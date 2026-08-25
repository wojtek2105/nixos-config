#!/usr/bin/env python3

import argparse
import csv
import datetime as dt
import gc
import json
import math
import os
import platform
import re
import shutil
import statistics
import subprocess
import time
import xml.etree.ElementTree as ET
from pathlib import Path


SOURCES = {
    "sched_ext/scx": "https://github.com/sched-ext/scx",
    "scx_bpfland": "https://github.com/sched-ext/scx/tree/main/scheds/rust/scx_bpfland",
    "scx_lavd": "https://github.com/sched-ext/scx/tree/main/scheds/rust/scx_lavd",
    "SCX 1.1.2 release": "https://github.com/sched-ext/scx/releases/tag/v1.1.2",
    "scx_lavd 1.1.3 regression": "https://github.com/sched-ext/scx/issues/3750",
    "scx_flash": "https://github.com/sched-ext/scx/tree/main/scheds/rust/scx_flash",
    "stress-ng": "https://github.com/ColinIanKing/stress-ng",
    "SuperTuxKart": "https://github.com/supertuxkart/stk-code",
    "SuperTuxKart Vulkan fixed-pipeline issue": "https://github.com/supertuxkart/stk-code/issues/4815",
    "SuperTuxKart performance testing": "https://supertuxkart.net/Performance_testing",
    "OpenBenchmarking SuperTuxKart": "https://openbenchmarking.org/test/pts/supertuxkart",
    "Mesa DRI_PRIME": "https://docs.mesa3d.org/envvars.html#envvar-DRI_PRIME",
    "Mesa Vulkan present mode": "https://docs.mesa3d.org/envvars.html#envvar-MESA_VK_WSI_PRESENT_MODE",
    "GameMode": "https://github.com/FeralInteractive/gamemode",
}

PROFILE_LABELS = {
    "desktop-cpu": "CPU — pulpit",
    "gaming-cpu": "CPU — granie",
    "gpu": "GPU",
}

SCHEDULER_LABELS = {
    "eevdf": "EEVDF",
    "bpfland": "scx_bpfland",
    "lavd": "scx_lavd",
    "flash": "scx_flash",
}


def now_iso():
    return dt.datetime.now().astimezone().isoformat(timespec="seconds")


