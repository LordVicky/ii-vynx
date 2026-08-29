#!/usr/bin/env python3
"""Synchronized, non-mutating capture harness for K4 issue #22.

Captures:
- Quickshell k4barDebug IPC state (10 Hz)
- Hyprland cursor position (20 Hz)
- Hyprland layer geometry (5 Hz)
- [K4BottomHover] QML events emitted after capture start

The capture runs for a fixed duration. After starting it, move onto the bottom
collapsed pill, stop the pointer, and do not touch the mouse until capture ends.
"""

from __future__ import annotations

import argparse
import json
import re
import shutil
import subprocess
import sys
import tarfile
import threading
import time
from pathlib import Path
from typing import Any

DEFAULT_DURATION = 12.0
DEFAULT_STATE_INTERVAL = 0.10
DEFAULT_CURSOR_INTERVAL = 0.05
DEFAULT_LAYER_INTERVAL = 0.20
DEFAULT_CONFIG = "ii"
DEFAULT_LOG = "/tmp/ii-vynx-k4.log"
EVENT_PREFIX = "[K4BottomHover]"


def now_ms() -> int:
    return time.time_ns() // 1_000_000


def run(cmd: list[str], timeout: float = 0.9) -> str:
    try:
        proc = subprocess.run(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            timeout=timeout,
            check=False,
        )
        return proc.stdout.strip()
    except subprocess.TimeoutExpired:
        return "<timeout>"
    except OSError as exc:
        return f"<os-error:{exc}>"


def parse_json(text: str) -> Any:
    try:
        return json.loads(text)
    except Exception:
        return None


def compact(text: str) -> str:
    return " ".join(text.replace("\t", " ").splitlines())


def wait_for_ipc(config: str, seconds: float) -> tuple[bool, str]:
    deadline = time.monotonic() + seconds
    last = ""
    while time.monotonic() <= deadline:
        last = run(["qs", "-c", config, "ipc", "show"])
        if re.search(r"^target\s+k4barDebug\b", last, re.MULTILINE):
            return True, last
        time.sleep(0.25)
    return False, last


def sampler(stop: threading.Event, interval: float, fn, path: Path) -> None:
    next_tick = time.monotonic()
    with path.open("a", encoding="utf-8") as fh:
        while not stop.is_set():
            ts = now_ms()
            value = compact(fn())
            fh.write(f"{ts}\t{value}\n")
            fh.flush()
            next_tick += interval
            delay = next_tick - time.monotonic()
            if delay > 0:
                stop.wait(delay)
            else:
                next_tick = time.monotonic()


def read_tsv(path: Path) -> list[tuple[int, str]]:
    rows: list[tuple[int, str]] = []
    if not path.exists():
        return rows
    for line in path.read_text(errors="replace").splitlines():
        parts = line.split("\t", 1)
        if len(parts) != 2:
            continue
        try:
            rows.append((int(parts[0]), parts[1]))
        except ValueError:
            continue
    return rows


def cursor_xy(value: Any) -> tuple[float, float] | None:
    if isinstance(value, dict):
        x, y = value.get("x"), value.get("y")
        if isinstance(x, (int, float)) and isinstance(y, (int, float)):
            return float(x), float(y)
    if isinstance(value, list) and len(value) >= 2:
        x, y = value[:2]
        if isinstance(x, (int, float)) and isinstance(y, (int, float)):
            return float(x), float(y)
    return None


def find_k4_layers(value: Any) -> list[dict[str, Any]]:
    found: list[dict[str, Any]] = []
    if isinstance(value, dict):
        if value.get("namespace") == "quickshell:k4bar":
            found.append(value)
        for child in value.values():
            found.extend(find_k4_layers(child))
    elif isinstance(value, list):
        for child in value:
            found.extend(find_k4_layers(child))
    return found


def nearest(rows: list[tuple[int, Any]], ts: int) -> tuple[int, Any] | None:
    if not rows:
        return None
    return min(rows, key=lambda row: abs(row[0] - ts))


