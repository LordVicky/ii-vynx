#!/usr/bin/env python3
"""Record repeated K4 enter/leave attempts and classify every post-leave respawn.

Run for a fixed window. During that window repeat the real reproduction gesture:
  enter collapsed bottom pill -> let Clock/Player expand -> leave the bar.

The analyzer classifies each later passive activation as:
- FALSE/SYNTHETIC: cursor is outside K4 at activation;
- GEOMETRY-INDUCED: cursor is stationary while K4 moves under it;
- PHYSICAL RE-ENTRY: cursor is moving and is inside K4 at activation.

No K4 runtime state is modified.
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

PASSIVE = {"clock", "player"}
EVENT_PREFIX = "[K4BottomHover]"
BASE_HEIGHT = 34.0


def now_ms() -> int:
    return time.time_ns() // 1_000_000


def run(cmd: list[str], timeout: float = 0.9) -> str:
    try:
        p = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                           text=True, timeout=timeout, check=False)
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
    out = []
    if not path.exists():
        return out
    for line in path.read_text(errors="replace").splitlines():
        parts = line.split("\t", 1)
        if len(parts) != 2:
            continue
        try:
            out.append((int(parts[0]), parts[1]))
        except ValueError:
            pass
    return out


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
    out = []
    if isinstance(value, dict):
        if value.get("namespace") == "quickshell:k4bar":
            out.append(value)
        for child in value.values():
            out.extend(find_k4_layers(child))
    elif isinstance(value, list):
        for child in value:
            out.extend(find_k4_layers(child))
    return out


def nearest(rows: list[tuple[int, Any]], ts: int):
    return min(rows, key=lambda row: abs(row[0] - ts)) if rows else None


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


def layer_at(rows: list[tuple[int, Any]], ts: int):
    row = nearest(rows, ts)
    if row is None:
        return None
    rts, obj = row
    matches = find_k4_layers(obj)
    return (rts, matches[0]) if matches else None


def rects_for_event(event: dict[str, Any], layer: dict[str, Any] | None):
    if layer is None:
        return None, None
    vals = [layer.get(k) for k in ("x", "y", "w", "h")]
    if not all(isinstance(v, (int, float)) for v in vals):
        return None, None
    lx, ly, _, lh = map(float, vals)
    island = None
    if all(isinstance(event.get(k), (int, float)) for k in ("islandX", "islandW", "islandH")):
        ih = float(event["islandH"])
        island = (lx + float(event["islandX"]), ly + lh - ih,
                  float(event["islandW"]), ih)
    bridge = None
    if all(isinstance(event.get(k), (int, float)) for k in ("bridgeX", "bridgeW")):
        bridge = (lx + float(event["bridgeX"]), ly + lh - BASE_HEIGHT,
                  float(event["bridgeW"]), BASE_HEIGHT)
    return island, bridge


def point_in_rect(point, rect) -> bool | None:
    if point is None or rect is None:
        return None
    x, y = point
    rx, ry, rw, rh = rect
    return rx <= x <= rx + rw and ry <= y <= ry + rh


def point_in_union(point, a, b) -> bool | None:
    va, vb = point_in_rect(point, a), point_in_rect(point, b)
    if va is None and vb is None:
        return None
    return bool(va) or bool(vb)


def cursor_motion(rows: list[tuple[int, Any]], ts: int, before=300, after=150):
    pts = []
    for t, value in rows:
        if ts - before <= t <= ts + after:
            p = cursor_xy(value)
            if p is not None:
                pts.append(p)
    if len(pts) < 4:
        return "UNAVAILABLE", "<4 samples"
    xs = [p[0] for p in pts]; ys = [p[1] for p in pts]
    sx, sy = max(xs) - min(xs), max(ys) - min(ys)
    return ("STATIONARY" if sx <= 2 and sy <= 2 else "MOVING",
            f"x-span={sx:g}px y-span={sy:g}px samples={len(pts)}")


def transitions(states: list[tuple[int, Any]]):
    out = []
    prev = object()
    for ts, status in states:
        if not isinstance(status, dict):
            continue
        key = (status.get("occupant"), status.get("hovered"))
        if key != prev:
            out.append((ts, key[0], key[1]))
            prev = key
    return out


def geometry_for_respawn(events, layers, ts):
    candidates = [e for e in events if e["reason"] == "pointer-over"
                  and e.get("pointerOver") is True and abs(e["ts"] - ts) <= 250]
    if candidates:
        event = min(candidates, key=lambda e: abs(e["ts"] - ts))
    else:
        before = [e for e in events if e["ts"] <= ts]
        event = before[-1] if before else None
    lr = layer_at(layers, ts)
    layer = lr[1] if lr else None
    island = bridge = None
    if event:
        island, bridge = rects_for_event(event, layer)
    return event, island, bridge


def analyze(root: Path) -> str:
    states = [(t, parse_json(v)) for t, v in read_tsv(root / "state.tsv")]
    cursors = [(t, parse_json(v)) for t, v in read_tsv(root / "cursor.tsv")]
    layers = [(t, parse_json(v)) for t, v in read_tsv(root / "layers.tsv")]
    events = []
    for line in (root / "bottom-events.log").read_text(errors="replace").splitlines():
        e = parse_event(line)
        if e:
            events.append(e)
    trans = transitions(states)

    addresses = []
    for _, obj in layers:
        for layer in find_k4_layers(obj):
            a = str(layer.get("address", ""))
            if a and a not in addresses:
                addresses.append(a)

    out = [
        "K4 #22 repeated-attempt watcher v2",
        "===================================",
        f"state_samples: {len(states)}",
        f"cursor_samples: {len(cursors)}",
        f"layer_samples: {len(layers)}",
        f"events: {len(events)}",
        f"events_with_bridge_true: {sum(1 for e in events if e.get('bridge') is True)}",
        f"k4_layer_addresses: {addresses}",
        "",
        "IPC transitions:",
    ]
    for ts, occ, hov in trans:
        out.append(f"  {ts}: occupant={occ!r} hovered={hov!r}")

    cycles = []
    last_passive = None
    for ts, occ, hov in trans:
        if occ in PASSIVE and hov is True:
            if last_passive and last_passive.get("collapse"):
                cycle = {**last_passive, "respawn": (ts, occ, hov)}
                cycles.append(cycle)
            last_passive = {"passive": (ts, occ, hov), "collapse": None}
        elif occ == "idle" and hov is False and last_passive and last_passive.get("collapse") is None:
            last_passive["collapse"] = (ts, occ, hov)

    out.append("")
    out.append(f"passive_idle_passive_cycles: {len(cycles)}")
    valid = []
    physical = []
    for idx, cycle in enumerate(cycles, 1):
        p_ts, p_owner, _ = cycle["passive"]
        c_ts, _, _ = cycle["collapse"]
        r_ts, r_owner, _ = cycle["respawn"]
        cursor_row = nearest(cursors, r_ts)
        cursor = cursor_xy(cursor_row[1]) if cursor_row else None
        motion, detail = cursor_motion(cursors, r_ts)
        event, island, bridge = geometry_for_respawn(events, layers, r_ts)
        inside = point_in_union(cursor, island, bridge)
        if inside is False:
            kind = "FALSE/SYNTHETIC"
            valid.append(idx)
        elif inside is True and motion == "STATIONARY":
            kind = "GEOMETRY-INDUCED"
            valid.append(idx)
        elif inside is True and motion == "MOVING":
            kind = "PHYSICAL RE-ENTRY"
            physical.append(idx)
        else:
            kind = "INCONCLUSIVE"
        out += [
            f"\n  cycle {idx}: {p_owner}@{p_ts} -> idle@{c_ts} -> {r_owner}@{r_ts}",
            f"    classification: {kind}",
            f"    respawn_cursor: {cursor}",
            f"    cursor_motion: {motion} ({detail})",
            f"    cursor_inside_current_region: {inside}",
            f"    island_rect: {island}",
            f"    bridge_rect: {bridge}",
            f"    nearest_pointer_entry_event: {event['ts'] if event else None}",
        ]

    out += ["", "Interpretation gate:"]
    if valid:
        out.append(f"  VALID LEAVE-TRIGGER BUG captured in cycle(s): {valid}.")
        out.append("  A passive owner reactivated without a physical cursor re-entry; use that cycle for root-cause analysis.")
    elif physical:
        out.append(f"  ONLY PHYSICAL RE-ENTRIES captured in cycle(s): {physical}.")
        out.append("  No false respawn was proven in this window.")
    else:
        out.append("  NO CLASSIFIABLE RESPAWN captured. Repeat the gesture during another watch window.")
    return "\n".join(out) + "\n"


def main() -> None:
    p = argparse.ArgumentParser()
    p.add_argument("--config", default="ii")
    p.add_argument("--log", default="/tmp/ii-vynx-k4.log")
    p.add_argument("--wait", type=float, default=10.0)
    p.add_argument("--seconds", type=float, default=45.0)
    p.add_argument("--output")
    args = p.parse_args()

    for cmd in ("qs", "hyprctl"):
        if shutil.which(cmd) is None:
            raise SystemExit(f"Missing required command: {cmd}")
    ok, ipc = wait_for_ipc(args.config, args.wait)
    if not ok:
        print(f"k4barDebug did not register on {args.config!r}.\n{ipc}", file=sys.stderr)
        raise SystemExit(1)

    root = Path(args.output) if args.output else Path("/tmp") / f"k4-bottom-hover-watch-{time.strftime('%Y%m%d-%H%M%S')}"
    root.mkdir(parents=True, exist_ok=True)
    for name in ("state.tsv", "cursor.tsv", "layers.tsv", "quickshell-segment.log", "bottom-events.log"):
        (root / name).write_text("")

    log_path = Path(args.log)
    log_start = log_path.stat().st_size if log_path.exists() else 0
    start_ms = now_ms()
    stop = threading.Event()

    def state_cmd(): return run(["qs", "-c", args.config, "ipc", "call", "k4barDebug", "status"])
    def cursor_cmd(): return run(["hyprctl", "-j", "cursorpos"])
    def layer_cmd(): return run(["hyprctl", "-j", "layers"])

    threads = [
        threading.Thread(target=sampler, args=(stop, 0.10, state_cmd, root / "state.tsv"), daemon=True),
        threading.Thread(target=sampler, args=(stop, 0.05, cursor_cmd, root / "cursor.tsv"), daemon=True),
        threading.Thread(target=sampler, args=(stop, 0.20, layer_cmd, root / "layers.tsv"), daemon=True),
    ]
    for t in threads: t.start()

    print(f"Watcher recording for {args.seconds:.0f}s.")
    print("Repeat the REAL enter -> expand -> leave gesture as many times as needed during this window.")
    print("After each leave, briefly stop moving the mouse so a spontaneous reactivation is distinguishable from a real re-entry.")
    time.sleep(args.seconds)

    stop.set()
    for t in threads: t.join(timeout=1.0)
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
        "start_ms": start_ms, "end_ms": end_ms, "seconds": args.seconds,
        "git_head": run(["git", "rev-parse", "HEAD"]),
        "config": args.config, "log": args.log,
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


if __name__ == "__main__":
    main()
