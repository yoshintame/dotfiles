package main

import (
	"bytes"
	"flag"
	"fmt"
	"io"
	"log"
	"math"
	"net/http"
	"os"
	"path/filepath"
	"sort"
	"strconv"
	"strings"
	"sync"
	"time"
)

var browsers = map[string]string{
	"Arc.app":           "arc",
	"Dia.app":           "dia",
	"yab.app":           "yab",
	"Crest.app":         "crest",
	"Google Chrome.app": "chrome",
	"Safari.app":        "safari",
}

var webkitTypes = map[string]string{
	"com.apple.WebKit.WebContent": "renderer",
	"com.apple.WebKit.GPU":        "gpu",
	"com.apple.WebKit.Networking": "network",
}

var utilitySubtypes = map[string]string{
	"network.mojom.NetworkService":            "network",
	"storage.mojom.StorageService":            "storage",
	"audio.mojom.AudioService":                "audio",
	"video_capture.mojom.VideoCaptureService": "video-capture",
}

const (
	graduateFootprint = 64 << 20
	graduateCPUShare  = 0.05
	pruneAfterSamples = 40
)

type key struct{ a, b string }

type gauges struct {
	processes    int
	footprint    uint64
	resident     uint64
	maxFootprint uint64
}

type counters struct {
	cpuSeconds float64
	energy     float64
	wakeups    float64
	diskRead   float64
	diskWrite  float64
}

func (c *counters) add(d counters) {
	c.cpuSeconds += d.cpuSeconds
	c.energy += d.energy
	c.wakeups += d.wakeups
	c.diskRead += d.diskRead
	c.diskWrite += d.diskWrite
}

func (g *gauges) add(u usage) {
	g.processes++
	g.footprint += u.footprint
	g.resident += u.resident
	g.maxFootprint = max(g.maxFootprint, u.footprint)
}

type exporter struct {
	mu            sync.Mutex
	rendered      []byte
	renderedAt    time.Time
	previous      map[int]usage
	sinceTicks    uint64
	lastSample    time.Time
	samples       int
	lastSeen      map[key]int
	graduated     map[key]bool
	appTotals     map[key]*counters
	browserTotals map[key]*counters
}

func newExporter() *exporter {
	return &exporter{
		previous:      map[int]usage{},
		sinceTicks:    math.MaxUint64,
		lastSeen:      map[key]int{},
		graduated:     map[key]bool{},
		appTotals:     map[key]*counters{},
		browserTotals: map[key]*counters{},
	}
}

func outerBundle(path string) string {
	for part := range strings.SplitSeq(path, "/") {
		if strings.HasSuffix(part, ".app") {
			return part
		}
	}
	return ""
}

func browserProcessType(path string, args []string, isMain bool) string {
	name := filepath.Base(path)
	if t, ok := webkitTypes[name]; ok {
		return t
	}
	flags := map[string]string{}
	extension := false
	for _, a := range args {
		if a == "--extension-process" {
			extension = true
		}
		if k, v, ok := strings.Cut(strings.TrimPrefix(a, "--"), "="); ok && strings.HasPrefix(a, "--") {
			flags[k] = v
		}
	}
	switch kind, ok := flags["type"]; {
	case !ok && isMain && len(args) > 1 && args[1] == "mcp":
		return "mcp"
	case !ok && isMain:
		return "main"
	case !ok:
		return "xpc"
	case kind == "renderer" && extension:
		return "extension"
	case kind == "renderer":
		return "renderer"
	case kind == "gpu-process":
		return "gpu"
	case kind == "utility":
		if t, ok := utilitySubtypes[flags["utility-sub-type"]]; ok {
			return t
		}
		return "utility"
	default:
		return kind
	}
}

type proc struct {
	pid     int
	path    string
	usage   usage
	app     key
	browser key
}

