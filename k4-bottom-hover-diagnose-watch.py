#!/usr/bin/env python3
"""Watch repeated K4 enter/leave attempts and stop on the real #22 respawn.

The user may repeat the normal reproduction gesture during the watch window:
  enter collapsed bottom pill -> let passive Clock/Player expand -> leave.

The harness does not treat pointer movement as an error. It stops only after it
observes a complete passive -> idle -> passive state cycle, then checks whether
the physical cursor had actually re-entered the intended K4 hit region.
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


def sampler(stop: threading.Event, interval: float, fn, path: Path, update=None) -> None:
    next_tick = time.monotonic()
    with path.open("a", encoding="utf-8") as fh:
        while not stop.is_set():
            ts = now_ms()
            text = compact(fn())
            fh.write(f"{ts}\t{text}\n")
            fh.flush()
            if update is not None:
                update(ts, text)
            next_tick += interval
            delay = next_tick - time.monotonic()
            if delay > 0:
                stop.wait(delay)
            else:
                next_tick = time.monotonic()


def read_tsv(path: Path) -> list[tuple[int, str]]:
    out: list[tuple[int, str]] = []
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


class Detector:
    def __init__(self) -> None:
        self.lock = threading.Lock()
        self.phase = "waiting-passive"
        self.attempt = 0
        self.passive_ms: int | None = None
        self.collapse_ms: int | None = None
        self.respawn_ms: int | None = None
        self.respawn_owner: str | None = None
        self.detected = threading.Event()
        self.last_key = None

    def update(self, ts: int, text: str) -> None:
        status = parse_json(text)
        if not isinstance(status, dict):
            return
        key = (status.get("occupant"), status.get("hovered"))
        with self.lock:
            if key == self.last_key:
                return
            self.last_key = key
            occ, hovered = key
            if self.phase == "waiting-passive":
                if occ in PASSIVE and hovered is True:
                    self.attempt += 1
                    self.passive_ms = ts
                    self.collapse_ms = None
                    self.phase = "waiting-collapse"
                    print(f"Attempt {self.attempt}: passive owner {occ!r} active. Leave the bar normally.", flush=True)
            elif self.phase == "waiting-collapse":
                if occ == "idle" and hovered is False:
                    self.collapse_ms = ts
                    self.phase = "waiting-respawn"
                    print(f"Attempt {self.attempt}: collapsed to idle. Watching for false respawn...", flush=True)
            elif self.phase == "waiting-respawn":
                if occ in PASSIVE and hovered is True:
                    self.respawn_ms = ts
                    self.respawn_owner = str(occ)
                    self.detected.set()
                    print(f"Attempt {self.attempt}: passive respawn detected ({occ}). Capturing post-roll...", flush=True)


def analyze(root: Path) -> str:
    meta = parse_json((root / "meta.json").read_text(errors="replace")) or {}
    states = [(t, parse_json(v)) for t, v in read_tsv(root / "state.tsv")]
    cursors = [(t, parse_json(v)) for t, v in read_tsv(root / "cursor.tsv")]
    layers = [(t, parse_json(v)) for t, v in read_tsv(root / "layers.tsv")]
    events = []
    for line in (root / "bottom-events.log").read_text(errors="replace").splitlines():
        e = parse_event(line)
        if e:
            events.append(e)

    passive_ms = meta.get("passive_ms")
    collapse_ms = meta.get("collapse_ms")
    respawn_ms = meta.get("respawn_ms")
    out = [
        "K4 #22 repeated-attempt watcher",
        "================================",
        f"attempts_seen: {meta.get('attempts_seen')}",
        f"detected: {bool(respawn_ms)}",
        f"passive_ms: {passive_ms}",
        f"collapse_ms: {collapse_ms}",
        f"respawn_ms: {respawn_ms}",
        f"respawn_owner: {meta.get('respawn_owner')}",
        f"state_samples: {len(states)}",
        f"cursor_samples: {len(cursors)}",
        f"layer_samples: {len(layers)}",
        f"events: {len(events)}",
        f"events_with_bridge_true: {sum(1 for e in events if e.get('bridge') is True)}",
    ]
    addresses = []
    for _, obj in layers:
        for layer in find_k4_layers(obj):
            a = str(layer.get("address", ""))
            if a and a not in addresses:
                addresses.append(a)
    out.append(f"k4_layer_addresses: {addresses}")

    if not respawn_ms:
        out += ["", "Interpretation gate:",
                "  NOT CAPTURED: no complete passive -> idle -> passive cycle occurred.",
                "  Re-run and repeat the normal enter/leave gesture until the watcher stops itself."]
        return "\n".join(out) + "\n"

    respawn_ms = int(respawn_ms)
    c = nearest(cursors, respawn_ms)
    cursor = cursor_xy(c[1]) if c else None
    lr = layer_at(layers, respawn_ms)
    layer = lr[1] if lr else None
    geom_events = [e for e in events if e["ts"] <= respawn_ms]
    geom = geom_events[-1] if geom_events else None
    island = bridge = None
    if geom:
        island, bridge = rects_for_event(geom, layer)
    inside = point_in_union(cursor, island, bridge)

    pointer_entries = [e for e in events if collapse_ms and e["ts"] >= int(collapse_ms)
                       and e["reason"] == "pointer-over" and e.get("pointerOver") is True]
    out += ["", f"respawn_cursor: {cursor}",
            f"respawn_island_rect: {island}", f"respawn_bridge_rect: {bridge}",
            f"cursor_inside_intended_region: {inside}",
            f"post_collapse_pointer_over_true_events: {len(pointer_entries)}"]
    for e in pointer_entries[-5:]:
        cc = nearest(cursors, e["ts"])
        out.append(f"  {e['ts']}: cursor={cursor_xy(cc[1]) if cc else None} qml={e['raw']}")

    out += ["", "Interpretation gate:"]
    if inside is False:
        out.append("  VALID LEAVE-TRIGGER BUG: passive owner respawned while the physical cursor was outside K4's intended hit region.")
    elif inside is True:
        out.append("  PHYSICAL RE-ENTRY: respawn coincided with the cursor being back inside K4; not proof of a false re-entry.")
    else:
        out.append("  RESPAWN CAPTURED, GEOMETRY INCONCLUSIVE: inspect the raw bundle manually.")
    return "\n".join(out) + "\n"


def main() -> None:
    p = argparse.ArgumentParser()
    p.add_argument("--config", default="ii")
    p.add_argument("--log", default="/tmp/ii-vynx-k4.log")
    p.add_argument("--wait", type=float, default=10.0)
    p.add_argument("--max-seconds", type=float, default=45.0)
    p.add_argument("--post-roll", type=float, default=1.5)
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
    detector = Detector()

    def state_cmd(): return run(["qs", "-c", args.config, "ipc", "call", "k4barDebug", "status"])
    def cursor_cmd(): return run(["hyprctl", "-j", "cursorpos"])
    def layer_cmd(): return run(["hyprctl", "-j", "layers"])

    threads = [
        threading.Thread(target=sampler, args=(stop, 0.10, state_cmd, root / "state.tsv", detector.update), daemon=True),
        threading.Thread(target=sampler, args=(stop, 0.05, cursor_cmd, root / "cursor.tsv"), daemon=True),
        threading.Thread(target=sampler, args=(stop, 0.20, layer_cmd, root / "layers.tsv"), daemon=True),
    ]
    for t in threads: t.start()

    print("Watcher started. Reproduce #22 normally; you may repeat the enter/leave gesture several times.")
    print("Do not stop the script manually if an attempt fails; it stops itself when passive -> idle -> passive is seen.")
    deadline = time.monotonic() + args.max_seconds
    while time.monotonic() < deadline and not detector.detected.is_set():
        time.sleep(0.05)
    if detector.detected.is_set():
        time.sleep(args.post_roll)

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

    with detector.lock:
        meta = {
            "created": time.strftime("%Y-%m-%dT%H:%M:%S%z"),
            "start_ms": start_ms, "end_ms": end_ms,
            "attempts_seen": detector.attempt,
            "passive_ms": detector.passive_ms,
            "collapse_ms": detector.collapse_ms,
            "respawn_ms": detector.respawn_ms,
            "respawn_owner": detector.respawn_owner,
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