def write_json(path, value):
    destination = Path(path)
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_text(
        json.dumps(value, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )


def command_output(command, cwd=None, timeout=5):
    try:
        result = subprocess.run(
            command,
            cwd=cwd,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            timeout=timeout,
            check=False,
        )
    except (FileNotFoundError, subprocess.TimeoutExpired):
        return "niedostępne"

    output = result.stdout.strip()
    return output if output else "niedostępne"


def first_line(value):
    return value.splitlines()[0] if value else "niedostępne"


def read_supertuxkart_version():
    output = command_output(["supertuxkart", "--version"])
    clean_output = re.sub(r"\x1b\[[0-?]*[ -/]*[@-~]", "", output)
    match = re.search(
        r"(?i)supertuxkart(?:\s+version)?[-\s:=v]*([0-9]+(?:\.[0-9]+)+)",
        clean_output,
    )
    if match:
        return f"SuperTuxKart {match.group(1)}"

    executable = shutil.which("supertuxkart")
    if executable:
        resolved = str(Path(executable).resolve())
        match = re.search(r"/[^/]+-supertuxkart-([0-9][^/]*)/", resolved)
        if match:
            return f"SuperTuxKart {match.group(1)}"
    return first_line(clean_output)


def read_os_release():
    path = Path("/etc/os-release")
    if not path.exists():
        return platform.system()

    values = {}
    for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
        if "=" not in line:
            continue
        key, value = line.split("=", 1)
        values[key] = value.strip().strip('"')
    return values.get("PRETTY_NAME", values.get("NAME", platform.system()))


def read_cpu_model():
    cpuinfo = Path("/proc/cpuinfo")
    if not cpuinfo.exists():
        return platform.processor() or "niedostępne"
    for line in cpuinfo.read_text(encoding="utf-8", errors="replace").splitlines():
        if line.lower().startswith("model name") and ":" in line:
            return line.split(":", 1)[1].strip()
    return platform.processor() or "niedostępne"


def read_memory_gib():
    meminfo = Path("/proc/meminfo")
    if not meminfo.exists():
        return None
    for line in meminfo.read_text(encoding="utf-8", errors="replace").splitlines():
        if line.startswith("MemTotal:"):
            kib = int(line.split()[1])
            return round(kib / 1024 / 1024, 2)
    return None


def read_power_source():
    root = Path("/sys/class/power_supply")
    battery_present = False
    external_power = False
    if not root.exists():
        return "external"

    external_types = {
        "Mains",
        "UPS",
        "USB",
        "USB_DCP",
        "USB_CDP",
        "USB_ACA",
        "USB_C",
        "USB_PD",
        "USB_PD_DRP",
        "Apple_Brick_ID",
        "Wireless",
    }
    for supply in root.iterdir():
        try:
            supply_type = (supply / "type").read_text().strip()
        except OSError:
            continue
        if supply_type == "Battery":
            battery_present = True
        elif supply_type in external_types:
            try:
                external_power |= (supply / "online").read_text().strip() == "1"
            except OSError:
                pass
    return "battery" if battery_present and not external_power else "external"


def read_governor():
    path = Path("/sys/devices/system/cpu/cpu0/cpufreq/scaling_governor")
    try:
        return path.read_text().strip()
    except OSError:
        return "niedostępne"


def read_display():
    raw = command_output(["hyprctl", "monitors", "-j"])
    if raw == "niedostępne":
        return {"mode": "niedostępne", "refresh_hz": None}
    try:
        monitors = [monitor for monitor in json.loads(raw) if not monitor.get("disabled")]
    except (json.JSONDecodeError, TypeError):
        return {"mode": "niedostępne", "refresh_hz": None}
    if not monitors:
        return {"mode": "niedostępne", "refresh_hz": None}
    monitor = max(
        monitors,
        key=lambda item: (item.get("width", 0) * item.get("height", 0), item.get("refreshRate", 0)),
    )
    width = int(monitor.get("width", 0))
    height = int(monitor.get("height", 0))
    refresh = monitor.get("refreshRate")
    mode = f"{width}x{height}" if width and height else "niedostępne"
    return {
        "mode": mode,
        "refresh_hz": round(float(refresh), 3) if refresh is not None else None,
    }


def metadata_command(args):
    gpu_lines = []
    for line in command_output(["lspci"], timeout=10).splitlines():
        if re.search(r"VGA compatible controller|3D controller|Display controller", line):
            gpu_lines.append(line.split(": ", 1)[-1])

    repo_root = Path(args.repo_root).resolve()
    git_revision = first_line(command_output(["git", "rev-parse", "--short", "HEAD"], cwd=repo_root))
    git_status = command_output(["git", "status", "--short"], cwd=repo_root)
    git_dirty = git_status not in {"", "niedostępne"}

    tool_versions = {
        "stress-ng": first_line(command_output(["stress-ng", "--version"])),
        "SuperTuxKart": read_supertuxkart_version(),
        "systemd": first_line(command_output(["systemctl", "--version"])),
        "scx_bpfland": first_line(command_output(["scx_bpfland", "--version"])),
        "scx_lavd": first_line(command_output(["scx_lavd", "--version"])),
        "scx_flash": first_line(command_output(["scx_flash", "--version"])),
    }

    metadata = {
        "created_at": now_iso(),
        "os": read_os_release(),
        "kernel": platform.release(),
        "architecture": platform.machine(),
        "cpu": read_cpu_model(),
        "logical_cpus": os.cpu_count(),
        "memory_gib": read_memory_gib(),
        "gpu": gpu_lines or ["niedostępne"],
        "display": read_display(),
        "power_source": read_power_source(),
        "cpu_governor_before": read_governor(),
        "power_profile_before": first_line(command_output(["powerprofilesctl", "get"])),
        "original_sched_ext_state": args.original_state,
        "original_scheduler": args.original_ops,
        "git_revision": git_revision,
        "git_dirty": git_dirty,
        "runs_per_scheduler": args.runs,
        "schedulers": args.schedulers.split(","),
        "profiles": args.profiles.split(","),
        "desktop_duration_seconds": args.desktop_duration,
        "desktop_period_microseconds": args.desktop_period_us,
        "cooldown_seconds": args.cooldown,
        "gaming_size": args.gaming_size,
        "gpu_size": args.gpu_size,
        "gpu_prime": args.gpu_prime,
        "benchmark_engine": "supertuxkart-1.5-replay",
        "game_benchmark": {
            "replay": "benchmark_black_forest.replay",
            "renderers": {
                "gaming_cpu": "vulkan",
                "gpu": "opengl",
            },
            "window_system": "wayland",
            "vsync": False,
            "max_fps": 9999,
            "gaming_cpu_mesa_present_mode": "immediate",
            "gpu_swap_interval": 0,
            "gpu_gfx_preset": 7,
            "fullscreen_mode": {
                "gaming_cpu": "sdl-fullscreen-desktop",
                "gpu": "hyprland-maximized-then-fullscreen",
            },
            "config_schema": 8,
            "telemetry": "supertuxkart-profiler",
            "gaming_cpu_quality": "low",
            "gpu_quality": "ultimate",
            "warmup_replays": True,
        },
        "tool_versions": tool_versions,
        "sources": SOURCES,
    }
    write_json(args.output, metadata)


def percentile(values, fraction):
    if not values:
        return None
    ordered = sorted(values)
    index = max(0, min(len(ordered) - 1, math.ceil(fraction * len(ordered)) - 1))
    return ordered[index]


def latency_command(args):
    period_ns = args.period_us * 1000
    warmup_end = time.perf_counter_ns() + int(args.warmup * 1_000_000_000)
    while True:
        remaining = warmup_end - time.perf_counter_ns()
        if remaining <= 0:
            break
        time.sleep(remaining / 1_000_000_000)

    gc.disable()
    latencies_ns = []
    missed_periods = 0
    started_ns = time.perf_counter_ns()
    deadline_ns = started_ns + period_ns
    finish_ns = started_ns + int(args.duration * 1_000_000_000)

    while deadline_ns <= finish_ns:
        remaining_ns = deadline_ns - time.perf_counter_ns()
        if remaining_ns > 0:
            time.sleep(remaining_ns / 1_000_000_000)
        woke_ns = time.perf_counter_ns()
        lateness_ns = max(0, woke_ns - deadline_ns)
        latencies_ns.append(lateness_ns)
        if lateness_ns >= period_ns:
            skipped = lateness_ns // period_ns
            missed_periods += skipped
            deadline_ns += skipped * period_ns
        deadline_ns += period_ns
    gc.enable()

    latencies_us = [value / 1000 for value in latencies_ns]
    expected_samples = max(1, int(args.duration * 1_000_000 / args.period_us))
    result = {
        "profile": "desktop-cpu",
        "scheduler": args.scheduler,
        "run": args.run,
        "status": "complete" if latencies_us else "failed",
        "started_at": args.started_at,
        "finished_at": now_iso(),
        "active_ops": args.active_ops,
        "scheduler_args": args.scheduler_args,
        "raw_log": args.raw_log,
        "workload": {
            "duration_seconds": args.duration,
            "period_microseconds": args.period_us,
            "background_workers": args.background_workers,
        },
        "metrics": {
            "samples": len(latencies_us),
            "latency_mean_us": statistics.fmean(latencies_us) if latencies_us else None,
            "latency_p50_us": percentile(latencies_us, 0.50),
            "latency_p95_us": percentile(latencies_us, 0.95),
            "latency_p99_us": percentile(latencies_us, 0.99),
            "latency_p999_us": percentile(latencies_us, 0.999),
            "latency_max_us": max(latencies_us) if latencies_us else None,
            "missed_periods": missed_periods,
            "missed_deadline_pct": 100 * missed_periods / expected_samples,
        },
    }
    write_json(args.output, result)


def as_float(value):
    if value is None:
        return None
    try:
        return float(str(value).strip())
    except (TypeError, ValueError):
        return None


def parse_stk_benchmark(text):
    match = re.search(
        r"Frame count\s*'(?P<frames>[0-9]+)'.*?"
        r"Time \(ms\)\s*'(?P<time>[0-9]+)'.*?"
        r"Steady FPS\s*'(?P<steady>[0-9]+(?:\.[0-9]+)?)'.*?"
        r"Mostly (?:stable|steady) FPS\s*'(?P<mostly>[0-9]+(?:\.[0-9]+)?)'.*?"
        r"Typical FPS\s*'(?P<typical>[0-9]+(?:\.[0-9]+)?)'",
        text,
        flags=re.IGNORECASE | re.DOTALL,
    )
    if not match:
        return {}
    result = {
        "frame_count": int(match.group("frames")),
        "benchmark_time_ms": int(match.group("time")),
        "steady_fps": float(match.group("steady")),
        "mostly_steady_fps": float(match.group("mostly")),
        "typical_fps": float(match.group("typical")),
    }
    if result["benchmark_time_ms"] > 0:
        result["average_fps"] = (
            result["frame_count"] * 1000 / result["benchmark_time_ms"]
        )
    return result


def stk_one_percent_low(rows, frame_count, benchmark_time_ms):
    """Estimate average FPS of the slowest 1% from STK's cumulative table."""
    target_count = max(1, math.ceil(frame_count * 0.01))
    previous_count = 0
    previous_duration_ms = 0.0

    for row in rows:
        if len(row) < 3:
            continue
        target_fps = as_float(row[0])
        slow_count_value = as_float(row[1])
        duration_ratio = as_float(row[2])
        if target_fps is None or slow_count_value is None or duration_ratio is None:
            continue

        slow_count = int(slow_count_value)
        slow_duration_ms = duration_ratio * benchmark_time_ms
        if slow_count < previous_count or slow_duration_ms < previous_duration_ms:
            continue
        if slow_count < target_count:
            previous_count = slow_count
            previous_duration_ms = slow_duration_ms
            continue

        added_count = slow_count - previous_count
        if added_count <= 0:
            selected_duration_ms = slow_duration_ms
        else:
            fraction = (target_count - previous_count) / added_count
            selected_duration_ms = previous_duration_ms + fraction * (
                slow_duration_ms - previous_duration_ms
            )
        if selected_duration_ms <= 0:
            return None
        return target_count * 1000 / selected_duration_ms

    return None


def parse_stk_csv(path):
    report = Path(path)
    if not report.exists():
        return {}
    with report.open(newline="", encoding="utf-8", errors="replace") as handle:
        rows = list(csv.reader(handle))
    result = {}
    frame_count = None
    benchmark_time_ms = None
    threshold_rows = []

    for index, row in enumerate(rows[:-1]):
        labels = [cell.strip().lower() for cell in row]
        if not labels:
            continue
        if labels[0] == "total frame count":
            values = [as_float(cell) for cell in rows[index + 1]]
            numeric = [value for value in values if value is not None]
            if len(numeric) >= 2:
                frame_count = int(numeric[0])
                benchmark_time_ms = numeric[1]
        elif "steady fps" in labels[0]:
            values = [as_float(cell) for cell in rows[index + 1]]
            numeric = [value for value in values if value is not None]
            if len(numeric) >= 3:
                result.update(
                    {
                        "steady_fps": numeric[0],
                        "mostly_steady_fps": numeric[1],
                        "typical_fps": numeric[2],
                    }
                )
        elif labels[0] == "target fps" and len(labels) >= 3:
            threshold_rows = rows[index + 1 :]

    if frame_count is not None and benchmark_time_ms is not None:
        result["frame_count"] = frame_count
        result["benchmark_time_ms"] = benchmark_time_ms
        if benchmark_time_ms > 0:
            result["average_fps"] = frame_count * 1000 / benchmark_time_ms
            one_percent_low = stk_one_percent_low(
                threshold_rows,
                frame_count,
                benchmark_time_ms,
            )
            if one_percent_low is not None:
                result["one_percent_low_fps"] = one_percent_low
    return result


def parse_stk_graphics_parameters(path):
    report = Path(path)
    if not report.exists():
        return {}
    with report.open(newline="", encoding="utf-8", errors="replace") as handle:
        rows = list(csv.reader(handle))

    for index, row in enumerate(rows[:-1]):
        if not row or row[0].strip().lower() != "graphics parameters":
            continue
        names = [cell.strip() for cell in row[1:] if cell.strip()]
        values = [cell.strip() for cell in rows[index + 1][1:]]
        return dict(zip(names, values))
    return {}


def parse_stk_video_parameters(path):
    config = Path(path)
    if not config.exists():
        return {}
    try:
        root = ET.parse(config).getroot()
    except (ET.ParseError, OSError):
        return {}
    video = root.find("Video")
    return dict(video.attrib) if video is not None else {}


def validate_render_target(parameters, size):
    if not parameters:
        return ["Brak końcowych parametrów Video STK"]
    try:
        expected_width, expected_height = size.lower().split("x", 1)
    except ValueError:
        return [f"Nieprawidłowy rozmiar profilu gry: {size}"]

    actual_width = parameters.get("width")
    actual_height = parameters.get("height")
    if (actual_width, actual_height) != (expected_width, expected_height):
        return [
            "Faktyczny render target STK ma rozmiar "
            f"{actual_width or 'brak'}x{actual_height or 'brak'}, "
            f"oczekiwano {expected_width}x{expected_height}"
        ]
    return []


def validate_gpu_ultimate_graphics(parameters, size):
    if not parameters:
        return ["Raport STK nie zawiera parametrów graficznych"]

    expected = {
        "Render resolution": "1",
        "Dynamic lighting": "1",
        "Particle effects": "2",
        "Animated characters": "1",
        "Geometry Detail": "5",
        "Bloom": "1",
        "Glow": "1",
        "Light Shaft": "1",
        "Anti-Aliasing (MLAA)": "1",
        "SSAO": "1",
        "Anisotropic Filtering": "16",
        "Light scattering": "1",
        "Degraded IBL": "0",
        "Motion Blur": "1",
        "Depth of Field": "1",
        "Texture compression": "1",
        "HD Textures": "3",
        "HQ Mipmap": "1",
    }
    try:
        width, height = size.lower().split("x", 1)
        expected["Resolution width"] = width
        expected["Resolution height"] = height
    except ValueError:
        return [f"Nieprawidłowy rozmiar profilu GPU: {size}"]

    mismatches = [
        f"{name}={parameters.get(name, 'brak')} (oczekiwano {value})"
        for name, value in expected.items()
        if parameters.get(name) != value
    ]
    shadow_resolution = as_float(parameters.get("Shadow Resolution"))
    if shadow_resolution is None or shadow_resolution < 1024:
        mismatches.append(
            "Shadow Resolution="
            f"{parameters.get('Shadow Resolution', 'brak')} (oczekiwano co najmniej 1024)"
        )
    if mismatches:
        return ["Profil GPU nie odpowiada Ultimate: " + ", ".join(mismatches)]
    return []


def scheduler_matches_active_ops(scheduler, active_ops):
    normalized = active_ops.lower()
    if scheduler == "eevdf":
        return normalized == "eevdf"
    return scheduler.lower() in normalized


def validate_game_prewarm_command(args):
    internal_log = Path(args.internal_log)
    text = (
        internal_log.read_text(encoding="utf-8", errors="replace")
        if internal_log.exists()
        else ""
    )
    metrics = parse_stk_csv(args.benchmark_report)
    graphics_parameters = parse_stk_graphics_parameters(args.benchmark_report)
    video_parameters = parse_stk_video_parameters(args.config)
    errors = []
    required_metrics = (
        "average_fps",
        "one_percent_low_fps",
        "steady_fps",
        "mostly_steady_fps",
        "typical_fps",
    )
    if not all(name in metrics for name in required_metrics):
        errors.append("Rozgrzewka nie zapisała pełnych metryk STK")
    expected_renderer = "Vulkan" if args.renderer == "vulkan" else "OpenGL"
    if not re.search(
        rf"{expected_renderer} renderer:\s*(.+)", text, flags=re.IGNORECASE
    ):
        errors.append(f"Rozgrzewka nie potwierdziła renderera {expected_renderer}")
    if args.renderer == "opengl":
        if not re.search(r"GLSL supported", text, flags=re.IGNORECASE):
            errors.append("Rozgrzewka nie potwierdziła shaderów GLSL")
        if re.search(r"Using the fixed pipeline", text, flags=re.IGNORECASE):
            errors.append("Rozgrzewka uruchomiła niedozwolony fixed pipeline")
    if args.profile == "gpu" and args.quality == "ultimate":
        errors.extend(validate_gpu_ultimate_graphics(graphics_parameters, args.size))
    errors.extend(validate_render_target(video_parameters, args.size))
    if errors:
        raise SystemExit("; ".join(errors))


def game_command(args):
    log_paths = [Path(args.log), Path(args.internal_log)]
    text = "\n".join(
        path.read_text(encoding="utf-8", errors="replace")
        for path in log_paths
        if path.exists()
    )
    metrics = parse_stk_csv(args.benchmark_report)
    metrics.update(parse_stk_benchmark(text))
    graphics_parameters = parse_stk_graphics_parameters(args.benchmark_report)
    video_parameters = parse_stk_video_parameters(args.config)

    renderer_match = re.search(
        r"(?:Vulkan|OpenGL) renderer:\s*(.+)", text, flags=re.IGNORECASE
    )
    render_gpu = renderer_match.group(1).strip() if renderer_match else "niedostępne"

    errors = []
    required_metrics = (
        "average_fps",
        "one_percent_low_fps",
        "steady_fps",
        "mostly_steady_fps",
        "typical_fps",
    )
    if not all(name in metrics for name in required_metrics):
        errors.append("Brak pełnych końcowych metryk benchmarku SuperTuxKart")
    expected_renderer = "Vulkan" if args.renderer == "vulkan" else "OpenGL"
    if not re.search(
        rf"{expected_renderer} renderer:\s*(.+)", text, flags=re.IGNORECASE
    ):
        errors.append(f"STK nie potwierdził renderera {expected_renderer}")
    if args.renderer == "opengl":
        if not re.search(r"GLSL supported", text, flags=re.IGNORECASE):
            errors.append("OpenGL nie potwierdził obsługi shaderów GLSL")
        if re.search(r"Using the fixed pipeline", text, flags=re.IGNORECASE):
            errors.append("OpenGL uruchomił niedozwolony fixed pipeline")
    if args.profile == "gpu" and args.quality == "ultimate":
        errors.extend(validate_gpu_ultimate_graphics(graphics_parameters, args.size))
    errors.extend(validate_render_target(video_parameters, args.size))
    if args.process_exit != 0:
        errors.append(f"SuperTuxKart zakończył się kodem {args.process_exit}")
    if not scheduler_matches_active_ops(args.scheduler, args.active_ops):
        errors.append(
            f"Scheduler przestał działać podczas próby: oczekiwano {args.scheduler}, "
            f"aktywny był {args.active_ops}"
        )

    raw_parent = Path(args.raw_log).parent
    result = {
        "profile": args.profile,
        "scheduler": args.scheduler,
        "run": args.run,
        "status": "failed" if errors else "complete",
        "started_at": args.started_at,
        "finished_at": now_iso(),
        "active_ops": args.active_ops,
        "scheduler_args": args.scheduler_args,
        "raw_log": args.raw_log,
        "internal_log": str(raw_parent / Path(args.internal_log).name),
        "benchmark_report": (
            str(raw_parent / Path(args.benchmark_report).name)
            if Path(args.benchmark_report).exists()
            else None
        ),
        "render_gpu": render_gpu,
        "graphics_parameters": graphics_parameters,
        "video_parameters": video_parameters,
        "workload": {
            "engine": "SuperTuxKart",
            "replay": "benchmark_black_forest.replay",
            "size": args.size,
            "quality": args.quality,
            "renderer": args.renderer,
            "gpu_prime": args.gpu_prime,
            "background_workers": args.background_workers,
            "gamemode": args.gamemode,
        },
        "metrics": metrics,
    }
    if errors:
        result["error"] = "; ".join(errors)
    write_json(args.output, result)
    if errors:
        raise SystemExit(1)


def failure_command(args):
    write_json(
        args.output,
        {
            "profile": args.profile,
            "scheduler": args.scheduler,
            "run": args.run,
            "status": "failed",
            "started_at": args.started_at,
            "finished_at": now_iso(),
            "active_ops": args.active_ops,
            "scheduler_args": args.scheduler_args,
            "raw_log": args.raw_log,
            "error": args.error,
            "metrics": {},
        },
    )


def format_number(value, digits=2):
    if value is None:
        return "—"
    if isinstance(value, int):
        return str(value)
    if isinstance(value, float):
        return f"{value:.{digits}f}"
    return str(value)


def markdown_escape(value):
    return str(value).replace("|", "\\|").replace("\n", " ")


def aggregate(results, profile, scheduler, metric):
    values = []
    for result in results:
        if result.get("profile") != profile or result.get("scheduler") != scheduler:
            continue
        if result.get("status") != "complete":
            continue
        value = result.get("metrics", {}).get(metric)
        if isinstance(value, (int, float)):
            values.append(float(value))
    if not values:
        return None
    return {
        "count": len(values),
        "mean": statistics.fmean(values),
        "stdev": statistics.stdev(values) if len(values) > 1 else 0.0,
        "min": min(values),
        "max": max(values),
    }


def mean_cell(results, profile, scheduler, metric, digits=2):
    stats = aggregate(results, profile, scheduler, metric)
    if stats is None:
        return "—"
    return f"{stats['mean']:.{digits}f} ± {stats['stdev']:.{digits}f}"


def completed_count(results, profile, scheduler):
    return sum(
        1
        for result in results
        if result.get("profile") == profile
        and result.get("scheduler") == scheduler
        and result.get("status") == "complete"
    )


def automatic_conclusion(results, profile, schedulers):
    metric = "latency_p99_us" if profile == "desktop-cpu" else "mostly_steady_fps"
    lower_is_better = profile == "desktop-cpu"
    candidates = []
    for scheduler in schedulers:
        stats = aggregate(results, profile, scheduler, metric)
        if stats:
            candidates.append((scheduler, stats))
    if not candidates:
        return "Brak kompletnych wyników do automatycznego porównania."

    best_scheduler, best_stats = (
        min(candidates, key=lambda item: item[1]["mean"])
        if lower_is_better
        else max(candidates, key=lambda item: item[1]["mean"])
    )
    baseline = next((stats for scheduler, stats in candidates if scheduler == "eevdf"), None)
    result = f"Najlepszą średnią ma **{SCHEDULER_LABELS.get(best_scheduler, best_scheduler)}**"
    result += f" ({best_stats['mean']:.2f})."
    if baseline and baseline["mean"]:
        if lower_is_better:
            delta = 100 * (baseline["mean"] - best_stats["mean"]) / baseline["mean"]
            result += f" Względem EEVDF mierzona wartość jest niższa o {delta:.2f}%."
        else:
            delta = 100 * (best_stats["mean"] - baseline["mean"]) / baseline["mean"]
            result += f" Względem EEVDF mierzona wartość jest wyższa o {delta:.2f}%."
        noise = max(best_stats["stdev"], baseline["stdev"])
        if abs(best_stats["mean"] - baseline["mean"]) <= noise:
            result += " Różnica mieści się jednak w rozrzucie pojedynczych przebiegów."
    if min(stats["count"] for _, stats in candidates) < 3:
        result += " Wynik jest wstępny: wykonano mniej niż trzy kompletne przebiegi na scheduler."
    return result


def load_results(directory):
    results = []
    for path in sorted(Path(directory).glob("*.json")):
        try:
            results.append(json.loads(path.read_text(encoding="utf-8")))
        except (json.JSONDecodeError, OSError):
            continue
    return results


def write_results_csv(path, results):
    metric_names = sorted(
        {
            metric
            for result in results
            for metric in result.get("metrics", {}).keys()
        }
    )
    fields = [
        "profile",
        "scheduler",
        "run",
        "status",
        "started_at",
        "finished_at",
        "active_ops",
        "scheduler_args",
        "render_gpu",
        "raw_log",
        "internal_log",
        "benchmark_report",
        "error",
    ] + metric_names
    destination = Path(path)
    destination.parent.mkdir(parents=True, exist_ok=True)
    with destination.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fields)
        writer.writeheader()
        for result in results:
            row = {field: result.get(field, "") for field in fields}
            row["scheduler_args"] = result.get("scheduler_args", "")
            row.update(result.get("metrics", {}))
            writer.writerow(row)


