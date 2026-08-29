#!/usr/bin/env python3
"""Leave-triggered synchronized capture for K4 issue #22.

Reproduction model:
1. move onto the collapsed bottom K4 pill;
2. let the passive Clock/Player expand;
3. move back out using the same motion that normally triggers the double-spawn;
4. after leaving, stop moving and let the harness record.

A valid bug is a passive reactivation after the deliberate leave while the
physical cursor is still outside the intended island/bridge screen-space hit
region. No K4 runtime state is modified by this script.
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

EVENT_PREFIX = "[K4BottomHover]"
PASSIVE = {"clock", "player"}
BASE_HEIGHT = 34.0


def now_ms() -> int:
    return time.time_ns() // 1_000_000


def run(cmd: list[str], timeout: float = 0.9) -> str:
    try:
        p = subprocess.run(
            cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
            text=True, timeout=timeout, check=False
        )
        return p.stdout.strip()
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
            fh.write(f"{ts}\t{compact(fn())}\n")
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
    out: list[dict[str, Any]] = []
    if isinstance(value, dict):
        if value.get("namespace") == "quickshell:k4bar":
            out.append(value)
        for child in value.values():
            out.extend(find_k4_layers(child))
    elif isinstance(value, list):
        for child in value:
            out.extend(find_k4_layers(child))
    return out


def nearest(rows: list[tuple[int, Any]], ts: int) -> tuple[int, Any] | None:
    return min(rows, key=lambda r: abs(r[0] - ts)) if rows else None


def parse_event(line: str) -> dict[str, Any] | None:
    m = re.search(r"\[K4BottomHover\]\s+(\d+)\s+(\S+)(.*)$", line)
    if not m:
        return None
    e: dict[str, Any] = {"ts": int(m.group(1)), "reason": m.group(2), "raw": line.strip()}
    for key, raw in re.findall(r"([A-Za-z][A-Za-z0-9_]*)=\s*([^\s]+)", m.group(3)):
        if raw in ("true", "false"):
            e[key] = raw == "true"
        else:
            try:
                e[key] = float(raw) if "." in raw else int(raw)
            except ValueError:
                e[key] = raw
    return e


def local_cursor_motion(rows: list[tuple[int, Any]], ts: int, before=250, after=100):
    pts: list[tuple[float, float]] = []
    for t, value in rows:
        if ts - before <= t <= ts + after:
            p = cursor_xy(value)
            if p is not None:
                pts.append(p)
    if len(pts) < 3:
        return "UNAVAILABLE", "<3 samples"
    xs = [p[0] for p in pts]
    ys = [p[1] for p in pts]
    sx, sy = max(xs) - min(xs), max(ys) - min(ys)
    return ("STATIONARY" if sx <= 2 and sy <= 2 else "MOVING",
            f"x-span={sx:g}px y-span={sy:g}px samples={len(pts)}")


def layer_at(rows: list[tuple[int, Any]], ts: int) -> tuple[int, dict[str, Any]] | None:
    row = nearest(rows, ts)
    if row is None:
        return None
    rts, obj = row
    matches = find_k4_layers(obj)
    if not matches:
        return None
    return rts, matches[0]


def rects_for_event(event: dict[str, Any], layer: dict[str, Any] | None):
    if layer is None:
        return None, None
    vals = [layer.get(k) for k in ("x", "y", "w", "h")]
    if not all(isinstance(v, (int, float)) for v in vals):
        return None, None
    lx, ly, _, lh = map(float, vals)

    island = None
    if all(isinstance(event.get(k), (int, float))
           for k in ("islandX", "islandW", "islandH")):
        ih = float(event["islandH"])
        island = (
            lx + float(event["islandX"]),
            ly + lh - ih,
            float(event["islandW"]),
            ih,
        )

    bridge = None
    if all(isinstance(event.get(k), (int, float))
           for k in ("bridgeX", "bridgeW")):
        bridge = (
            lx + float(event["bridgeX"]),
            ly + lh - BASE_HEIGHT,
            float(event["bridgeW"]),
            BASE_HEIGHT,
        )
    return island, bridge


def point_in_rect(point: tuple[float, float] | None, rect) -> bool | None:
    if point is None or rect is None:
        return None
    x, y = point
    rx, ry, rw, rh = rect
    return rx <= x <= rx + rw and ry <= y <= ry + rh


def point_in_union(point, island, bridge):
    a = point_in_rect(point, island)
    b = point_in_rect(point, bridge)
    if a is None and b is None:
        return None
    return bool(a) or bool(b)


def status_transitions(states: list[tuple[int, Any]], start_ms: int, end_ms: int):
    out = []
    prev = None
    for ts, status in states:
        if ts < start_ms or ts > end_ms or not isinstance(status, dict):
            continue
        key = (status.get("occupant"), status.get("hovered"))
        if key != prev:
            out.append((ts, key[0], key[1]))
            prev = key
    return out


def analyze(root: Path) -> str:
    meta = parse_json((root / "meta.json").read_text(errors="replace")) or {}
    start_ms = int(meta.get("start_ms", 0))
    end_ms = int(meta.get("end_ms", 2**63 - 1))

    states = [(t, parse_json(v)) for t, v in read_tsv(root / "state.tsv")]
    cursors = [(t, parse_json(v)) for t, v in read_tsv(root / "cursor.tsv")]
    layers = [(t, parse_json(v)) for t, v in read_tsv(root / "layers.tsv")]

    events = []
    for line in (root / "bottom-events.log").read_text(errors="replace").splitlines():
        e = parse_event(line)
        if e and start_ms <= e["ts"] <= end_ms:
            events.append(e)

    transitions = status_transitions(states, start_ms, end_ms)

    addresses = []
    for _, obj in layers:
        for layer in find_k4_layers(obj):
            addr = str(layer.get("address", ""))
            if addr and addr not in addresses:
                addresses.append(addr)

    out = [
        "K4 #22 leave-trigger diagnostic",
        "===============================",
        f"state_samples: {len(states)}",
        f"cursor_samples: {len(cursors)}",
        f"layer_samples: {len(layers)}",
        f"events: {len(events)}",
        f"k4_layer_addresses: {addresses}",
        f"events_with_bridge_true: {sum(1 for e in events if e.get('bridge') is True)}",
        "",
        "IPC transitions:",
    ]
    for ts, occ, hovered in transitions:
        motion, detail = local_cursor_motion(cursors, ts)
        out.append(f"  {ts}: occupant={occ!r} hovered={hovered!r} cursor={motion} ({detail})")

    leaves = [
        e for e in events
        if e["reason"] == "pointer-over" and e.get("pointerOver") is False
    ]
    expected_leave = None
    for e in leaves:
        motion, _ = local_cursor_motion(cursors, e["ts"])
        if motion == "MOVING":
            expected_leave = e
            break

    out.append("")
    if expected_leave:
        leave_ts = expected_leave["ts"]
        out.append(f"deliberate_leave_ms: {leave_ts}")
        c = nearest(cursors, leave_ts)
        out.append(f"  nearest_cursor={cursor_xy(c[1]) if c else None}")
    else:
        out.append("deliberate_leave_ms: NOT FOUND")
        leave_ts = None

    collapse = respawn = None
    if leave_ts is not None:
        for ts, occ, hovered in transitions:
            if ts < leave_ts:
                continue
            if collapse is None and occ == "idle" and hovered is False:
                collapse = (ts, occ, hovered)
                continue
            if collapse is not None and ts > collapse[0] and occ in PASSIVE and hovered is True:
                respawn = (ts, occ, hovered)
                break

    out.append(f"post_leave_collapse: {collapse}")
    out.append(f"post_leave_respawn: {respawn}")

    suspicious_entries = []
    if collapse is not None:
        for e in events:
            if e["ts"] <= collapse[0]:
                continue
            if e["reason"] != "pointer-over" or e.get("pointerOver") is not True:
                continue
            c = nearest(cursors, e["ts"])
            point = cursor_xy(c[1]) if c else None
            lr = layer_at(layers, e["ts"])
            layer = lr[1] if lr else None
            island, bridge = rects_for_event(e, layer)
            inside = point_in_union(point, island, bridge)
            motion, detail = local_cursor_motion(cursors, e["ts"])
            suspicious_entries.append((e, point, inside, motion, detail, island, bridge))

    out.append(f"post_collapse_pointer_entries: {len(suspicious_entries)}")
    for e, point, inside, motion, detail, island, bridge in suspicious_entries:
        out.append(
            f"  {e['ts']}: cursor={point} inside_intended_region={inside} "
            f"motion={motion} ({detail}) island={island} bridge={bridge}"
        )

    valid = False
    reason = ""
    if respawn is not None:
        geom_events = [e for e in events if e["ts"] <= respawn[0]]
        geom = geom_events[-1] if geom_events else None
        c = nearest(cursors, respawn[0])
        point = cursor_xy(c[1]) if c else None
        lr = layer_at(layers, respawn[0])
        layer = lr[1] if lr else None
        island = bridge = None
        if geom:
            island, bridge = rects_for_event(geom, layer)
        inside = point_in_union(point, island, bridge)
        motion, detail = local_cursor_motion(cursors, respawn[0])
        out.append("")
        out.append(
            f"respawn_geometry: cursor={point} inside_intended_region={inside} "
            f"motion={motion} ({detail}) island={island} bridge={bridge}"
        )
        if inside is False:
            valid = True
            reason = "passive owner respawned while the physical cursor was outside the intended K4 hover region"
        else:
            reason = "respawn occurred, but cursor was not proven outside the intended K4 hover region"
    elif any(inside is False for _, _, inside, *_ in suspicious_entries):
        valid = True
        reason = "pointerOver re-entered after collapse while physical cursor was outside the intended K4 hover region"
    else:
        reason = "no post-leave false re-entry/respawn was captured"

    out.append("")
    out.append("Interpretation gate:")
    if valid:
        out.append(f"  VALID LEAVE-TRIGGER BUG: {reason}.")
    else:
        out.append(f"  NOT YET VALID: {reason}.")
        out.append("  Re-run using the exact enter-then-leave motion that normally produces the double-spawn.")

    return "\n".join(out) + "\n"


def capture(args) -> Path:
    for cmd in ("qs", "hyprctl"):
        if shutil.which(cmd) is None:
            raise SystemExit(f"Missing required command: {cmd}")

    ok, ipc = wait_for_ipc(args.config, args.wait)
    if not ok:
        print(f"k4barDebug did not register on config {args.config!r}.", file=sys.stderr)
        print(ipc, file=sys.stderr)
        if Path(args.log).exists():
            print("\n=== log tail ===", file=sys.stderr)
            print("\n".join(Path(args.log).read_text(errors="replace").splitlines()[-120:]),
                  file=sys.stderr)
        raise SystemExit(1)

    root = (Path(args.output) if args.output else
            Path("/tmp") / f"k4-bottom-hover-leave-{time.strftime('%Y%m%d-%H%M%S')}")
    root.mkdir(parents=True, exist_ok=True)
    for name in ("state.tsv", "cursor.tsv", "layers.tsv",
                 "bottom-events.log", "quickshell-segment.log"):
        (root / name).write_text("")

    log_path = Path(args.log)
    log_start = log_path.stat().st_size if log_path.exists() else 0
    start_ms = now_ms()
    stop = threading.Event()

    state_cmd = lambda: run(["qs", "-c", args.config, "ipc", "call", "k4barDebug", "status"])
    cursor_cmd = lambda: run(["hyprctl", "-j", "cursorpos"])
    layer_cmd = lambda: run(["hyprctl", "-j", "layers"])

    threads = [
        threading.Thread(target=sampler, args=(stop, args.state_interval, state_cmd, root / "state.tsv"), daemon=True),
        threading.Thread(target=sampler, args=(stop, args.cursor_interval, cursor_cmd, root / "cursor.tsv"), daemon=True),
        threading.Thread(target=sampler, args=(stop, args.layer_interval, layer_cmd, root / "layers.tsv"), daemon=True),
    ]
    for t in threads:
        t.start()

    print("K4 #22 leave-trigger capture started.")
    print("Use the exact motion that reproduces the bug:")
    print("  1. move onto the collapsed bottom pill;")
    print("  2. let Clock/Player expand;")
    print("  3. move back out exactly as you normally do;")
    print("  4. after leaving, stop moving the mouse.")
    print(f"Recording for {args.duration:.1f}s; no keyboard input is needed.")

    time.sleep(args.duration)

    stop.set()
    for t in threads:
        t.join(timeout=1)
    end_ms = now_ms()

    if log_path.exists():
        with log_path.open("rb") as fh:
            fh.seek(log_start)
            seg = fh.read().decode(errors="replace")
        (root / "quickshell-segment.log").write_text(seg)
        lines = [line for line in seg.splitlines() if EVENT_PREFIX in line]
        (root / "bottom-events.log").write_text("\n".join(lines) + ("\n" if lines else ""))

    meta = {
        "created": time.strftime("%Y-%m-%dT%H:%M:%S%z"),
        "start_ms": start_ms,
        "end_ms": end_ms,
        "duration": args.duration,
        "config": args.config,
        "log": args.log,
        "git_head": run(["git", "rev-parse", "HEAD"]),
        "qs_version": run(["qs", "--version"]),
        "hyprland_version": run(["hyprctl", "version"]),
    }
    (root / "meta.json").write_text(json.dumps(meta, indent=2) + "\n")
    summary = analyze(root)
    (root / "summary.txt").write_text(summary)
    print("\n" + summary)

    archive = Path(str(root) + ".tar.gz")
    with tarfile.open(archive, "w:gz") as tf:
        tf.add(root, arcname=root.name)
    print(f"Capture directory: {root}")
    print(f"Bundle: {archive}")
    return root


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--config", default="ii")
    p.add_argument("--log", default="/tmp/ii-vynx-k4.log")
    p.add_argument("--wait", type=float, default=10.0)
    p.add_argument("--duration", type=float, default=10.0)
    p.add_argument("--state-interval", type=float, default=0.10)
    p.add_argument("--cursor-interval", type=float, default=0.05)
    p.add_argument("--layer-interval", type=float, default=0.20)
    p.add_argument("--output")
    p.add_argument("--analyze", metavar="DIR",
                   help="analyze an existing extracted capture directory")
    args = p.parse_args()

    if args.analyze:
        print(analyze(Path(args.analyze)), end="")
        return
    capture(args)


if __name__ == "__main__":
    main()