func takeSample() ([]proc, []int) {
	paths := map[int]string{}
	var procs []proc
	var inaccessible []int
	for _, pid := range listPids() {
		u, ok := pidUsage(pid)
		if !ok {
			inaccessible = append(inaccessible, pid)
			continue
		}
		app, browser, ok := classify(pid, paths)
		if !ok {
			continue
		}
		procs = append(procs, proc{pid, paths[pid], u, app, browser})
	}
	return procs, inaccessible
}

func classify(pid int, paths map[int]string) (app, browser key, ok bool) {
	path, cached := paths[pid]
	if !cached {
		path = pidPath(pid)
		paths[pid] = path
	}
	if path == "" {
		return key{}, key{}, false
	}
	own := outerBundle(path)
	ownerBundle := ""
	if owner := responsiblePid(pid); owner > 0 && owner != pid {
		ownerPath, ok := paths[owner]
		if !ok {
			ownerPath = pidPath(owner)
			paths[owner] = ownerPath
		}
		ownerBundle = outerBundle(ownerPath)
	}

	switch {
	case own != "":
		app = key{strings.TrimSuffix(own, ".app"), "app"}
	case strings.Contains(path, ".xpc/") && ownerBundle != "":
		app = key{strings.TrimSuffix(ownerBundle, ".app"), "app"}
	default:
		app = key{filepath.Base(path), "command"}
	}

	name, ok := browsers[own]
	if !ok {
		name, ok = browsers[ownerBundle]
	}
	if ok {
		isMain := own != "" && strings.Count(path, ".app/") == 1 && strings.Contains(path, "/Contents/MacOS/")
		browser = key{name, browserProcessType(path, pidArgs(pid), isMain)}
	}
	return app, browser, true
}

func delta(now usage, before usage, seen bool, sinceTicks uint64) counters {
	switch {
	case seen && before.start == now.start:
	case now.start >= sinceTicks:
		before = usage{}
	default:
		return counters{}
	}
	diff := func(a, b uint64) float64 {
		if a < b {
			return 0
		}
		return float64(a - b)
	}
	cpu := now.cpuNanos - before.cpuNanos
	return counters{
		cpuSeconds: max(cpu, 0) / 1e9,
		energy:     diff(now.energy, before.energy) / 1e9,
		wakeups:    diff(now.wakeups, before.wakeups),
		diskRead:   diff(now.diskRead, before.diskRead),
		diskWrite:  diff(now.diskWrite, before.diskWrite),
	}
}

func (e *exporter) sample() {
	began := time.Now()
	nowTicks := machAbsoluteTime()
	elapsed := began.Sub(e.lastSample).Seconds()
	current := map[int]usage{}
	appGauges := map[key]*gauges{}
	appDeltas := map[key]*counters{}
	browserGauges := map[key]*gauges{}
	e.samples++
	e.prune()

	procs, inaccessible := takeSample()
	for _, p := range procs {
		u, app, browser := p.usage, p.app, p.browser
		current[p.pid] = u
		before, seen := e.previous[p.pid]
		d := delta(u, before, seen, e.sinceTicks)

		if appGauges[app] == nil {
			appGauges[app] = &gauges{}
			appDeltas[app] = &counters{}
		}
		appGauges[app].add(u)
		appDeltas[app].add(d)

		if browser.a != "" {
			if browserGauges[browser] == nil {
				browserGauges[browser] = &gauges{}
			}
			browserGauges[browser].add(u)
			if e.browserTotals[browser] == nil {
				e.browserTotals[browser] = &counters{}
			}
			e.browserTotals[browser].add(d)
			e.lastSeen[browser] = e.samples
		}
	}

	other := key{"other", "other"}
	otherGauges := &gauges{}
	for app, g := range appGauges {
		cpuShare := 0.0
		if !e.lastSample.IsZero() && elapsed > 0 {
			cpuShare = appDeltas[app].cpuSeconds / elapsed
		}
		if g.footprint >= graduateFootprint || cpuShare >= graduateCPUShare {
			e.graduated[app] = true
			e.lastSeen[app] = e.samples
		}
		target := app
		if !e.graduated[app] {
			target = other
			otherGauges.processes += g.processes
			otherGauges.footprint += g.footprint
			otherGauges.resident += g.resident
			otherGauges.maxFootprint = max(otherGauges.maxFootprint, g.maxFootprint)
			delete(appGauges, app)
		}
		if e.appTotals[target] == nil {
			e.appTotals[target] = &counters{}
		}
		e.appTotals[target].add(*appDeltas[app])
	}
	appGauges[other] = otherGauges

	e.previous = current
	e.sinceTicks = nowTicks
	e.lastSample = began

	var buf bytes.Buffer
	writeFamilies(&buf, "mac_app", "app", "kind", appGauges, e.appTotals)
	writeFamilies(&buf, "mac_browser", "browser", "process_type", browserGauges, e.browserTotals)
	writeSystem(&buf)
	writeScalar(&buf, "mac_apps_processes_inaccessible", "gauge", "Processes whose usage cannot be read without root.", float64(len(inaccessible)))
	writeScalar(&buf, "mac_apps_collect_duration_seconds", "gauge", "Time spent reading all processes.", time.Since(began).Seconds())

	e.mu.Lock()
	e.rendered = buf.Bytes()
	e.renderedAt = time.Now()
	e.mu.Unlock()
}