def report_command(args):
    results = load_results(args.results_dir)
    metadata = json.loads(Path(args.metadata).read_text(encoding="utf-8"))
    schedulers = metadata.get("schedulers", [])
    profiles = metadata.get("profiles", [])
    game_benchmark = metadata.get("game_benchmark", {})
    renderers = game_benchmark.get("renderers", {})
    legacy_renderer = game_benchmark.get("renderer", "vulkan")
    gaming_renderer = renderers.get("gaming_cpu", legacy_renderer)
    gpu_renderer = renderers.get("gpu", legacy_renderer)
    render_gpus = sorted(
        {
            result.get("render_gpu")
            for result in results
            if result.get("render_gpu") not in {None, "", "niedostępne"}
        }
    )
    write_results_csv(args.csv, results)

    lines = [
        f"# Benchmark schedulerów — {metadata.get('created_at', now_iso())}",
        "",
        "> Raport wygenerowany automatycznie. Każdy wiersz podsumowania pokazuje średnią ± odchylenie standardowe.",
        "",
        "## Środowisko",
        "",
        "| Parametr | Wartość |",
        "| --- | --- |",
        f"| System | {markdown_escape(metadata.get('os', '—'))} |",
        f"| Kernel | `{markdown_escape(metadata.get('kernel', '—'))}` |",
        f"| CPU | {markdown_escape(metadata.get('cpu', '—'))} ({metadata.get('logical_cpus', '—')} logicznych CPU) |",
        f"| RAM | {format_number(metadata.get('memory_gib'))} GiB |",
        f"| GPU | {markdown_escape('; '.join(metadata.get('gpu', ['—'])))} |",
        f"| Monitor | {markdown_escape(metadata.get('display', {}).get('mode', '—'))} @ {format_number(metadata.get('display', {}).get('refresh_hz'))} Hz |",
        f"| Zasilanie | `{metadata.get('power_source', '—')}` |",
        f"| Governor przed testem | `{metadata.get('cpu_governor_before', '—')}` |",
        f"| Profil zasilania przed testem | `{metadata.get('power_profile_before', '—')}` |",
        f"| Scheduler przed testem | `{metadata.get('original_scheduler', '—')}` (`{metadata.get('original_sched_ext_state', '—')}`) |",
        f"| Rewizja konfiguracji | `{metadata.get('git_revision', '—')}`; dirty: `{str(metadata.get('git_dirty', False)).lower()}` |",
        f"| Powtórzenia | {metadata.get('runs_per_scheduler', '—')} na scheduler i profil |",
    ]
    selected_scx_versions = [
        metadata.get("tool_versions", {}).get(SCHEDULER_LABELS[scheduler], "niedostępne")
        for scheduler in schedulers
        if scheduler in SCHEDULER_LABELS and scheduler != "eevdf"
    ]
    if selected_scx_versions:
        lines.append(
            f"| Wersje schedulerów SCX | {markdown_escape('; '.join(selected_scx_versions))} |"
        )
    if render_gpus:
        lines.append(f"| GPU renderujące | {markdown_escape('; '.join(render_gpus))} |")

    lines.extend(["", "## Metodologia", ""])
    if "desktop-cpu" in profiles:
        lines.append(
            f"- **CPU — pulpit:** okresowy próbnik użytkowy co {metadata.get('desktop_period_microseconds', '—')} µs podczas obciążenia `stress-ng` na wszystkich poza dwoma logicznymi CPU. Niższe p95/p99 i mniej przekroczonych okresów oznaczają sprawniejszą obsługę krótkich zadań interaktywnych."
        )
    gaming_renderer_label = "Vulkanie" if gaming_renderer == "vulkan" else "OpenGL"
    if "gaming-cpu" in profiles:
        lines.append(
            f"- **CPU — granie:** wbudowany replay `benchmark_black_forest.replay` z SuperTuxKart 1.5 działa w {gaming_renderer_label}, {metadata.get('gaming_size', '—')} i niskiej jakości równocześnie z pełnym obciążeniem CPU. To faktyczna pętla gry, a nie mikrobenchmark renderera."
        )
        lines.append(
            "- Rozgrzewka i każda punktowana próba profilu CPU sprawdzają końcowy "
            "render target `width` × `height` zapisany przez STK. Próba z inną "
            "faktyczną rozdzielczością jest odrzucana zamiast trafiać do agregatów."
        )
    if "gpu" in profiles:
        if gpu_renderer == "opengl":
            lines.append(
                f"- **GPU:** ten sam deterministyczny replay działa w shaderowym OpenGL, "
                f"natywnym presecie 7 (Ultimate) i rozdzielczości "
                f"{metadata.get('gpu_size', '—')}, bez sztucznego obciążenia CPU. "
                f"Wybór Mesa `{metadata.get('gpu_prime', 'default')}` jest zapisany "
                "razem z nazwą GPU odczytaną z logu gry."
            )
            lines.append(
                "- Pełna izolowana konfiguracja STK w schemacie v8 ustawia renderer "
                "i bazową jakość przed utworzeniem urządzenia graficznego. Profil GPU "
                "jest odrzucany, jeśli log nie potwierdzi shaderowego OpenGL albo raport "
                "CSV nie zawiera parametrów Ultimate. Na Hyprlandzie harness czeka na "
                "wczytanie replayu i ustanie logów ładowania, a następnie — jeszcze w "
                "niemierzonej fazie SET — przez aktualne API Lua Hyprlanda przełącza "
                "okno kolejno jak działające skróty: toggle maximized i toggle pełnego "
                "fullscreen. Stan oraz logiczny rozmiar okna są potwierdzane przez "
                "Hyprland przed pomiarem, a końcowy render target `width` × `height` z "
                "konfiguracji STK musi odpowiadać rozdzielczości profilu. MangoHud nie "
                "jest wstrzykiwany do procesu, aby jego asynchroniczny logger nie "
                "wpływał na stabilność wyjścia gry."
            )
        else:
            lines.append(
                f"- **GPU:** ten sam deterministyczny replay działa w Vulkanie, "
                f"ustawieniu Ultimate i rozdzielczości {metadata.get('gpu_size', '—')}, "
                "bez sztucznego obciążenia CPU. "
                f"Wybór Mesa `{metadata.get('gpu_prime', 'default')}` jest zapisany "
                "razem z nazwą GPU odczytaną z logu gry."
            )
            lines.append(
                "- Pełna izolowana konfiguracja STK w schemacie v8 ustawia jakość przed "
                "utworzeniem urządzenia Vulkan. MangoHud nie jest wstrzykiwany do procesu, "
                "aby jego asynchroniczny logger nie wpływał na stabilność wyjścia gry."
            )

    game_profiles_selected = "gaming-cpu" in profiles or "gpu" in profiles
    if game_profiles_selected:
        if "gaming-cpu" in profiles and "gpu" in profiles:
            lines.append(
                "- V-Sync jest wyłączony w izolowanym profilu STK, a limit gry wynosi "
                "9999 FPS. Vulkan profilu CPU używa trybu prezentacji Mesa `immediate`; "
                "profil GPU używa OpenGL z interwałem wymiany 0 i `vblank_mode=0`. "
                "Wynik nie zatrzymuje się na odświeżaniu monitora."
            )
        elif "gaming-cpu" in profiles:
            lines.append(
                "- V-Sync jest wyłączony w izolowanym profilu STK, limit gry wynosi "
                "9999 FPS, a Mesa Vulkan używa trybu prezentacji `immediate`. Wynik "
                "nie zatrzymuje się na odświeżaniu monitora."
            )
        elif gpu_renderer == "opengl":
            lines.append(
                "- V-Sync jest wyłączony w izolowanym profilu STK, limit gry wynosi "
                "9999 FPS, a OpenGL używa interwału wymiany 0 i `vblank_mode=0`. "
                "Wynik nie zatrzymuje się na odświeżaniu monitora."
            )
        else:
            lines.append(
                "- V-Sync jest wyłączony w izolowanym profilu STK, limit gry wynosi "
                "9999 FPS, a Mesa Vulkan używa trybu prezentacji `immediate`. Wynik "
                "nie zatrzymuje się na odświeżaniu monitora."
            )
        lines.extend(
            [
                "- Average FPS jest liczone z liczby klatek i całkowitego czasu replayu. 1% Low FPS to średni FPS najwolniejszego 1% klatek, odtworzony z tabeli skumulowanej liczby i czasu wolnych klatek profilera STK; liniowa interpolacja ostatniego koszyka ogranicza błąd wynikający z progów co 1 FPS.",
                "- Natywne miary profilera STK uzupełniają standardowe wyniki: Steady FPS premiuje brak stutteru, Mostly Steady FPS równoważy płynność i wydajność, a Typical FPS opisuje typową wydajność. Automatyczny wniosek używa Mostly Steady FPS.",
                f"- Przed właściwymi pomiarami każdy wybrany wariant gry wykonuje jeden niepunktowany replay rozgrzewający cache zasobów i shaderów. Między próbami jest {metadata.get('cooldown_seconds', '—')} s przerwy, a kolejność schedulerów rotuje między rundami.",
            ]
        )
        lines.append(
            "- Profile gamingowe korzystają z GameMode. EEVDF oznacza wyłączony `sched_ext`; pozostałe schedulery działają jako tymczasowa usługa systemd. Próba jest odrzucana, jeżeli scheduler przestanie działać przed końcem replayu."
        )
    else:
        lines.append(
            "- EEVDF oznacza wyłączony `sched_ext`; pozostałe schedulery działają jako tymczasowa usługa systemd. Próba jest odrzucana, jeżeli scheduler przestanie działać przed końcem pomiaru."
        )
    lines.extend(
        [
            "",
            "### Źródła testów",
            "",
        ]
    )
    for name, url in metadata.get("sources", SOURCES).items():
        lines.append(f"- [{name}]({url})")

    profile_metric_tables = {
        "desktop-cpu": [
            ("latency_p50_us", "p50 [µs]", 1),
            ("latency_p95_us", "p95 [µs]", 1),
            ("latency_p99_us", "p99 [µs]", 1),
            ("latency_p999_us", "p99,9 [µs]", 1),
            ("latency_max_us", "maks. [µs]", 1),
            ("missed_deadline_pct", "pominięte okresy [%]", 3),
        ],
        "gaming-cpu": [
            ("average_fps", "Average FPS", 1),
            ("one_percent_low_fps", "1% Low FPS", 1),
            ("steady_fps", "Steady FPS", 1),
            ("mostly_steady_fps", "Mostly Steady FPS", 1),
            ("typical_fps", "Typical FPS", 1),
        ],
        "gpu": [
            ("average_fps", "Average FPS", 1),
            ("one_percent_low_fps", "1% Low FPS", 1),
            ("steady_fps", "Steady FPS", 1),
            ("mostly_steady_fps", "Mostly Steady FPS", 1),
            ("typical_fps", "Typical FPS", 1),
        ],
    }

    lines.extend(["", "## Podsumowanie"])
    for profile in profiles:
        metrics = profile_metric_tables.get(profile, [])
        lines.extend(
            [
                "",
                f"### {PROFILE_LABELS.get(profile, profile)}",
                "",
                automatic_conclusion(results, profile, schedulers),
                "",
                "| Scheduler | Próby | " + " | ".join(label for _, label, _ in metrics) + " |",
                "| --- | ---: | " + " | ".join("---:" for _ in metrics) + " |",
            ]
        )
        for scheduler in schedulers:
            cells = [
                mean_cell(results, profile, scheduler, metric, digits)
                for metric, _, digits in metrics
            ]
            lines.append(
                f"| {SCHEDULER_LABELS.get(scheduler, scheduler)} | {completed_count(results, profile, scheduler)} | "
                + " | ".join(cells)
                + " |"
            )

    lines.extend(["", "## Wszystkie przebiegi"])
    for profile in profiles:
        metrics = profile_metric_tables.get(profile, [])
        lines.extend(
            [
                "",
                f"### {PROFILE_LABELS.get(profile, profile)}",
                "",
                "| Scheduler | Runda | Stan | "
                + " | ".join(label for _, label, _ in metrics)
                + " | Log / błąd |",
                "| --- | ---: | --- | "
                + " | ".join("---:" for _ in metrics)
                + " | --- |",
            ]
        )
        profile_results = sorted(
            (result for result in results if result.get("profile") == profile),
            key=lambda result: (int(result.get("run", 0)), result.get("scheduler", "")),
        )
        for result in profile_results:
            cells = [
                format_number(result.get("metrics", {}).get(metric), digits)
                for metric, _, digits in metrics
            ]
            details = result.get("error") or result.get("raw_log", "—")
            lines.append(
                f"| {SCHEDULER_LABELS.get(result.get('scheduler'), result.get('scheduler', '—'))} "
                f"| {result.get('run', '—')} | {result.get('status', '—')} | "
                + " | ".join(cells)
                + f" | {markdown_escape(details)} |"
            )

    lines.extend(
        [
            "",
            "## Dane surowe",
            "",
            "- `results.csv` zawiera wszystkie metryki w formacie maszynowym.",
            "- `metadata.json` zapisuje środowisko i wersje narzędzi bez nazwy hosta ani użytkownika.",
            "- `raw/` zawiera pełne logi `stress-ng`, silnika gry, jego raport CSV oraz JSON każdego przebiegu.",
            "",
            "Replay STK jest rzeczywistym, powtarzalnym obciążeniem gry i nadaje się do selekcji kandydatów. Ostateczny wybór schedulera warto jeszcze potwierdzić w jednej z własnych wymagających gier, bo inny silnik może mieć inny rozkład wątków.",
            "",
        ]
    )
    destination = Path(args.output)
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_text("\n".join(lines), encoding="utf-8")