def parse_event(line: str) -> dict[str, Any] | None:
    match = re.search(r"\[K4BottomHover\]\s+(\d+)\s+(\S+)(.*)$", line)
    if not match:
        return None
    event: dict[str, Any] = {
        "ts": int(match.group(1)),
        "reason": match.group(2),
        "raw": line.strip(),
    }
    rest = match.group(3)
    pairs = re.findall(r"([A-Za-z][A-Za-z0-9_]*)=\s*([^\s]+)", rest)
    for key, raw in pairs:
        if raw in ("true", "false"):
            event[key] = raw == "true"
            continue
        try:
            event[key] = float(raw) if "." in raw else int(raw)
        except ValueError:
            event[key] = raw
    return event


def local_cursor_window(
    cursor_rows: list[tuple[int, Any]], ts: int, before: int = 350, after: int = 120
) -> tuple[str, str]:
    pts: list[tuple[float, float]] = []
    for sample_ts, value in cursor_rows:
        if ts - before <= sample_ts <= ts + after:
            pos = cursor_xy(value)
            if pos is not None:
                pts.append(pos)
    if len(pts) < 3:
        return "UNAVAILABLE", "<3 cursor samples"
    xs = [p[0] for p in pts]
    ys = [p[1] for p in pts]
    span_x, span_y = max(xs) - min(xs), max(ys) - min(ys)
    verdict = "STATIONARY" if span_x <= 2 and span_y <= 2 else "MOVING"
    return verdict, f"x-span={span_x:g}px y-span={span_y:g}px samples={len(pts)}"


def layer_at(rows: list[tuple[int, Any]], ts: int) -> tuple[int, dict[str, Any]] | None:
    row = nearest(rows, ts)
    if row is None:
        return None
    rts, obj = row
    matches = find_k4_layers(obj)
    if not matches:
        return None
    return rts, matches[0]


def bridge_contains_cursor(
    event: dict[str, Any], layer: dict[str, Any] | None, cursor: tuple[float, float] | None
) -> str:
    if layer is None or cursor is None:
        return "unknown"
    if any(not isinstance(event.get(key), (int, float)) for key in ("bridgeX", "bridgeW")):
        return "unknown"
    lx, ly, lw, lh = (layer.get("x"), layer.get("y"), layer.get("w"), layer.get("h"))
    if not all(isinstance(v, (int, float)) for v in (lx, ly, lw, lh)):
        return "unknown"
    x1 = float(lx) + float(event["bridgeX"])
    x2 = x1 + float(event["bridgeW"])
    y1 = float(ly) + float(lh) - 34.0
    y2 = float(ly) + float(lh)
    x, y = cursor
    return "yes" if x1 <= x <= x2 and y1 <= y <= y2 else "no"


