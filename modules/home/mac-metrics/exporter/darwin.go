package main

/*
#include <dlfcn.h>
#include <libproc.h>
#include <mach/mach_time.h>
#include <sys/resource.h>
#include <sys/sysctl.h>

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
