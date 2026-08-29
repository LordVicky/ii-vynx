#!/usr/bin/env python3
"""Mark the exact user-visible K4 #22 double-spawn and correlate runtime evidence."""
from __future__ import annotations
import argparse, json, re, select, shutil, subprocess, sys, tarfile, threading, time
from pathlib import Path

PREFIX='[K4BottomHover]'

def now_ms(): return time.time_ns()//1_000_000

def run(cmd, timeout=0.9):
    try:
        p=subprocess.run(cmd,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,timeout=timeout,check=False)
        return p.stdout.strip()
    except subprocess.TimeoutExpired: return '<timeout>'
    except OSError as e: return f'<os-error:{e}>'

def j(s):
    try: return json.loads(s)
    except Exception: return None

def compact(s): return ' '.join(s.replace('\t',' ').splitlines())

def sampler(stop, interval, fn, path):
    nxt=time.monotonic()
    with path.open('a',encoding='utf-8') as f:
        while not stop.is_set():
            f.write(f'{now_ms()}\t{compact(fn())}\n'); f.flush()
            nxt+=interval; delay=nxt-time.monotonic()
            if delay>0: stop.wait(delay)
            else: nxt=time.monotonic()

def read_tsv(path):
    out=[]
    for line in path.read_text(errors='replace').splitlines() if path.exists() else []:
        p=line.split('\t',1)
        if len(p)==2:
            try: out.append((int(p[0]),p[1]))
            except ValueError: pass
    return out

def parse_event(line):
    m=re.search(r'\[K4BottomHover\]\s+(\d+)\s+(\S+)(.*)$',line)
    if not m: return None
    e={'ts':int(m.group(1)),'reason':m.group(2),'raw':line.strip()}
    for k,v in re.findall(r'([A-Za-z][A-Za-z0-9_]*)=\s*([^\s]+)',m.group(3)):
        if v in ('true','false'): e[k]=(v=='true')
        else:
            try: e[k]=float(v) if '.' in v else int(v)
            except ValueError: e[k]=v
    return e

def find_layers(v):
    out=[]
    if isinstance(v,dict):
        if v.get('namespace')=='quickshell:k4bar': out.append(v)
        for x in v.values(): out.extend(find_layers(x))
    elif isinstance(v,list):
        for x in v: out.extend(find_layers(x))
    return out

def cursor_xy(v):
    if isinstance(v,dict) and isinstance(v.get('x'),(int,float)) and isinstance(v.get('y'),(int,float)):
        return (v['x'],v['y'])
    if isinstance(v,list) and len(v)>=2 and all(isinstance(x,(int,float)) for x in v[:2]): return tuple(v[:2])
    return None

def wait_ipc(config, secs):
    end=time.monotonic()+secs; last=''
    while time.monotonic()<end:
        last=run(['qs','-c',config,'ipc','show'])
        if re.search(r'^target\s+k4barDebug\b',last,re.M): return True,last
        time.sleep(.25)
    return False,last

def analyze(root):
    meta=j((root/'meta.json').read_text()) or {}; mark=int(meta['marker_ms']); pre=int(meta['pre_ms']); post=int(meta['post_ms'])
    lo,hi=mark-pre,mark+post
    states=[(t,j(v)) for t,v in read_tsv(root/'state.tsv') if lo<=t<=hi]
    cursors=[(t,j(v)) for t,v in read_tsv(root/'cursor.tsv') if lo<=t<=hi]
    layers=[(t,j(v)) for t,v in read_tsv(root/'layers.tsv') if lo<=t<=hi]
    events=[]
    for line in (root/'bottom-events.log').read_text(errors='replace').splitlines():
        e=parse_event(line)
        if e and lo<=e['ts']<=hi: events.append(e)
    out=['K4 #22 visual-marker diagnostic','================================',f'marker_ms: {mark}',f'window: -{pre}ms .. +{post}ms',f'events_in_window: {len(events)}','']
    out.append('IPC transitions:')
    prev=object()
    for t,s in states:
        if not isinstance(s,dict): continue
        key=(s.get('occupant'),s.get('hovered'),s.get('activeScreen'))
        if key!=prev:
            out.append(f'  {t-mark:+6d}ms  occupant={key[0]!r} hovered={key[1]!r} screen={key[2]!r}')
            prev=key
    out.append('\nQML events:')
    for e in events:
        out.append(f"  {e['ts']-mark:+6d}ms  {e['reason']:<30} visible={e.get('visible')} ptr={e.get('pointerOver')} island={e.get('island')} bridge={e.get('bridge')} state={e.get('stateHovered')} passive={e.get('passive')} surfaceH={e.get('surfaceH')} islandH={e.get('islandH')}")
    out.append('\nK4 layer geometry changes:')
    prev=None
    for t,obj in layers:
        ms=find_layers(obj)
        if not ms: continue
        x=ms[0]; key=(x.get('address'),x.get('x'),x.get('y'),x.get('w'),x.get('h'))
        if key!=prev:
            out.append(f'  {t-mark:+6d}ms  address={key[0]} x={key[1]} y={key[2]} w={key[3]} h={key[4]}')
            prev=key
    pts=[(t,cursor_xy(v)) for t,v in cursors if cursor_xy(v) is not None]
    if pts:
        nearest=min(pts,key=lambda p:abs(p[0]-mark)); xs=[p[1][0] for p in pts]; ys=[p[1][1] for p in pts]
        out += ['\nCursor:',f'  at marker: {nearest[1]} ({nearest[0]-mark:+d}ms sample)',f'  window span: x={min(xs)}..{max(xs)}, y={min(ys)}..{max(ys)}']
    occ=[s.get('occupant') for _,s in states if isinstance(s,dict)]; reasons=[e['reason'] for e in events]
    out.append('\nInterpretation hints:')
    if any(o in ('clock','player') for o in occ) and 'idle' in occ: out.append('  Occupant changes are present near the visual marker; inspect IPC/QML ordering above.')
    else: out.append('  No passive<->idle occupant transition is sampled near the visual marker.')
    if 'surface-height' in reasons: out.append('  A layer-surface height configure occurred near the visual marker.')
    if 'island-height-animation-start' in reasons or 'island-height-animation-done' in reasons: out.append('  An island height animation boundary occurred near the visual marker.')
    if not events: out.append('  No K4 QML probe event occurred near the marker; widen the window or verify the log path.')
    return '\n'.join(out)+'\n'