def analyze(root: Path) -> str:
    meta_path = root / "meta.json"
    start_ms = end_ms = None
    if meta_path.exists():
        meta = parse_json(meta_path.read_text(errors="replace")) or {}
        start_ms, end_ms = meta.get("start_ms"), meta.get("end_ms")

    states_raw = read_tsv(root / "state.tsv")
    cursors_raw = read_tsv(root / "cursor.tsv")
    layers_raw = read_tsv(root / "layers.tsv")
    states = [(ts, parse_json(text)) for ts, text in states_raw]
    cursors = [(ts, parse_json(text)) for ts, text in cursors_raw]
    layers = [(ts, parse_json(text)) for ts, text in layers_raw]

    events: list[dict[str, Any]] = []
    event_path = root / "bottom-events.log"
    if event_path.exists():
        for line in event_path.read_text(errors="replace").splitlines():
            event = parse_event(line)
            if event is None:
                continue
            if start_ms is not None and event["ts"] < start_ms:
                continue
            if end_ms is not None and event["ts"] > end_ms:
                continue
            events.append(event)

    out: list[str] = [
        "K4 #22 bottom-hover diagnostic v2",
        "==================================",
        f"state_samples: {len(states)}",
        f"cursor_samples: {len(cursors)}",
        f"layer_samples: {len(layers)}",
        f"bottom_hover_events_in_window: {len(events)}",
    ]

    bridge_true = [e for e in events if e.get("bridge") is True]
    out.append(f"events_with_bridge_true: {len(bridge_true)}")

    addresses: list[str] = []
    for _, obj in layers:
        for layer in find_k4_layers(obj):
            addr = str(layer.get("address", ""))
            if addr and addr not in addresses:
                addresses.append(addr)
    out.append(f"k4_layer_addresses: {addresses}")

    transitions: list[tuple[int, Any, Any]] = []
    previous: Any = object()
    for ts, status in states:
        if not isinstance(status, dict):
            continue
        key = (status.get("occupant"), status.get("hovered"), status.get("activeScreen"))
        if key != previous:
            transitions.append((ts, key[0], key[1]))
            previous = key
    if transitions:
        out.append("\nIPC transitions:")
        for ts, occupant, hovered in transitions:
            out.append(f"  {ts}: occupant={occupant!r} hovered={hovered!r}")

    pointer_exits = [e for e in events if e["reason"] == "pointer-over" and e.get("pointerOver") is False]
    out.append(f"\npointer_over_false_events: {len(pointer_exits)}")
    for event in pointer_exits:
        ts = event["ts"]
        verdict, detail = local_cursor_window(cursors, ts)
        cursor_row = nearest(cursors, ts)
        cursor = cursor_xy(cursor_row[1]) if cursor_row else None
        layer_row = layer_at(layers, ts)
        layer = layer_row[1] if layer_row else None
        inside = bridge_contains_cursor(event, layer, cursor)
        out.append(f"\n  {ts} pointerOver=false")
        out.append(
            "    qml: island=%r bridge=%r stateHovered=%r passive=%r surfaceH=%r islandH=%r"
            % (
                event.get("island"), event.get("bridge"), event.get("stateHovered"),
                event.get("passive"), event.get("surfaceH"), event.get("islandH")
            )
        )
        out.append(f"    cursor-local: {verdict} ({detail}) nearest={cursor}")
        out.append(f"    cursor_inside_bridge_rect: {inside}")
        if layer_row:
            lts, layer_obj = layer_row
            out.append(
                "    layer(%+dms): address=%r x=%r y=%r w=%r h=%r"
                % (
                    lts - ts, layer_obj.get("address"), layer_obj.get("x"), layer_obj.get("y"),
                    layer_obj.get("w"), layer_obj.get("h")
                )
            )

    done_events = [e for e in events if e["reason"] == "island-height-animation-done"]
    if done_events:
        out.append("\nheight_animation_done_events:")
        for event in done_events:
            later_exits = [e for e in pointer_exits if 0 <= e["ts"] - event["ts"] <= 600]
            next_exit = later_exits[0] if later_exits else None
            out.append(
                f"  {event['ts']}: visible={event.get('visible')} islandH={event.get('islandH')} "
                f"next_pointer_exit_ms={(next_exit['ts'] - event['ts']) if next_exit else None}"
            )

    out.append("\nInterpretation gate:")
    stationary_exits = []
    for event in pointer_exits:
        verdict, _ = local_cursor_window(cursors, event["ts"])
        if verdict == "STATIONARY":
            stationary_exits.append(event)
    if stationary_exits:
        out.append("  VALID: at least one pointerOver=false transition occurred while the physical cursor was stationary.")
    else:
        out.append("  NOT YET VALID: no pointerOver=false transition is proven under a stationary physical cursor.")
        out.append("  Re-run and do not touch the mouse after placing it on the collapsed pill.")

    return "\n".join(out) + "\n"


