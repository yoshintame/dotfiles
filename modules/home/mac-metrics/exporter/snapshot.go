package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"text/tabwriter"
	"time"
)

type rates struct {
	FootprintBytes   uint64  `json:"footprint_bytes"`
	CPUPercent       float64 `json:"cpu_percent"`
	PowerMilliwatts  float64 `json:"power_mw"`
	WakeupsPerSecond float64 `json:"wakeups_per_s"`
	DiskReadPerSec   float64 `json:"disk_read_bytes_per_s"`
	DiskWritePerSec  float64 `json:"disk_write_bytes_per_s"`
}

func (r *rates) add(o rates) {
	r.FootprintBytes += o.FootprintBytes
	r.CPUPercent += o.CPUPercent
	r.PowerMilliwatts += o.PowerMilliwatts
	r.WakeupsPerSecond += o.WakeupsPerSecond
	r.DiskReadPerSec += o.DiskReadPerSec
	r.DiskWritePerSec += o.DiskWritePerSec
}

type appRow struct {
	App       string `json:"app"`
	Kind      string `json:"kind"`
	Processes int    `json:"processes"`
	rates
}

type procRow struct {
	PID        int     `json:"pid"`
	Name       string  `json:"name"`
	App        string  `json:"app"`
	Browser    string  `json:"browser,omitempty"`
	Type       string  `json:"process_type,omitempty"`
	AgeSeconds float64 `json:"age_seconds"`
	rates
}

type browserRow struct {
	Browser   string            `json:"browser"`
	Processes int               `json:"processes"`
	ByType    map[string]uint64 `json:"footprint_by_type"`
	rates
}

type cpuInfo struct {
	Cores            uint64     `json:"cores"`
	PerformanceCores uint64     `json:"performance_cores"`
	EfficiencyCores  uint64     `json:"efficiency_cores"`
	BusyPercent      float64    `json:"busy_percent"`
	UserPercent      float64    `json:"user_percent"`
	SystemPercent    float64    `json:"system_percent"`
	Load             [3]float64 `json:"load"`
}

type memoryInfo struct {
	TotalBytes      uint64 `json:"total_bytes"`
	UsedBytes       uint64 `json:"used_bytes"`
	AppBytes        uint64 `json:"app_bytes"`
	WiredBytes      uint64 `json:"wired_bytes"`
	CompressedBytes uint64 `json:"compressed_bytes"`
	CachedBytes     uint64 `json:"cached_bytes"`
	FreeBytes       uint64 `json:"free_bytes"`
	Pressure        string `json:"pressure"`
	KernelFreeLevel uint64 `json:"kernel_free_percent"`
	SwapTotalBytes  uint64 `json:"swap_total_bytes"`
	SwapUsedBytes   uint64 `json:"swap_used_bytes"`
}

type report struct {
	Time                  time.Time    `json:"time"`
	IntervalSeconds       float64      `json:"interval_seconds"`
	UptimeSeconds         int64        `json:"uptime_seconds"`
	CPU                   cpuInfo      `json:"cpu"`
	Memory                memoryInfo   `json:"memory"`
	InaccessibleProcesses int          `json:"inaccessible_processes"`
	AppsByMemory          []appRow     `json:"apps_by_memory"`
	AppsByCPU             []appRow     `json:"apps_by_cpu"`
	ProcessesByMemory     []procRow    `json:"processes_by_memory"`
	ProcessesByCPU        []procRow    `json:"processes_by_cpu"`
	Browsers              []browserRow `json:"browsers"`
}

var pressureNames = map[uint64]string{1: "normal", 2: "warning", 4: "critical"}

func readMemory() memoryInfo {
	m := memoryInfo{}
	m.TotalBytes, _ = sysctlUint("hw.memsize")
	if vm, ok := readVM(); ok {
		ps := vm.pageSize
		purgeable := min(vm.purgeable, vm.internal)
		m.AppBytes = (vm.internal - purgeable) * ps
		m.WiredBytes = vm.wired * ps
		m.CompressedBytes = vm.compressed * ps
		m.CachedBytes = (vm.external + purgeable) * ps
		m.FreeBytes = vm.free * ps
		m.UsedBytes = m.AppBytes + m.WiredBytes + m.CompressedBytes
	}
	level, _ := sysctlUint("kern.memorystatus_vm_pressure_level")
	m.Pressure = pressureNames[level]
	if m.Pressure == "" {
		m.Pressure = fmt.Sprintf("unknown (%d)", level)
	}
	m.KernelFreeLevel, _ = sysctlUint("kern.memorystatus_level")
	m.SwapTotalBytes, m.SwapUsedBytes, _ = readSwap()
	return m
}

func readCPU(before, after cpuTicks) cpuInfo {
	c := cpuInfo{Load: loadAverage()}
	c.Cores, _ = sysctlUint("hw.logicalcpu")
	c.PerformanceCores, _ = sysctlUint("hw.perflevel0.logicalcpu")
	c.EfficiencyCores, _ = sysctlUint("hw.perflevel1.logicalcpu")
	user := float64(after.user - before.user + after.nice - before.nice)
	system := float64(after.system - before.system)
	total := user + system + float64(after.idle-before.idle)
	if total > 0 {
		c.UserPercent = 100 * user / total
		c.SystemPercent = 100 * system / total
		c.BusyPercent = c.UserPercent + c.SystemPercent
	}
	return c
}

