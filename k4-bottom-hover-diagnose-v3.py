#!/usr/bin/env python3
"""Auto-armed synchronized capture for K4 issue #22.

Run this while K4 is deployed with the [K4BottomHover] QML probe.
Then move the pointer onto the collapsed bottom pill and stop moving it.
The script automatically arms on the first IslandState.hovered=true sample,
keeps pre-roll evidence, and stops a few seconds later. No keyboard input is
needed after launch.
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


class Shared:
    def __init__(self) -> None:
        self.lock = threading.Lock()
        self.latest_status: dict[str, Any] | None = None
        self.first_hover_ms: int | None = None


def sampler(stop: threading.Event, interval: float, fn, path: Path, update=None) -> None:
    next_tick = time.monotonic()
    with path.open("a", encoding="utf-8") as fh:
        while not stop.is_set():
            ts = now_ms()
            text = compact(fn())
            fh.write(f"{ts}\t{text}\n")
            fh.flush()
            if update:
                update(ts, text)
            next_tick += interval
            delay = next_tick - time.monotonic()
            if delay > 0:
                stop.wait(delay)
            else:
                next_tick = time.monotonic()


def read_tsv(path: Path) -> list[tuple[int, str]]:
    rows=[]
    if not path.exists():
        return rows
    for line in path.read_text(errors="replace").splitlines():
        parts=line.split("\t",1)
        if len(parts)!=2:
            continue
        try:
            rows.append((int(parts[0]), parts[1]))
        except ValueError:
            pass
    return rows


def cursor_xy(value: Any) -> tuple[float,float] | None:
    if isinstance(value, dict):
        x,y=value.get("x"),value.get("y")
        if isinstance(x,(int,float)) and isinstance(y,(int,float)):
            return float(x),float(y)
    if isinstance(value,list) and len(value)>=2:
        x,y=value[:2]
        if isinstance(x,(int,float)) and isinstance(y,(int,float)):
            return float(x),float(y)
    return None


def find_k4_layers(value: Any) -> list[dict[str,Any]]:
    out=[]
    if isinstance(value,dict):
        if value.get("namespace")=="quickshell:k4bar":
            out.append(value)
        for child in value.values():
            out.extend(find_k4_layers(child))
    elif isinstance(value,list):
        for child in value:
            out.extend(find_k4_layers(child))
    return out


def nearest(rows: list[tuple[int,Any]], ts: int):
    return min(rows,key=lambda r:abs(r[0]-ts)) if rows else None


def parse_event(line: str):
    m=re.search(r"\[K4BottomHover\]\s+(\d+)\s+(\S+)(.*)$",line)
    if not m:
        return None
    e={"ts":int(m.group(1)),"reason":m.group(2),"raw":line.strip()}
    for key,raw in re.findall(r"([A-Za-z][A-Za-z0-9_]*)=\s*([^\s]+)",m.group(3)):
        if raw in ("true","false"):
            e[key]=(raw=="true")
        else:
            try:
                e[key]=float(raw) if "." in raw else int(raw)
            except ValueError:
                e[key]=raw
    return e


def local_cursor_verdict(rows: list[tuple[int,Any]], ts: int, before=300, after=150):
    pts=[]
    for t,v in rows:
        if ts-before <= t <= ts+after:
            p=cursor_xy(v)
            if p:
                pts.append(p)
    if len(pts)<4:
        return "UNAVAILABLE","<4 samples"
    xs=[p[0] for p in pts]; ys=[p[1] for p in pts]
    sx=max(xs)-min(xs); sy=max(ys)-min(ys)
    verdict="STATIONARY" if sx<=2 and sy<=2 else "MOVING"
    return verdict,f"x-span={sx:g}px y-span={sy:g}px samples={len(pts)}"


def analyze(root: Path) -> str:
    meta=parse_json((root/"meta.json").read_text(errors="replace")) or {}
    arm_ms=meta.get("first_hover_ms")
    end_ms=meta.get("end_ms")
    pre_roll=int(meta.get("pre_roll_ms",1000))
    window_start=(arm_ms-pre_roll) if isinstance(arm_ms,int) else meta.get("start_ms",0)

    states=[(t,parse_json(v)) for t,v in read_tsv(root/"state.tsv")]
    cursors=[(t,parse_json(v)) for t,v in read_tsv(root/"cursor.tsv")]
    layers=[(t,parse_json(v)) for t,v in read_tsv(root/"layers.tsv")]

    events=[]
    for line in (root/"bottom-events.log").read_text(errors="replace").splitlines():
        e=parse_event(line)
        if not e:
            continue
        if window_start <= e["ts"] <= end_ms:
            events.append(e)

    out=[
        "K4 #22 auto-armed diagnostic",
        "============================",
        f"first_hover_ms: {arm_ms}",
        f"window_start_ms: {window_start}",
        f"end_ms: {end_ms}",
        f"state_samples: {len(states)}",
        f"cursor_samples: {len(cursors)}",
        f"layer_samples: {len(layers)}",
        f"events_in_window: {len(events)}",
        f"events_with_bridge_true: {sum(1 for e in events if e.get('bridge') is True)}",
    ]

    addresses=[]
    for _,obj in layers:
        for layer in find_k4_layers(obj):
            a=str(layer.get("address",""))
            if a and a not in addresses:
                addresses.append(a)
    out.append(f"k4_layer_addresses: {addresses}")

    transitions=[]
    prev=None
    for ts,s in states:
        if not isinstance(s,dict) or ts < window_start or ts > end_ms:
            continue
        key=(s.get("occupant"),s.get("hovered"))
        if key!=prev:
            transitions.append((ts,*key))
            prev=key
    out.append("\nIPC transitions:")
    for ts,occ,hov in transitions:
        verdict,detail=local_cursor_verdict(cursors,ts)
        out.append(f"  {ts}: occupant={occ!r} hovered={hov!r} cursor={verdict} ({detail})")

    pointer_false=[e for e in events if e["reason"]=="pointer-over" and e.get("pointerOver") is False]
    out.append(f"\npointer_over_false_events: {len(pointer_false)}")
    stationary_false=[]
    for e in pointer_false:
        verdict,detail=local_cursor_verdict(cursors,e["ts"])
        if verdict=="STATIONARY":
            stationary_false.append(e)
        c=nearest(cursors,e["ts"])
        out.append(
            f"  {e['ts']}: {verdict} ({detail}) "
            f"island={e.get('island')} bridge={e.get('bridge')} "
            f"stateHovered={e.get('stateHovered')} nearest_cursor={cursor_xy(c[1]) if c else None}"
        )

    passive={"clock","player"}
    seq=[(ts,occ,hov) for ts,occ,hov in transitions]
    respawns=[]
    for i in range(len(seq)-2):
        a,b,c=seq[i:i+3]
        if a[1] in passive and b[1]=="idle" and c[1] in passive:
            verdict_b,detail_b=local_cursor_verdict(cursors,b[0])
            verdict_c,detail_c=local_cursor_verdict(cursors,c[0])
            respawns.append((a,b,c,verdict_b,detail_b,verdict_c,detail_c))
    out.append(f"\npassive_respawn_sequences: {len(respawns)}")
    valid_respawn=False
    for a,b,c,vb,db,vc,dc in respawns:
        out.append(
            f"  {a[0]} {a[1]} -> {b[0]} idle -> {c[0]} {c[1]} | "
            f"collapse_cursor={vb} ({db}); respawn_cursor={vc} ({dc})"
        )
        if vb=="STATIONARY" and vc=="STATIONARY":
            valid_respawn=True

    bridge_false_stationary=0
    for e in events:
        if e.get("bridge") is not False:
            continue
        verdict,_=local_cursor_verdict(cursors,e["ts"])
        if verdict=="STATIONARY":
            bridge_false_stationary+=1
    out.append(f"\nstationary_events_with_bridge_false: {bridge_false_stationary}")

    out.append("\nInterpretation gate:")
    if valid_respawn:
        out.append("  VALID DOUBLE-SPAWN: passive owner collapsed and respawned while the physical cursor was stationary.")
    elif stationary_false:
        out.append("  VALID HOVER-LOSS: pointerOver=false occurred while the physical cursor was stationary, but no full respawn sequence was sampled.")
    else:
        out.append("  NOT VALID YET: no hover-loss/respawn transition was proven under a stationary physical cursor.")
    if not valid_respawn:
        out.append("  Leave the mouse completely untouched after it first reaches the collapsed pill; the script stops by itself.")

    return "\n".join(out)+"\n"


def capture(args):
    for cmd in ("qs","hyprctl"):
        if shutil.which(cmd) is None:
            raise SystemExit(f"Missing required command: {cmd}")
    ok,ipc=wait_for_ipc(args.config,args.wait)
    if not ok:
        print(f"k4barDebug did not register on config {args.config!r}.",file=sys.stderr)
        print(ipc,file=sys.stderr)
        if Path(args.log).exists():
            print("\n=== log tail ===",file=sys.stderr)
            print("\n".join(Path(args.log).read_text(errors="replace").splitlines()[-120:]),file=sys.stderr)
        raise SystemExit(1)

    root=Path(args.output) if args.output else Path("/tmp")/f"k4-bottom-hover-v3-{time.strftime('%Y%m%d-%H%M%S')}"
    root.mkdir(parents=True,exist_ok=True)
    for name in ("state.tsv","cursor.tsv","layers.tsv","bottom-events.log","quickshell-segment.log"):
        (root/name).write_text("")

    log_path=Path(args.log)
    log_start=log_path.stat().st_size if log_path.exists() else 0
    start_ms=now_ms()
    shared=Shared()
    stop=threading.Event()

    def state_cmd():
        return run(["qs","-c",args.config,"ipc","call","k4barDebug","status"])
    def cursor_cmd():
        return run(["hyprctl","-j","cursorpos"])
    def layer_cmd():
        return run(["hyprctl","-j","layers"])

    def state_update(ts,text):
        s=parse_json(text)
        if not isinstance(s,dict):
            return
        with shared.lock:
            shared.latest_status=s
            if shared.first_hover_ms is None and s.get("hovered") is True:
                shared.first_hover_ms=ts

    threads=[
        threading.Thread(target=sampler,args=(stop,args.state_interval,state_cmd,root/"state.tsv",state_update),daemon=True),
        threading.Thread(target=sampler,args=(stop,args.cursor_interval,cursor_cmd,root/"cursor.tsv"),daemon=True),
        threading.Thread(target=sampler,args=(stop,args.layer_interval,layer_cmd,root/"layers.tsv"),daemon=True),
    ]
    for t in threads: t.start()

    print("Capture started.")
    print("Move the pointer onto the COLLAPSED BOTTOM K4 pill, then stop moving it.")
    print("Do not click, type, or move the mouse after the hover begins; this script stops automatically.")

    deadline=time.monotonic()+args.arm_timeout
    first_hover=None
    while time.monotonic()<deadline:
        with shared.lock:
            first_hover=shared.first_hover_ms
        if first_hover is not None:
            break
        time.sleep(0.05)

    if first_hover is None:
        stop.set()
        for t in threads: t.join(timeout=1)
        raise SystemExit("No K4 hover detected before arm timeout.")

    print(f"Auto-armed at {first_hover}. Keep the mouse untouched for {args.post_hover:.1f}s...")
    target=time.monotonic()+args.post_hover
    while time.monotonic()<target:
        time.sleep(0.05)

    stop.set()
    for t in threads: t.join(timeout=1)
    end_ms=now_ms()

    if log_path.exists():
        with log_path.open("rb") as fh:
            fh.seek(log_start)
            seg=fh.read().decode(errors="replace")
        (root/"quickshell-segment.log").write_text(seg)
        lines=[line for line in seg.splitlines() if EVENT_PREFIX in line]
        (root/"bottom-events.log").write_text("\n".join(lines)+("\n" if lines else ""))

    meta={
        "created":time.strftime("%Y-%m-%dT%H:%M:%S%z"),
        "start_ms":start_ms,
        "first_hover_ms":first_hover,
        "pre_roll_ms":args.pre_roll_ms,
        "end_ms":end_ms,
        "post_hover":args.post_hover,
        "config":args.config,
        "log":args.log,
        "git_head":run(["git","rev-parse","HEAD"]),
        "qs_version":run(["qs","--version"]),
        "hyprland_version":run(["hyprctl","version"]),
    }
    (root/"meta.json").write_text(json.dumps(meta,indent=2)+"\n")
    summary=analyze(root)
    (root/"summary.txt").write_text(summary)
    print("\n"+summary)

    archive=Path(str(root)+".tar.gz")
    with tarfile.open(archive,"w:gz") as tf:
        tf.add(root,arcname=root.name)
    print(f"Capture directory: {root}")
    print(f"Bundle: {archive}")
    return root


def main():
    p=argparse.ArgumentParser()
    p.add_argument("--config",default="ii")
    p.add_argument("--log",default="/tmp/ii-vynx-k4.log")
    p.add_argument("--wait",type=float,default=10)
    p.add_argument("--arm-timeout",type=float,default=20)
    p.add_argument("--post-hover",type=float,default=6)
    p.add_argument("--pre-roll-ms",type=int,default=1000)
    p.add_argument("--state-interval",type=float,default=0.10)
    p.add_argument("--cursor-interval",type=float,default=0.05)
    p.add_argument("--layer-interval",type=float,default=0.20)
    p.add_argument("--output")
    p.add_argument("--analyze",metavar="DIR")
    args=p.parse_args()
    if args.analyze:
        print(analyze(Path(args.analyze)),end="")
    else:
        capture(args)


if __name__=="__main__":
    main()