func (e *exporter) prune() {
	for k, seen := range e.lastSeen {
		if e.samples-seen < pruneAfterSamples {
			continue
		}
		delete(e.lastSeen, k)
		delete(e.graduated, k)
		delete(e.appTotals, k)
		delete(e.browserTotals, k)
	}
}

var pagingEvents = []string{"compress", "decompress", "pagein", "pageout", "swapin", "swapout"}

func writeSystem(w io.Writer) {
	if level, ok := sysctlUint("kern.memorystatus_vm_pressure_level"); ok {
		writeScalar(w, "mac_memory_pressure_level", "gauge", "Kernel memory pressure level: 1 normal, 2 warning, 4 critical.", float64(level))
	}
	if level, ok := sysctlUint("kern.memorystatus_level"); ok {
		writeScalar(w, "mac_memory_free_ratio", "gauge", "Share of memory the kernel considers available.", float64(level)/100)
	}
	if vm, ok := readVM(); ok {
		paging := vm.paging()
		fmt.Fprintf(w, "# HELP mac_vm_paging_bytes_total Bytes moved by the compressor, swap and file paging.\n# TYPE mac_vm_paging_bytes_total counter\n")
		for _, event := range pagingEvents {
			fmt.Fprintf(w, "mac_vm_paging_bytes_total{event=\"%s\"} %d\n", event, paging[event])
		}
	}
	if level, ok := thermalPressure(); ok {
		writeScalar(w, "mac_thermal_pressure_level", "gauge", "Thermal pressure: 0 nominal, 1 moderate, 2 heavy, 3 trapping, 4 sleeping.", float64(level))
	}
	if b, ok := readBattery(); ok {
		writeScalar(w, "mac_battery_cycle_count", "gauge", "Battery charge cycle count.", float64(b.cycles))
		writeScalar(w, "mac_battery_full_charge_capacity_mah", "gauge", "Current full charge capacity.", float64(b.fullCapacity))
		writeScalar(w, "mac_battery_design_capacity_mah", "gauge", "Design capacity.", float64(b.designCapacity))
	}
}

func writeScalar(w io.Writer, name, kind, help string, value float64) {
	fmt.Fprintf(w, "# HELP %s %s\n# TYPE %s %s\n%s %s\n", name, help, name, kind, name, formatFloat(value))
}