func toRates(u usage, d counters, seconds float64) rates {
	return rates{
		FootprintBytes:   u.footprint,
		CPUPercent:       100 * d.cpuSeconds / seconds,
		PowerMilliwatts:  1000 * d.energy / seconds,
		WakeupsPerSecond: d.wakeups / seconds,
		DiskReadPerSec:   d.diskRead / seconds,
		DiskWritePerSec:  d.diskWrite / seconds,
	}
}

func top[T any](rows []T, n int, less func(a, b T) bool) []T {
	sorted := append([]T(nil), rows...)
	sort.SliceStable(sorted, func(i, j int) bool { return less(sorted[i], sorted[j]) })
	return sorted[:min(n, len(sorted))]
}

func buildReport(interval time.Duration, n int) report {
	ticksBefore, _ := readCPUTicks()
	first, _ := takeSample()
	started := time.Now()
	time.Sleep(interval)
	second, inaccessible := takeSample()
	seconds := time.Since(started).Seconds()
	ticksAfter, _ := readCPUTicks()
	nowTicks := float64(machAbsoluteTime())

	previous := make(map[int]usage, len(first))
	for _, p := range first {
		previous[p.pid] = p.usage
	}

	apps := map[key]*appRow{}
	browsersByName := map[string]*browserRow{}
	var procRows []procRow
	for _, p := range second {
		before, seen := previous[p.pid]
		r := toRates(p.usage, delta(p.usage, before, seen), seconds)

		a := apps[p.app]
		if a == nil {
			a = &appRow{App: p.app.a, Kind: p.app.b}
			apps[p.app] = a
		}
		a.Processes++
		a.add(r)

		name := filepath.Base(p.path)
		if p.path == "" {
			name = p.app.a
		}
		row := procRow{
			PID:        p.pid,
			Name:       name,
			App:        p.app.a,
			Browser:    p.browser.a,
			Type:       p.browser.b,
			AgeSeconds: max(nowTicks-float64(p.usage.start), 0) * nanosPerTick / 1e9,
			rates:      r,
		}
		procRows = append(procRows, row)

		if p.browser.a != "" && p.browser.b != "mcp" {
			b := browsersByName[p.browser.a]
			if b == nil {
				b = &browserRow{Browser: p.browser.a, ByType: map[string]uint64{}}
				browsersByName[p.browser.a] = b
			}
			b.Processes++
			b.ByType[p.browser.b] += p.usage.footprint
			b.add(r)
		}
	}

	appRows := make([]appRow, 0, len(apps))
	for _, a := range apps {
		appRows = append(appRows, *a)
	}
	browserRows := make([]browserRow, 0, len(browsersByName))
	for _, b := range browsersByName {
		browserRows = append(browserRows, *b)
	}

	byMemory := func(a, b rates) bool { return a.FootprintBytes > b.FootprintBytes }
	byCPU := func(a, b rates) bool { return a.CPUPercent > b.CPUPercent }
	return report{
		Time:                  time.Now(),
		IntervalSeconds:       seconds,
		UptimeSeconds:         time.Now().Unix() - bootTime(),
		CPU:                   readCPU(ticksBefore, ticksAfter),
		Memory:                readMemory(),
		InaccessibleProcesses: inaccessible,
		AppsByMemory:          top(appRows, n, func(a, b appRow) bool { return byMemory(a.rates, b.rates) }),
		AppsByCPU:             top(appRows, n, func(a, b appRow) bool { return byCPU(a.rates, b.rates) }),
		ProcessesByMemory:     top(procRows, n, func(a, b procRow) bool { return byMemory(a.rates, b.rates) }),
		ProcessesByCPU:        top(procRows, n, func(a, b procRow) bool { return byCPU(a.rates, b.rates) }),
		Browsers:              top(browserRows, len(browserRows), func(a, b browserRow) bool { return byMemory(a.rates, b.rates) }),
	}
}

func bytesText(b uint64) string {
	switch {
	case b >= 1<<30:
		return fmt.Sprintf("%.1fG", float64(b)/(1<<30))
	case b >= 1<<20:
		return fmt.Sprintf("%.0fM", float64(b)/(1<<20))
	default:
		return fmt.Sprintf("%.0fK", float64(b)/(1<<10))
	}
}

func durationText(seconds float64) string {
	d := time.Duration(seconds) * time.Second
	switch {
	case d >= 24*time.Hour:
		return fmt.Sprintf("%dd%dh", int(d.Hours())/24, int(d.Hours())%24)
	case d >= time.Hour:
		return fmt.Sprintf("%dh%dm", int(d.Hours()), int(d.Minutes())%60)
	case d >= time.Minute:
		return fmt.Sprintf("%dm", int(d.Minutes()))
	default:
		return fmt.Sprintf("%ds", int(d.Seconds()))
	}
}

