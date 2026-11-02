package main

/*
#include <dlfcn.h>
#include <libproc.h>
#include <mach/mach.h>
#include <mach/mach_time.h>
#include <stdlib.h>
#include <sys/resource.h>
#include <sys/sysctl.h>
#include <sys/time.h>

typedef pid_t (*responsible_fn)(pid_t);

static responsible_fn responsible_ptr;

static void init_responsible(void) {
	responsible_ptr = (responsible_fn)dlsym(RTLD_DEFAULT, "responsibility_get_pid_responsible_for_pid");
}

static pid_t responsible_pid(pid_t pid) {
	return responsible_ptr ? responsible_ptr(pid) : -1;
}

static int pid_rusage(pid_t pid, struct rusage_info_v4 *info) {
	return proc_pid_rusage(pid, RUSAGE_INFO_V4, (rusage_info_t *)info);
}

static int pid_args(pid_t pid, char *buf, size_t *size) {
	int mib[3] = {CTL_KERN, KERN_PROCARGS2, pid};
	return sysctl(mib, 3, buf, size, NULL, 0);
}

typedef struct {
	uint64_t free, active, inactive, wired, compressed, internal, external, purgeable, speculative, page_size;
} vm_snapshot;

static int read_vm(vm_snapshot *out) {
	vm_statistics64_data_t vm;
	mach_msg_type_number_t count = HOST_VM_INFO64_COUNT;
	mach_port_t host = mach_host_self();
	kern_return_t kr = host_statistics64(host, HOST_VM_INFO64, (host_info64_t)&vm, &count);
	vm_size_t page_size = 0;
	host_page_size(host, &page_size);
	mach_port_deallocate(mach_task_self(), host);
	if (kr != KERN_SUCCESS) {
		return -1;
	}
	out->free = vm.free_count;
	out->active = vm.active_count;
	out->inactive = vm.inactive_count;
	out->wired = vm.wire_count;
	out->compressed = vm.compressor_page_count;
	out->internal = vm.internal_page_count;
	out->external = vm.external_page_count;
	out->purgeable = vm.purgeable_count;
	out->speculative = vm.speculative_count;
	out->page_size = page_size;
	return 0;
}

static int read_cpu_ticks(uint64_t out[4]) {
	host_cpu_load_info_data_t info;
	mach_msg_type_number_t count = HOST_CPU_LOAD_INFO_COUNT;
	mach_port_t host = mach_host_self();
	kern_return_t kr = host_statistics(host, HOST_CPU_LOAD_INFO, (host_info_t)&info, &count);
	mach_port_deallocate(mach_task_self(), host);
	if (kr != KERN_SUCCESS) {
		return -1;
	}
	for (int i = 0; i < CPU_STATE_MAX; i++) {
		out[i] = info.cpu_ticks[i];
	}
	return 0;
}

static int sysctl_u64(const char *name, uint64_t *out) {
	uint64_t value = 0;
	size_t size = sizeof(value);
	if (sysctlbyname(name, &value, &size, NULL, 0) != 0) {
		return -1;
	}
	*out = value;
	return 0;
}

static int read_swap(uint64_t *total, uint64_t *used) {
	struct xsw_usage swap;
	size_t size = sizeof(swap);
	if (sysctlbyname("vm.swapusage", &swap, &size, NULL, 0) != 0) {
		return -1;
	}
	*total = swap.xsu_total;
	*used = swap.xsu_used;
	return 0;
}

static int64_t boot_time(void) {
	struct timeval tv;
	size_t size = sizeof(tv);
	if (sysctlbyname("kern.boottime", &tv, &size, NULL, 0) != 0) {
		return -1;
	}
	return tv.tv_sec;
}
*/
import "C"

import (
	"bytes"
	"encoding/binary"
	"unsafe"
)

type usage struct {
	start     uint64
	footprint uint64
	resident  uint64
	cpuNanos  float64
	energy    uint64
	wakeups   uint64
	diskRead  uint64
	diskWrite uint64
}

var nanosPerTick float64

func init() {
	C.init_responsible()
	var tb C.mach_timebase_info_data_t
	C.mach_timebase_info(&tb)
	nanosPerTick = float64(tb.numer) / float64(tb.denom)
}

