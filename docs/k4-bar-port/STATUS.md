# k4 Dynamic Island Port — Status

Working branch: `agent/k4-bar-port`
Source spec: `docs/k4-bar-port/SPEC.md`
Tickets: `docs/k4-bar-port/TICKETS.md`
Pinned k4 source: `48993812c88f0af5d0c5345cd273467043b889f1`

## Current phase

`K4-03 — Island state + plugin arbitration`: implementation starting after K4-02 live validation completed successfully.

Do not start dependent K4-04/K4-05 work until K4-03's demo-plugin arbitration/monitor/focus smoke test passes or any discovered issue is fixed and re-reviewed.

## K4-01 — validated

The user validated K4-01 in the live shell on 2026-08-22.

Observed:
- Bar Settings exposes Standard and k4 Dynamic Island variants.
- k4 Position and Alignment controls are visible while Standard-only settings are hidden.
- k4 mode replaces the Standard bar with the inert checkpoint capsule.
- `node --test tests/k4-bar-variant.test.js` passed 4/4 with zero failures.

K4-01 is closed.

## K4-02 — validated

Implemented:
- k4 visual tokens live in `modules/ii/k4bar/K4Theme.qml`;
- black k4 surface, 16px wings, 34px collapsed height, 880px surface ceiling;
- inverse-wing `Shape` silhouette with bottom reflection and 8x MSAA;
- collapsed-only compositor reservation and upstream delayed surface shrink;
- upstream OutBack width/height animation timings;
- pointer mask restricted to island geometry;
- centered clock with symmetric side reservation;
- upstream moving three-workspace viewport and 1800ms return;
- playing-media artwork + lightweight four-bar visualizer using existing ii MPRIS state;
- recording indicator using existing `Persistent.states.screenRecord` state;
- k4 attribution through `licenses/k4-NOTICE.txt`;
- Standard-only Liquid Glass sidebar reservation while k4 owns the bar.

### Live validation

Round 1 validated silhouette, top/bottom reflection, compact idle state, workspace transition, and lock/unlock ownership. It found two integration bugs:

1. Media lifecycle failed after the last MPRIS player disappeared. Fixed in `59ee919e` by deriving the active player directly from live `Mpris.players.values`, matching pinned k4.
2. Recording indicator could not resolve `Persistent`. Fixed in `4a1e5abb` by importing `qs.modules.common`, without changing recorder ownership.

Regression source coverage landed in `6affea6b`.

Final real-shell retest on 2026-08-22 passed all previously failing cases:
- clock-only → launch/play media: **passed**;
- player exits completely → later relaunch/play without Quickshell restart: **passed**;
- pause/resume contraction and expansion: **passed**;
- ii-vynx recording indicator start/stop: **passed**.

The three-workspace viewport is intentional upstream k4 behavior and remains unchanged for the faithful-port phase.

K4-02 is closed.

## K4-02 Standards + Spec review

### Standards

- k4-specific rendering remains under `modules/ii/k4bar/`.
- Existing Standard bar implementation files remain untouched.
- Existing ii services are consumed through their current public state; no duplicate notification, media, workspace, or recording owner was introduced.
- Continuous animation exists only while media is playing or recording is active.
- The k4 idle visualizer does not launch `cava` or another persistent process.
- Variant-sensitive sidebar reservation is enforced at the integration seam.
- Runtime regressions were fixed at their demonstrated causes rather than by adding timers or duplicate owners.

### Spec

K4-02 satisfies:
- 34px collapsed reservation semantics;
- pixel-faithful inverse wings;
- top/bottom reflection;
- width/height animation shell and delayed shrink;
- input mask scoped to island geometry;
- faithful idle clock/workspace/media composition;
- symmetric side-width measurement;
- all-monitor idle behavior;
- k4 attribution before substantial derived rendering code.

## Automated checks

Run from the repository root:

```bash
node --test tests/k4-bar-variant.test.js tests/k4-idle-shell.test.js
```

The implementation environment cannot execute the user's Quickshell/Wayland compositor session, so runtime checks are performed in the user's live shell.

## K4-03 target

Introduce the first-class island host seam before feature plugins:
- ii-owned `IslandState` singleton with upstream requested/active monitor state, published geometry, temporary placement ownership, physical gesture requests, and hidden/dialog input suppression;
- base island plugin contract and enabled lifecycle;
- highest-priority enabled active plugin wins with idle fallback;
- transient preemption;
- per-monitor expanded ownership while other monitors retain idle pills;
- safe active-view loading;
- hover-exit timer policy;
- keyboard/Escape policy;
- a small demo plugin path that proves open → resize → close, priority preemption, monitor routing, and transient dismissal.

## Next validation boundary

K4-03 is not complete until the demo-plugin source tests pass and the user confirms the island can open/resize/close, route to the requested monitor, preempt a transient, and return to idle without breaking the other demo plugin.
