# k4 Dynamic Island Port — Status

Working branch: `agent/k4-bar-port`
Source spec: `docs/k4-bar-port/SPEC.md`
Tickets: `docs/k4-bar-port/TICKETS.md`
Pinned k4 source: `48993812c88f0af5d0c5345cd273467043b889f1`

## Current phase

`K4-03 — Island state + plugin arbitration`: implementation and Standards + Spec review complete; source-test execution and real-shell demo validation pending.

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

## K4-03 implemented

The deep host/state/plugin seam now exists before feature views:
- `IslandState.qml` owns requested/active monitor routing, k4-compatible `arriba`/`abajo` position publication, `{x,y,ancho,alto}` geometry per screen, temporary placement ownership, gesture cooldown, and hidden/system-dialog suppression;
- `K4Plugin.qml` defines the enabled/active/priority/transient/dimensions/view/focus/background/hover boundary;
- disabled plugin requests are gated in the simplified K4-03 lifecycle so an inactive object cannot leave stale active/placement/gesture state; full destroy/recreate lifecycle remains K4-11;
- `K4PluginController.qml` owns highest-priority enabled-active arbitration, idle fallback, transient preemption, monitor ownership, open publication, background-tap routing, and hover-exit timers;
- `K4Bar.qml` renders the expanded winner only on `IslandState.activeScreen`; every other screen retains `K4IdlePill`;
- the compositor exclusive zone remains 34px while expanded content floats over windows;
- suppression keeps the layer surface mapped, sets island opacity to zero, removes its input mask, and drops keyboard focus instead of remapping the `PanelWindow`;
- keyboard policy supports none, exclusive, on-hover exclusive, and on-demand; Escape closes the visible non-idle plugin after nested controls can consume the event;
- only the visible enabled plugin view is loaded;
- island geometry is published on animated x/width/height and top/bottom changes;
- placement uses the upstream animated fraction model and gestures use the upstream `sacudida` / `empujon` / `tiron` contract;
- a temporary `k4barDebug` IPC harness supplies transient/secondary/primary demo plugins for K4-03 validation only.

Key K4-03 implementation/reviewer commits:
- `816aadb` — island state service;
- `4608254c` — plugin contract;
- `e1dbae2d` — arbitration controller;
- `ec4595a5` — inert demo view;
- `f64313df` — host wiring;
- `a0b9614f` — restore upstream state vocabulary and reset host-scoped singleton state;
- `bd0ca03b` — preserve monitor routing, geometry keys, and gesture names;
- `c2f60b5b` — gate requests from disabled simplified-lifecycle plugins;
- `23aace93` — expose geometry/state in debug status for live validation.

## K4-03 Standards + Spec review

### Standards

- Arbitration policy is isolated from `PanelWindow` rendering in `K4PluginController`.
- Long-lived host state is centralized in `IslandState`; feature plugins request behavior rather than writing host geometry directly.
- The Standard bar implementation and global ii service owners are untouched.
- No new notification/media/audio/network owner is introduced.
- The layer surface remains mapped during temporary suppression, avoiding the known Wayland remap lifecycle hazard.
- Plugin views are lazy at the Loader boundary; inactive demo view components are not instantiated.
- Disabled simplified-lifecycle plugins cannot issue new active, placement, or gesture requests.
- Reviewer fixes preserved k4's public state vocabulary rather than inventing an incompatible bridge.

### Spec

K4-03 source now covers every ticket item:
- first-class island state;
- base plugin interface and enabled lifecycle;
- highest-priority active winner with idle fallback;
- transient preemption;
- requested/active monitor routing;
- single-monitor expansion with idle pills elsewhere;
- safe active-only view loading;
- hover-exit timing;
- keyboard/Escape policy;
- temporary placement ownership;
- physical gesture requests;
- per-monitor geometry publication;
- hidden/dialog rendering and input suppression.

Dynamic catalog discovery, plugin persistence, external plugin loading, and destroy/recreate lifecycle are intentionally deferred to K4-11.

## Automated checks

Run from the repository root:

```bash
node --test \
  tests/k4-bar-variant.test.js \
  tests/k4-idle-shell.test.js \
  tests/k4-plugin-host.test.js
```

The connected GitHub branch is not mounted as a local checkout in the implementation environment, and the available container has no network route to GitHub. Therefore the new Node suites have been source-reviewed but not executed here; execution is part of the user's validation gate.

## Required K4-03 live validation

After deploying/restarting the branch in k4 mode:

1. `qs -c ii ipc call k4barDebug status` — idle baseline should report `occupant: "idle"`, `open: false`; `rect`/`rects` should contain nonzero `ancho`/`alto` and `position` should be `arriba` or `abajo`.
2. `qs -c ii ipc call k4barDebug openTransient` — island expands to the Transient demo; status should report `demo-transient` and `transientActive: true`.
3. `qs -c ii ipc call k4barDebug openSecondary` — Secondary wins and the lower transient is dismissed; status should report `demo-secondary`, `transientActive: false`.
4. `qs -c ii ipc call k4barDebug openPrimary` — Primary wins while Secondary remains active underneath. Then `closePrimary`; Secondary should reappear, proving preemption does not destroy the other plugin.
5. With Primary visible, click the island once and press Escape; it should close to the next eligible plugin/idle without stealing keyboard focus afterward.
6. Open Secondary and click its empty/background area; its background-tap policy should close it.
7. `disablePrimary`, then `openPrimary`; Primary must not become active. `enablePrimary` must not unexpectedly open it from stale state.
8. Open Primary, then `placePrimary 0.15 2500`; the island should animate toward 15% placement and automatically return to the configured alignment after about 2.5 seconds. `status` should show/clear `placementOwner` accordingly.
9. Call `gesture sacudida 1`, `gesture empujon 1`, and `gesture tiron 1` with more than 500ms between calls; the physical animations should play without resizing the exclusive zone.
10. `hideIsland` should make the island invisible/non-interactive without moving windows; `showIsland` should restore it. Switching k4 → Standard → k4 after a hide must return with suppression reset.
11. If multiple monitors are available, close all demos, then call `openPrimaryOn <SCREEN_NAME>` using an exact screen name from `hyprctl monitors -j | jq -r '.[].name'`; only that monitor should expand while all other monitors retain idle pills. `status.activeScreen` must match the requested name.
12. Finish with `qs -c ii ipc call k4barDebug closeAll`; the normal K4-02 idle/media/recording pill must still work.

## Next action after validation

If the Node suites and K4-03 live gate pass, close K4-03 and begin K4-04/K4-05 from the ticket dependency graph. Do not port complex feature plugins before this host seam is validated.