func listPids() []int {
	count := C.proc_listallpids(nil, 0)
	if count <= 0 {
		return nil
	}
	buf := make([]C.int, int(count)*2)
	count = C.proc_listallpids(unsafe.Pointer(&buf[0]), C.int(len(buf)*int(unsafe.Sizeof(buf[0]))))
	pids := make([]int, 0, count)
	for _, pid := range buf[:count] {
		if pid > 0 {
			pids = append(pids, int(pid))
		}
	}
	return pids
}

func pidPath(pid int) string {
	var buf [C.PROC_PIDPATHINFO_MAXSIZE]C.char
	if C.proc_pidpath(C.int(pid), unsafe.Pointer(&buf[0]), C.uint32_t(len(buf))) <= 0 {
		return ""
	}
	return C.GoString(&buf[0])
}

func responsiblePid(pid int) int {
	return int(C.responsible_pid(C.pid_t(pid)))
}

func pidUsage(pid int) (usage, bool) {
	var info C.struct_rusage_info_v4
	if C.pid_rusage(C.pid_t(pid), &info) != 0 {
		return usage{}, false
	}
	return usage{
		start:     uint64(info.ri_proc_start_abstime),
		footprint: uint64(info.ri_phys_footprint),
		resident:  uint64(info.ri_resident_size),
		cpuNanos:  float64(info.ri_user_time+info.ri_system_time) * nanosPerTick,
		energy:    uint64(info.ri_billed_energy),
		wakeups:   uint64(info.ri_pkg_idle_wkups + info.ri_interrupt_wkups),
		diskRead:  uint64(info.ri_diskio_bytesread),
		diskWrite: uint64(info.ri_diskio_byteswritten),
	}, true
}

func pidArgs(pid int) []string {
	var size C.size_t
	if C.pid_args(C.pid_t(pid), nil, &size) != 0 || size < 4 {
		return nil
	}
	buf := make([]byte, size)
	if C.pid_args(C.pid_t(pid), (*C.char)(unsafe.Pointer(&buf[0])), &size) != 0 || size < 4 {
		return nil
	}
	buf = buf[:size]
	argc := int(binary.LittleEndian.Uint32(buf[:4]))
	var parts []string
	for _, part := range bytes.Split(buf[4:], []byte{0}) {
		if len(part) > 0 {
			parts = append(parts, string(part))
		}
	}
	if len(parts) < 2 {
		return nil
	}
	return parts[1:min(argc+1, len(parts))]
}

type vmStats struct {
	free, active, inactive, wired, compressed, internal, external, purgeable, speculative, pageSize uint64
}

func readVM() (vmStats, bool) {
	var v C.vm_snapshot
	if C.read_vm(&v) != 0 {
		return vmStats{}, false
	}
	return vmStats{
		free: uint64(v.free), active: uint64(v.active), inactive: uint64(v.inactive),
		wired: uint64(v.wired), compressed: uint64(v.compressed), internal: uint64(v.internal),
		external: uint64(v.external), purgeable: uint64(v.purgeable), speculative: uint64(v.speculative),
		pageSize: uint64(v.page_size),
	}, true
}

type cpuTicks struct{ user, system, idle, nice uint64 }

func readCPUTicks() (cpuTicks, bool) {
	var t [4]C.uint64_t
	if C.read_cpu_ticks(&t[0]) != 0 {
		return cpuTicks{}, false
	}
	return cpuTicks{uint64(t[C.CPU_STATE_USER]), uint64(t[C.CPU_STATE_SYSTEM]), uint64(t[C.CPU_STATE_IDLE]), uint64(t[C.CPU_STATE_NICE])}, true
}

func sysctlUint(name string) (uint64, bool) {
	cname := C.CString(name)
	defer C.free(unsafe.Pointer(cname))
	var v C.uint64_t
	if C.sysctl_u64(cname, &v) != 0 {
		return 0, false
	}
	return uint64(v), true
}

func readSwap() (total, used uint64, ok bool) {
	var t, u C.uint64_t
	if C.read_swap(&t, &u) != 0 {
		return 0, 0, false
	}
	return uint64(t), uint64(u), true
}

func bootTime() int64 {
	return int64(C.boot_time())
}

func loadAverage() [3]float64 {
	var l [3]C.double
	C.getloadavg(&l[0], 3)
	return [3]float64{float64(l[0]), float64(l[1]), float64(l[2])}
}

func machAbsoluteTime() uint64 {
	return uint64(C.mach_absolute_time())
}
