import ctypes
import json
import os
import sys
import tempfile
from collections import defaultdict

BROWSERS = {
    "Arc.app": "arc",
    "Dia.app": "dia",
    "yab.app": "yab",
    "Crest.app": "crest",
    "Google Chrome.app": "chrome",
    "Safari.app": "safari",
}

WEBKIT_TYPES = {
    "com.apple.WebKit.WebContent": "renderer",
    "com.apple.WebKit.GPU": "gpu",
    "com.apple.WebKit.Networking": "network",
}

UTILITY_SUBTYPES = {
    "network.mojom.NetworkService": "network",
    "storage.mojom.StorageService": "storage",
    "audio.mojom.AudioService": "audio",
    "video_capture.mojom.VideoCaptureService": "video-capture",
}

COUNTERS = (
    "cpu_seconds",
    "energy_joules",
    "wakeups",
    "disk_read_bytes",
    "disk_written_bytes",
)

RUSAGE_FIELDS = (
    "user_time system_time pkg_idle_wkups interrupt_wkups pageins wired_size "
    "resident_size phys_footprint proc_start_abstime proc_exit_abstime "
    "child_user_time child_system_time child_pkg_idle_wkups "
    "child_interrupt_wkups child_pageins child_elapsed_abstime "
    "diskio_bytesread diskio_byteswritten qos_default qos_maintenance "
    "qos_background qos_utility qos_legacy qos_user_initiated "
    "qos_user_interactive billed_system_time serviced_system_time "
    "logical_writes lifetime_max_phys_footprint instructions cycles "
    "billed_energy serviced_energy interval_max_phys_footprint runnable_time"
).split()


class RusageInfoV4(ctypes.Structure):
    _fields_ = [("uuid", ctypes.c_uint8 * 16)] + [
        (name, ctypes.c_uint64) for name in RUSAGE_FIELDS
    ]


class MachTimebase(ctypes.Structure):
    _fields_ = [("numer", ctypes.c_uint32), ("denom", ctypes.c_uint32)]


libc = ctypes.CDLL("/usr/lib/libSystem.B.dylib", use_errno=True)
libproc = ctypes.CDLL("/usr/lib/libproc.dylib")
responsible_pid = libc.responsibility_get_pid_responsible_for_pid
responsible_pid.restype = ctypes.c_int
responsible_pid.argtypes = [ctypes.c_int]

timebase = MachTimebase()
libc.mach_timebase_info(ctypes.byref(timebase))
NS_PER_ABS = timebase.numer / timebase.denom

PATH_BUF = ctypes.create_string_buffer(4096)


def list_pids():
    count = libproc.proc_listallpids(None, 0)
    pids = (ctypes.c_int * (count * 2))()
    count = libproc.proc_listallpids(pids, ctypes.sizeof(pids))
    return [pid for pid in pids[:count] if pid > 0]


def pid_path(pid):
    if libproc.proc_pidpath(pid, PATH_BUF, len(PATH_BUF)) <= 0:
        return ""
    return PATH_BUF.value.decode(errors="replace")


def pid_args(pid):
    mib = (ctypes.c_int * 3)(1, 49, pid)
    size = ctypes.c_size_t(0)
    if libc.sysctl(mib, 3, None, ctypes.byref(size), None, 0) != 0:
        return []
    buf = ctypes.create_string_buffer(size.value)
    if libc.sysctl(mib, 3, buf, ctypes.byref(size), None, 0) != 0:
        return []
    raw = buf.raw[:size.value]
    argc = int.from_bytes(raw[:4], "little")
    parts = [p for p in raw[4:].split(b"\0") if p]
    return [p.decode(errors="replace") for p in parts[1:argc + 1]]


def outer_bundle(path):
    for part in path.split("/"):
        if part.endswith(".app"):
            return part
    return None


def process_type(path, args, is_main):
    name = os.path.basename(path)
    if name in WEBKIT_TYPES:
        return WEBKIT_TYPES[name]
    flags = dict(a[2:].split("=", 1) for a in args if a.startswith("--") and "=" in a)
    kind = flags.get("type")
    if kind is None:
        if is_main and args[1:2] == ["mcp"]:
            return "mcp"
        return "main" if is_main else "xpc"
    if kind == "renderer":
        return "extension" if "--extension-process" in args else "renderer"
    if kind == "gpu-process":
        return "gpu"
    if kind == "utility":
        return UTILITY_SUBTYPES.get(flags.get("utility-sub-type", ""), "utility")
    return kind