func writeText(w io.Writer, r report) {
	m, c := r.Memory, r.CPU
	fmt.Fprintf(w, "Mac snapshot %s, interval %.1fs, uptime %s\n",
		r.Time.Format("2006-01-02 15:04:05"), r.IntervalSeconds, durationText(float64(r.UptimeSeconds)))
	fmt.Fprintf(w, "CPU       %.0f%% busy (user %.0f%%, system %.0f%%) of %d cores (%dP+%dE), load %.2f %.2f %.2f\n",
		c.BusyPercent, c.UserPercent, c.SystemPercent, c.Cores, c.PerformanceCores, c.EfficiencyCores, c.Load[0], c.Load[1], c.Load[2])
	fmt.Fprintf(w, "Memory    %s used of %s: app %s, wired %s, compressed %s; cached files %s, free %s\n",
		bytesText(m.UsedBytes), bytesText(m.TotalBytes), bytesText(m.AppBytes), bytesText(m.WiredBytes),
		bytesText(m.CompressedBytes), bytesText(m.CachedBytes), bytesText(m.FreeBytes))
	fmt.Fprintf(w, "Pressure  %s (kernel free level %d%%), swap %s of %s\n",
		m.Pressure, m.KernelFreeLevel, bytesText(m.SwapUsedBytes), bytesText(m.SwapTotalBytes))
	fmt.Fprintf(w, "Hidden    %d processes of root and other users are not readable without root (WindowServer, kernel_task, system daemons)\n", r.InaccessibleProcesses)

	appTable := func(title string, rows []appRow) {
		fmt.Fprintf(w, "\n%s\n", title)
		tw := tabwriter.NewWriter(w, 0, 0, 2, ' ', tabwriter.AlignRight)
		fmt.Fprintln(tw, "MEMORY\tCPU%\tWAKEUPS/s\tDISK W/s\tPROCS\t  APP\t")
		for _, a := range rows {
			fmt.Fprintf(tw, "%s\t%.1f\t%.0f\t%s\t%d\t  %s (%s)\t\n", bytesText(a.FootprintBytes), a.CPUPercent,
				a.WakeupsPerSecond, bytesText(uint64(a.DiskWritePerSec)), a.Processes, a.App, a.Kind)
		}
		tw.Flush()
	}
	procTable := func(title string, rows []procRow) {
		fmt.Fprintf(w, "\n%s\n", title)
		tw := tabwriter.NewWriter(w, 0, 0, 2, ' ', tabwriter.AlignRight)
		fmt.Fprintln(tw, "PID\tMEMORY\tCPU%\tWAKEUPS/s\tAGE\t  PROCESS\t")
		for _, p := range rows {
			label := p.Name
			if p.App != p.Name {
				label += " [" + p.App + "]"
			}
			if p.Type != "" {
				label += " " + p.Type
			}
			fmt.Fprintf(tw, "%d\t%s\t%.1f\t%.0f\t%s\t  %s\t\n", p.PID, bytesText(p.FootprintBytes), p.CPUPercent,
				p.WakeupsPerSecond, durationText(p.AgeSeconds), label)
		}
		tw.Flush()
	}

	appTable("Apps by memory", r.AppsByMemory)
	appTable("Apps by CPU", r.AppsByCPU)
	procTable("Processes by memory", r.ProcessesByMemory)
	procTable("Processes by CPU", r.ProcessesByCPU)

	if len(r.Browsers) > 0 {
		fmt.Fprintf(w, "\nBrowsers (without yab mcp bridges)\n")
		tw := tabwriter.NewWriter(w, 0, 0, 2, ' ', 0)
		fmt.Fprintln(tw, "BROWSER\tMEMORY\tCPU%\tPROCS\tMEMORY BY TYPE")
		for _, b := range r.Browsers {
			types := make([]string, 0, len(b.ByType))
			for t := range b.ByType {
				types = append(types, t)
			}
			sort.Slice(types, func(i, j int) bool { return b.ByType[types[i]] > b.ByType[types[j]] })
			parts := make([]string, len(types))
			for i, t := range types {
				parts[i] = t + " " + bytesText(b.ByType[t])
			}
			fmt.Fprintf(tw, "%s\t%s\t%.1f\t%d\t%s\n", b.Browser, bytesText(b.FootprintBytes), b.CPUPercent,
				b.Processes, strings.Join(parts, ", "))
		}
		tw.Flush()
	}
}

func snapshot(args []string) {
	flags := flag.NewFlagSet("snapshot", flag.ExitOnError)
	interval := flags.Duration("interval", time.Second, "time between the two samples used for CPU, power and wakeup rates")
	n := flags.Int("top", 15, "rows per table")
	asJSON := flags.Bool("json", false, "print JSON instead of tables")
	flags.Parse(args)

	r := buildReport(*interval, *n)
	if *asJSON {
		enc := json.NewEncoder(os.Stdout)
		enc.SetIndent("", "  ")
		if err := enc.Encode(r); err != nil {
			fmt.Fprintln(os.Stderr, err)
			os.Exit(1)
		}
		return
	}
	writeText(os.Stdout, r)
}