var labelEscaper = strings.NewReplacer(`\`, `\\`, `"`, `\"`, "\n", `\n`)

func labelValue(v string) string {
	return labelEscaper.Replace(strings.ToValidUTF8(v, "\uFFFD"))
}

func formatFloat(v float64) string {
	return strconv.FormatFloat(v, 'g', -1, 64)
}

func writeFamilies(w io.Writer, prefix, labelA, labelB string, gs map[key]*gauges, cs map[key]*counters) {
	series := func(name, kind, help string, keys []key, value func(key) float64) {
		fmt.Fprintf(w, "# HELP %s_%s %s\n# TYPE %s_%s %s\n", prefix, name, help, prefix, name, kind)
		for _, k := range keys {
			fmt.Fprintf(w, "%s_%s{%s=\"%s\",%s=\"%s\"} %s\n", prefix, name,
				labelA, labelValue(k.a), labelB, labelValue(k.b), formatFloat(value(k)))
		}
	}
	gaugeKeys := sortedKeys(gs)
	counterKeys := sortedKeys(cs)
	series("processes", "gauge", "Running processes.", gaugeKeys,
		func(k key) float64 { return float64(gs[k].processes) })
	series("memory_footprint_bytes", "gauge", "Summed physical footprint, the Memory column of Activity Monitor.", gaugeKeys,
		func(k key) float64 { return float64(gs[k].footprint) })
	series("memory_resident_bytes", "gauge", "Summed resident size.", gaugeKeys,
		func(k key) float64 { return float64(gs[k].resident) })
	series("process_footprint_max_bytes", "gauge", "Largest single process footprint.", gaugeKeys,
		func(k key) float64 { return float64(gs[k].maxFootprint) })
	series("cpu_seconds_total", "counter", "CPU time, user plus system.", counterKeys,
		func(k key) float64 { return cs[k].cpuSeconds })
	series("energy_joules_total", "counter", "Energy used by the process itself.", counterKeys,
		func(k key) float64 { return cs[k].energy })
	series("wakeups_total", "counter", "Idle and interrupt wakeups.", counterKeys,
		func(k key) float64 { return cs[k].wakeups })
	series("disk_read_bytes_total", "counter", "Bytes read from disk.", counterKeys,
		func(k key) float64 { return cs[k].diskRead })
	series("disk_written_bytes_total", "counter", "Bytes written to disk.", counterKeys,
		func(k key) float64 { return cs[k].diskWrite })
}

func sortedKeys[V any](m map[key]V) []key {
	keys := make([]key, 0, len(m))
	for k := range m {
		keys = append(keys, k)
	}
	sort.Slice(keys, func(i, j int) bool {
		if keys[i].a != keys[j].a {
			return keys[i].a < keys[j].a
		}
		return keys[i].b < keys[j].b
	})
	return keys
}

func serve(args []string) {
	flags := flag.NewFlagSet("serve", flag.ExitOnError)
	listen := flags.String("listen", "127.0.0.1:9184", "address to serve /metrics on")
	interval := flags.Duration("interval", 15*time.Second, "time between process samples")
	flags.Parse(args)

	e := newExporter()
	e.sample()
	go func() {
		for range time.Tick(*interval) {
			e.sample()
		}
	}()
	http.HandleFunc("/metrics", func(w http.ResponseWriter, _ *http.Request) {
		e.mu.Lock()
		rendered, age := e.rendered, time.Since(e.renderedAt)
		e.mu.Unlock()
		if age > 3**interval {
			http.Error(w, fmt.Sprintf("last sample is %s old", age.Round(time.Second)), http.StatusServiceUnavailable)
			return
		}
		w.Header().Set("Content-Type", "text/plain; version=0.0.4")
		w.Write(rendered)
	})
	log.Fatal(http.ListenAndServe(*listen, nil))
}

func main() {
	if len(os.Args) < 2 {
		fmt.Fprintln(os.Stderr, "usage: mac-metrics serve [-listen addr] | snapshot [-interval 1s] [-top 15] [-json]")
		os.Exit(2)
	}
	switch os.Args[1] {
	case "serve":
		serve(os.Args[2:])
	case "snapshot":
		snapshot(os.Args[2:])
	default:
		fmt.Fprintf(os.Stderr, "unknown command %q\n", os.Args[1])
		os.Exit(2)
	}
}