def capture(args: argparse.Namespace) -> Path:
    for cmd in ("qs", "hyprctl"):
        if shutil.which(cmd) is None:
            raise SystemExit(f"Missing required command: {cmd}")

    ok, ipc_output = wait_for_ipc(args.config, args.wait)
    if not ok:
        print(f"k4barDebug did not register on config {args.config!r}.", file=sys.stderr)
        print(f"\n=== qs -c {args.config} ipc show ===\n{ipc_output}", file=sys.stderr)
        if Path(args.log).exists():
            tail = Path(args.log).read_text(errors="replace").splitlines()[-120:]
            print(f"\n=== tail {args.log} ===\n" + "\n".join(tail), file=sys.stderr)
        raise SystemExit(1)

    output = Path(args.output) if args.output else Path(
        f"/tmp/k4-bottom-hover-v2-{time.strftime('%Y%m%d-%H%M%S')}"
    )
    output.mkdir(parents=True, exist_ok=True)
    for name in ("state.tsv", "cursor.tsv", "layers.tsv", "quickshell-segment.log", "bottom-events.log"):
        (output / name).write_text("")

    print("\nK4 #22 v2 capture ready.")
    print("1. Keep the pointer away from K4.")
    print("2. Press Enter to begin the fixed capture window.")
    print("3. Move onto the collapsed bottom pill, then STOP moving the mouse.")
    print(f"4. Do not touch the mouse again for {args.duration:g} seconds, even after the double-spawn.")
    input("\nPress Enter to start capture... ")

    log_path = Path(args.log)
    log_start = log_path.stat().st_size if log_path.exists() else 0
    start_ms = now_ms()

    stop = threading.Event()
    threads = [
        threading.Thread(
            target=sampler,
            args=(stop, args.state_interval, lambda: run(["qs", "-c", args.config, "ipc", "call", "k4barDebug", "status"]), output / "state.tsv"),
            daemon=True,
        ),
        threading.Thread(
            target=sampler,
            args=(stop, args.cursor_interval, lambda: run(["hyprctl", "-j", "cursorpos"]), output / "cursor.tsv"),
            daemon=True,
        ),
        threading.Thread(
            target=sampler,
            args=(stop, args.layer_interval, lambda: run(["hyprctl", "-j", "layers"]), output / "layers.tsv"),
            daemon=True,
        ),
    ]
    for thread in threads:
        thread.start()

    print(f"Capturing for {args.duration:g}s — reproduce #22 now and leave the mouse stationary...")
    time.sleep(args.duration)
    stop.set()
    for thread in threads:
        thread.join(timeout=2)
    end_ms = now_ms()

    if log_path.exists():
        with log_path.open("rb") as fh:
            fh.seek(log_start)
            segment = fh.read().decode(errors="replace")
        (output / "quickshell-segment.log").write_text(segment)
        events = "\n".join(line for line in segment.splitlines() if EVENT_PREFIX in line)
        if events:
            events += "\n"
        (output / "bottom-events.log").write_text(events)

    meta = {
        "created": time.strftime("%Y-%m-%dT%H:%M:%S%z"),
        "start_ms": start_ms,
        "end_ms": end_ms,
        "duration": args.duration,
        "state_interval": args.state_interval,
        "cursor_interval": args.cursor_interval,
        "layer_interval": args.layer_interval,
        "config": args.config,
        "log": args.log,
        "git_head": run(["git", "rev-parse", "HEAD"]),
        "qs_version": run(["qs", "--version"]),
        "hyprland_version": run(["hyprctl", "version"]),
    }
    (output / "meta.json").write_text(json.dumps(meta, indent=2) + "\n")

    summary = analyze(output)
    (output / "summary.txt").write_text(summary)
    print("\n" + summary)

    archive = output.with_suffix(".tar.gz")
    with tarfile.open(archive, "w:gz") as tf:
        tf.add(output, arcname=output.name)
    print(f"Capture directory: {output}")
    print(f"Bundle: {archive}")
    return output


def main() -> int:
    parser = argparse.ArgumentParser(description="K4 #22 synchronized bottom-hover diagnostic v2")
    parser.add_argument("--config", default=DEFAULT_CONFIG)
    parser.add_argument("--wait", type=float, default=10.0)
    parser.add_argument("--duration", type=float, default=DEFAULT_DURATION)
    parser.add_argument("--state-interval", type=float, default=DEFAULT_STATE_INTERVAL)
    parser.add_argument("--cursor-interval", type=float, default=DEFAULT_CURSOR_INTERVAL)
    parser.add_argument("--layer-interval", type=float, default=DEFAULT_LAYER_INTERVAL)
    parser.add_argument("--log", default=DEFAULT_LOG)
    parser.add_argument("--output")
    parser.add_argument("--analyze-dir", type=Path, help="analyze an existing v2 capture directory instead of capturing")
    args = parser.parse_args()

    if args.analyze_dir:
        print(analyze(args.analyze_dir), end="")
        return 0
    capture(args)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