def main():
    p=argparse.ArgumentParser()
    p.add_argument('--config',default='ii'); p.add_argument('--log',default='/tmp/ii-vynx-k4.log'); p.add_argument('--wait',type=float,default=10)
    p.add_argument('--max-seconds',type=float,default=60); p.add_argument('--pre',type=float,default=3.0); p.add_argument('--post',type=float,default=2.0); p.add_argument('--output')
    a=p.parse_args()
    for cmd in ('qs','hyprctl'):
        if not shutil.which(cmd): raise SystemExit(f'Missing required command: {cmd}')
    ok,last=wait_ipc(a.config,a.wait)
    if not ok: raise SystemExit(f'k4barDebug did not register on {a.config!r}.\n{last}')
    root=Path(a.output) if a.output else Path('/tmp')/f"k4-bottom-hover-marker-{time.strftime('%Y%m%d-%H%M%S')}"; root.mkdir(parents=True,exist_ok=True)
    for n in ('state.tsv','cursor.tsv','layers.tsv','quickshell-segment.log','bottom-events.log'): (root/n).write_text('')
    log=Path(a.log); log_start=log.stat().st_size if log.exists() else 0; start=now_ms(); stop=threading.Event()
    state=lambda:run(['qs','-c',a.config,'ipc','call','k4barDebug','status']); cursor=lambda:run(['hyprctl','-j','cursorpos']); layers=lambda:run(['hyprctl','-j','layers'])
    threads=[threading.Thread(target=sampler,args=(stop,.10,state,root/'state.tsv'),daemon=True),threading.Thread(target=sampler,args=(stop,.05,cursor,root/'cursor.tsv'),daemon=True),threading.Thread(target=sampler,args=(stop,.20,layers,root/'layers.tsv'),daemon=True)]
    for t in threads:t.start()
    print('Capture running. Reproduce #22 normally.')
    print('Press ENTER at the instant you SEE the unwanted second spawn. Do not move the mouse just to mark it.')
    ready,_,_=select.select([sys.stdin],[],[],a.max_seconds)
    if not ready:
        stop.set(); [t.join(timeout=1) for t in threads]; raise SystemExit('No marker received before timeout; no bundle created.')
    sys.stdin.readline(); marker=now_ms(); print(f'Marked at {marker}. Capturing {a.post:.1f}s post-roll...')
    time.sleep(a.post); stop.set(); [t.join(timeout=1) for t in threads]; end=now_ms()
    if log.exists():
        with log.open('rb') as f:f.seek(log_start); seg=f.read().decode(errors='replace')
        (root/'quickshell-segment.log').write_text(seg); lines=[x for x in seg.splitlines() if PREFIX in x]; (root/'bottom-events.log').write_text('\n'.join(lines)+('\n' if lines else ''))
    meta={'created':time.strftime('%Y-%m-%dT%H:%M:%S%z'),'start_ms':start,'marker_ms':marker,'end_ms':end,'pre_ms':int(a.pre*1000),'post_ms':int(a.post*1000),'git_head':run(['git','rev-parse','HEAD']),'config':a.config,'log':a.log}
    (root/'meta.json').write_text(json.dumps(meta,indent=2)+'\n'); summary=analyze(root); (root/'summary.txt').write_text(summary); print('\n'+summary)
    arc=Path(str(root)+'.tar.gz')
    with tarfile.open(arc,'w:gz') as tf:tf.add(root,arcname=root.name)
    print(f'Bundle: {arc}')
if __name__=='__main__': main()
