package main

import (
	"flag"
	"fmt"
	"io"
	"log"
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
	previous      map[int]usage
	lastSample    time.Time
	graduated     map[key]bool
	appTotals     map[key]*counters
	browserTotals map[key]*counters
}

func newExporter() *exporter {
	return &exporter{
		previous:      map[int]usage{},
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

func commandName(pid int, path string) string {
	if args := pidArgs(pid); len(args) > 0 {
		return filepath.Base(args[0])
	}
	return filepath.Base(path)
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
		app, browser := classify(pid, paths)
		procs = append(procs, proc{pid, paths[pid], u, app, browser})
	}
	return procs, inaccessible
}

func classify(pid int, paths map[int]string) (app, browser key) {
	path, ok := paths[pid]
	if !ok {
		path = pidPath(pid)
		paths[pid] = path
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
		app = key{commandName(pid, path), "command"}
	}

	name, ok := browsers[own]
	if !ok {
		name, ok = browsers[ownerBundle]
	}
	if ok {
		isMain := own != "" && strings.Count(path, ".app/") == 1 && strings.Contains(path, "/Contents/MacOS/")
		browser = key{name, browserProcessType(path, pidArgs(pid), isMain)}
	}
	return app, browser
}

func delta(now usage, before usage, seen bool) counters {
	if !seen || before.start != now.start {
		before = usage{}
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

func (e *exporter) collect(w io.Writer) {
	e.mu.Lock()
	defer e.mu.Unlock()

	began := time.Now()
	elapsed := began.Sub(e.lastSample).Seconds()
	current := map[int]usage{}
	appGauges := map[key]*gauges{}
	appDeltas := map[key]*counters{}
	browserGauges := map[key]*gauges{}

	procs, inaccessible := takeSample()
	for _, p := range procs {
		u, app, browser := p.usage, p.app, p.browser
		current[p.pid] = u
		before, seen := e.previous[p.pid]
		d := delta(u, before, seen)

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
		}
		target := app
		if !e.graduated[app] {
			target = other
			otherGauges.processes += g.processes
			otherGauges.footprint += g.footprint
			otherGauges.resident += g.resident
			otherGauges.maxFootprint = max(otherGauges.maxFootprint, g.maxFootprint)
		}
		if e.appTotals[target] == nil {
			e.appTotals[target] = &counters{}
		}
		e.appTotals[target].add(*appDeltas[app])
	}
	for app := range appGauges {
		if !e.graduated[app] {
			delete(appGauges, app)
		}
	}
	appGauges[other] = otherGauges

	e.previous = current
	e.lastSample = began

	writeFamilies(w, "mac_app", "app", "kind", appGauges, e.appTotals)
	writeFamilies(w, "mac_browser", "browser", "process_type", browserGauges, e.browserTotals)
	fmt.Fprintf(w, "# HELP mac_apps_processes_inaccessible Processes whose usage cannot be read without root.\n# TYPE mac_apps_processes_inaccessible gauge\nmac_apps_processes_inaccessible %d\n", len(inaccessible))
	if vm, ok := readVM(); ok {
		fmt.Fprintf(w, "# HELP mac_vm_paging_bytes_total Bytes moved by the compressor, swap and file paging.\n# TYPE mac_vm_paging_bytes_total counter\n")
		paging := vm.paging()
		for _, event := range []string{"compress", "decompress", "pagein", "pageout", "swapin", "swapout"} {
			fmt.Fprintf(w, "mac_vm_paging_bytes_total{event=\"%s\"} %d\n", event, paging[event])
		}
	}
	if level, ok := thermalPressure(); ok {
		fmt.Fprintf(w, "# HELP mac_thermal_pressure_level Thermal pressure: 0 nominal, 1 moderate, 2 heavy, 3 trapping, 4 sleeping.\n# TYPE mac_thermal_pressure_level gauge\nmac_thermal_pressure_level %d\n", level)
	}
	fmt.Fprintf(w, "# HELP mac_apps_collect_duration_seconds Time spent reading all processes.\n# TYPE mac_apps_collect_duration_seconds gauge\nmac_apps_collect_duration_seconds %s\n", formatFloat(time.Since(began).Seconds()))
}

var labelEscaper = strings.NewReplacer(`\`, `\\`, `"`, `\"`, "\n", `\n`)

func formatFloat(v float64) string {
	return strconv.FormatFloat(v, 'g', -1, 64)
}

func writeFamilies(w io.Writer, prefix, labelA, labelB string, gs map[key]*gauges, cs map[key]*counters) {
	series := func(name, kind, help string, keys []key, value func(key) float64) {
		fmt.Fprintf(w, "# HELP %s_%s %s\n# TYPE %s_%s %s\n", prefix, name, help, prefix, name, kind)
		for _, k := range keys {
			fmt.Fprintf(w, "%s_%s{%s=\"%s\",%s=\"%s\"} %s\n", prefix, name,
				labelA, labelEscaper.Replace(k.a), labelB, labelEscaper.Replace(k.b), formatFloat(value(k)))
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
	series("energy_joules_total", "counter", "Billed energy.", counterKeys,
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
	flags.Parse(args)

	e := newExporter()
	http.HandleFunc("/metrics", func(w http.ResponseWriter, _ *http.Request) {
		w.Header().Set("Content-Type", "text/plain; version=0.0.4")
		e.collect(w)
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