def build_parser():
    parser = argparse.ArgumentParser()
    subparsers = parser.add_subparsers(dest="command", required=True)

    metadata = subparsers.add_parser("metadata")
    metadata.add_argument("--output", required=True)
    metadata.add_argument("--repo-root", required=True)
    metadata.add_argument("--runs", required=True, type=int)
    metadata.add_argument("--schedulers", required=True)
    metadata.add_argument("--profiles", required=True)
    metadata.add_argument("--desktop-duration", required=True, type=int)
    metadata.add_argument("--desktop-period-us", required=True, type=int)
    metadata.add_argument("--cooldown", required=True, type=int)
    metadata.add_argument("--gaming-size", required=True)
    metadata.add_argument("--gpu-size", required=True)
    metadata.add_argument("--gpu-prime", required=True)
    metadata.add_argument("--original-state", required=True)
    metadata.add_argument("--original-ops", required=True)
    metadata.set_defaults(func=metadata_command)

    latency = subparsers.add_parser("latency")
    latency.add_argument("--output", required=True)
    latency.add_argument("--scheduler", required=True)
    latency.add_argument("--run", required=True, type=int)
    latency.add_argument("--duration", required=True, type=int)
    latency.add_argument("--period-us", required=True, type=int)
    latency.add_argument("--warmup", default=2.0, type=float)
    latency.add_argument("--background-workers", required=True, type=int)
    latency.add_argument("--active-ops", required=True)
    latency.add_argument("--scheduler-args", required=True)
    latency.add_argument("--raw-log", required=True)
    latency.add_argument("--started-at", required=True)
    latency.set_defaults(func=latency_command)

    validate_game_prewarm = subparsers.add_parser("validate-game-prewarm")
    validate_game_prewarm.add_argument(
        "--profile", choices=["gaming-cpu", "gpu"], required=True
    )
    validate_game_prewarm.add_argument(
        "--renderer", choices=["vulkan", "opengl"], required=True
    )
    validate_game_prewarm.add_argument(
        "--quality", choices=["low", "ultimate"], required=True
    )
    validate_game_prewarm.add_argument("--internal-log", required=True)
    validate_game_prewarm.add_argument("--benchmark-report", required=True)
    validate_game_prewarm.add_argument("--config", required=True)
    validate_game_prewarm.add_argument("--size", required=True)
    validate_game_prewarm.set_defaults(func=validate_game_prewarm_command)

    game = subparsers.add_parser("game")
    game.add_argument("--output", required=True)
    game.add_argument("--profile", choices=["gaming-cpu", "gpu"], required=True)
    game.add_argument("--scheduler", required=True)
    game.add_argument("--run", required=True, type=int)
    game.add_argument("--log", required=True)
    game.add_argument("--internal-log", required=True)
    game.add_argument("--benchmark-report", required=True)
    game.add_argument("--config", required=True)
    game.add_argument("--size", required=True)
    game.add_argument("--quality", choices=["low", "ultimate"], required=True)
    game.add_argument("--renderer", choices=["vulkan", "opengl"], required=True)
    game.add_argument("--gpu-prime", required=True)
    game.add_argument("--process-exit", required=True, type=int)
    game.add_argument("--background-workers", required=True, type=int)
    game.add_argument("--gamemode", required=True)
    game.add_argument("--active-ops", required=True)
    game.add_argument("--scheduler-args", required=True)
    game.add_argument("--raw-log", required=True)
    game.add_argument("--started-at", required=True)
    game.set_defaults(func=game_command)

    failure = subparsers.add_parser("failure")
    failure.add_argument("--output", required=True)
    failure.add_argument("--profile", required=True)
    failure.add_argument("--scheduler", required=True)
    failure.add_argument("--run", required=True, type=int)
    failure.add_argument("--active-ops", required=True)
    failure.add_argument("--scheduler-args", required=True)
    failure.add_argument("--raw-log", required=True)
    failure.add_argument("--started-at", required=True)
    failure.add_argument("--error", required=True)
    failure.set_defaults(func=failure_command)

    report = subparsers.add_parser("report")
    report.add_argument("--results-dir", required=True)
    report.add_argument("--metadata", required=True)
    report.add_argument("--output", required=True)
    report.add_argument("--csv", required=True)
    report.set_defaults(func=report_command)
    return parser


def main():
    parser = build_parser()
    args = parser.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