def sample():
    paths = {}
    rows = {}
    for pid in list_pids():
        usage = RusageInfoV4()
        if libproc.proc_pid_rusage(pid, 4, ctypes.byref(usage)) != 0:
            continue
        path = paths.setdefault(pid, pid_path(pid))
        own = outer_bundle(path)
        browser = BROWSERS.get(own)
        if browser is None:
            owner = responsible_pid(pid)
            if owner <= 0 or owner == pid:
                continue
            owner_path = paths.setdefault(owner, pid_path(owner))
            browser = BROWSERS.get(outer_bundle(owner_path))
            if browser is None:
                continue
        is_main = own in BROWSERS and path.count(".app/") == 1 and "/Contents/MacOS/" in path
        rows[pid] = {
            "browser": browser,
            "type": process_type(path, pid_args(pid), is_main),
            "start": usage.proc_start_abstime,
            "footprint": usage.phys_footprint,
            "resident": usage.resident_size,
            "cpu_seconds": (usage.user_time + usage.system_time) * NS_PER_ABS / 1e9,
            "energy_joules": usage.billed_energy / 1e9,
            "wakeups": usage.pkg_idle_wkups + usage.interrupt_wkups,
            "disk_read_bytes": usage.diskio_bytesread,
            "disk_written_bytes": usage.diskio_byteswritten,
        }
    return rows


def load_state(path):
    try:
        with open(path) as f:
            return json.load(f)
    except (OSError, ValueError):
        return {"processes": {}, "totals": {}}


def atomic_write(path, text):
    fd, temporary = tempfile.mkstemp(dir=os.path.dirname(path), prefix=os.path.basename(path) + ".tmp.")
    try:
        with os.fdopen(fd, "w") as f:
            f.write(text)
        os.chmod(temporary, 0o644)
        os.replace(temporary, path)
    except BaseException:
        os.unlink(temporary)
        raise


def main():
    textfile_dir, state_path = sys.argv[1], sys.argv[2]
    state = load_state(state_path)
    previous = state["processes"]
    totals = state["totals"]

    rows = sample()
    gauges = defaultdict(lambda: {"processes": 0, "footprint": 0, "resident": 0, "max_footprint": 0})
    for pid, row in rows.items():
        key = f"{row['browser']}|{row['type']}"
        g = gauges[key]
        g["processes"] += 1
        g["footprint"] += row["footprint"]
        g["resident"] += row["resident"]
        g["max_footprint"] = max(g["max_footprint"], row["footprint"])

        before = previous.get(str(pid))
        same = before is not None and before["start"] == row["start"]
        total = totals.setdefault(key, dict.fromkeys(COUNTERS, 0))
        for counter in COUNTERS:
            delta = row[counter] - before[counter] if same else row[counter]
            total[counter] += max(delta, 0)

    lines = []

    def family(name, kind, help_text, values):
        lines.append(f"# HELP {name} {help_text}")
        lines.append(f"# TYPE {name} {kind}")
        for key, value in sorted(values.items()):
            browser, ptype = key.split("|")
            lines.append(f'{name}{{browser="{browser}",process_type="{ptype}"}} {value}')

    family("mac_browser_processes", "gauge", "Running processes.",
           {k: g["processes"] for k, g in gauges.items()})
    family("mac_browser_memory_footprint_bytes", "gauge",
           "Summed physical footprint, the Memory column of Activity Monitor.",
           {k: g["footprint"] for k, g in gauges.items()})
    family("mac_browser_memory_resident_bytes", "gauge", "Summed resident size.",
           {k: g["resident"] for k, g in gauges.items()})
    family("mac_browser_process_footprint_max_bytes", "gauge",
           "Largest single process footprint.",
           {k: g["max_footprint"] for k, g in gauges.items()})
    family("mac_browser_cpu_seconds_total", "counter", "CPU time, user plus system.",
           {k: t["cpu_seconds"] for k, t in totals.items()})
    family("mac_browser_energy_joules_total", "counter", "Billed energy.",
           {k: t["energy_joules"] for k, t in totals.items()})
    family("mac_browser_wakeups_total", "counter", "Idle and interrupt wakeups.",
           {k: t["wakeups"] for k, t in totals.items()})
    family("mac_browser_disk_read_bytes_total", "counter", "Bytes read from disk.",
           {k: t["disk_read_bytes"] for k, t in totals.items()})
    family("mac_browser_disk_written_bytes_total", "counter", "Bytes written to disk.",
           {k: t["disk_written_bytes"] for k, t in totals.items()})

    atomic_write(os.path.join(textfile_dir, "browsers.prom"), "\n".join(lines) + "\n")
    state = {
        "processes": {str(pid): {c: row[c] for c in ("start", *COUNTERS)} for pid, row in rows.items()},
        "totals": totals,
    }
    atomic_write(state_path, json.dumps(state))


main()
