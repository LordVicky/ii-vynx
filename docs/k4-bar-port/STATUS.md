# k4 Dynamic Island Port — Status

Working branch: `agent/k4-bar-port`
Source spec: `docs/k4-bar-port/SPEC.md`
Tickets: `docs/k4-bar-port/TICKETS.md`
Pinned k4 source: `48993812c88f0af5d0c5345cd273467043b889f1`

## Current phase

`K4-03 — Island state + plugin arbitration`: **validated and closed**.

Next ticket: `K4-04 — Core media/clock/volume parity`.

Do not start dependent complex feature plugins before K4-04's own review/validation boundary.

## K4-01 — validated

The user validated K4-01 in the live shell on 2026-08-22.

Observed:
- Bar Settings exposes Standard and k4 Dynamic Island variants.
- k4 Position and Alignment controls are visible while Standard-only settings are hidden.
- k4 mode replaces the Standard bar.
- source-contract tests passed.

K4-01 is closed.

## K4-02 — validated

Implemented and validated:
- k4 visual tokens in `modules/ii/k4bar/K4Theme.qml`;
- black k4 surface, 16px wings, 34px collapsed height, 880px surface ceiling;
- inverse-wing `Shape` silhouette with bottom reflection and 8x MSAA;
- collapsed-only compositor reservation and upstream delayed surface shrink;
- upstream OutBack width/height animation timings;
- pointer mask restricted to island geometry;
- centered clock with symmetric side reservation;
- upstream moving three-workspace viewport and 1800ms return;
- playing-media artwork + lightweight four-bar visualizer using live ii MPRIS state;
- recording indicator using existing `Persistent.states.screenRecord` state;
- k4 attribution through `licenses/k4-NOTICE.txt`.

Round-1 runtime validation found and fixed two integration bugs:
1. media lifecycle after the last MPRIS player disappeared (`59ee919e`);
2. missing common-state import for `Persistent` recording state (`4a1e5abb`).

Final live retest passed:
- clock-only → launch/play media;
- player exits completely → later relaunch/play without Quickshell restart;
- pause/resume contraction and expansion;
- ii-vynx recording indicator start/stop;
- top/bottom reflection;
- workspace transition;
- lock/unlock ownership.

The three-workspace viewport is intentional upstream k4 behavior and remains unchanged for the faithful-port phase.

K4-02 is closed.

## K4-03 — implemented

The deep host/state/plugin seam now exists before feature views:
- `IslandState.qml` owns requested/active monitor routing, k4-compatible `arriba`/`abajo` position publication, `{x,y,ancho,alto}` geometry per screen, temporary placement ownership, gesture cooldown, and hidden/system-dialog suppression;
- `K4Plugin.qml` defines the enabled/active/priority/`transitorio`/dimensions/view/focus/background/hover boundary;
- disabled plugin requests are gated in the simplified K4-03 lifecycle so an inactive object cannot leave stale active/placement/gesture state; full destroy/recreate lifecycle remains K4-11;
- `K4PluginController.qml` owns highest-priority enabled-active arbitration, idle fallback, transient preemption, monitor ownership, open publication, background-tap routing, and hover-exit timers;
- `K4Bar.qml` renders the expanded winner only on `IslandState.activeScreen`; every other screen retains `K4IdlePill`;
- the compositor exclusive zone remains 34px while expanded content floats over windows;
- suppression keeps the layer surface mapped, sets island opacity to zero, removes its input mask, and drops keyboard focus instead of remapping the `PanelWindow`;
- keyboard policy supports none, exclusive, on-hover exclusive, and on-demand; Escape closes the visible non-idle plugin after nested controls can consume the event;
- only the visible enabled plugin view is loaded;
- island geometry is published on animated x/width/height and top/bottom changes;
- placement uses the upstream animated fraction model;
- gestures use the upstream `sacudida` / `empujon` / `tiron` contract;
- a temporary `k4barDebug` IPC harness supplies transient/secondary/primary demo plugins for K4-03 validation only.

Key implementation/reviewer fixes:
- `816aadb` — island state service;
- `4608254c` — plugin contract;
- `e1dbae2d` — arbitration controller;
- `ec4595a5` — inert demo view;
- `f64313df` — host wiring;
- `a0b9614f` — restore upstream state vocabulary and reset host-scoped singleton state;
- `bd0ca03b` — preserve monitor routing, geometry keys, and gesture names;
- `c2f60b5b` — gate requests from disabled simplified-lifecycle plugins;
- `23aace93` — expose geometry/state in debug status;
- `9d1bec7c` — deterministic initial winner publication;
- `5b28cae6` / `27c12964` / `fbe40506` — restore pinned k4 `transitorio` API after the translated identifier `transient` proved to be a reserved QML keyword;
- `0470b463` — regression coverage for the `transitorio` parser contract;
- `f7f5a0ea` — follow the K4-03 alignment state seam in K4-01 regression coverage.

The parser regression produced Quickshell exit 255 before the `transitorio` fix. Live retest afterward reported `INFO: Configuration Loaded` with no k4bar load errors.

## Liquid Glass integration state

The k4 branch is synchronized with the Liquid Glass base through `438de909`.

The newer Liquid Glass sidebar architecture removed the old top/bottom bar-specific dashboard inset mechanism entirely. The obsolete k4 Standard-only reserve shim was therefore removed during the two-parent sync rather than preserved.

Regression coverage now asserts that no bar-specific dashboard inset state exists and `SidebarDashboardGlass` uses `ExclusionMode.Normal`.

## K4-03 automated validation

Run from the repository root:

```bash
node --test \
  tests/k4-bar-variant.test.js \
  tests/k4-idle-shell.test.js \
  tests/k4-plugin-host.test.js
```

User result on 2026-08-22:
- tests: 16
- pass: 16
- fail: 0

## K4-03 live validation

Validated on 2026-08-22:
- idle publication: `occupant: "idle"`, `open: false`, nonzero `{ancho, alto}` geometry;
- transient demo wins from idle;
- Secondary preempts/dismisses the transient;
- Primary preempts Secondary while preserving Secondary underneath;
- closing Primary reveals Secondary again;
- Escape closes Primary and keyboard focus returns normally;
- Secondary background tap closes Secondary;
- disabled Primary rejects an open request;
- re-enabling Primary does not resurrect stale active state;
- temporary placement ownership moves to `0.15`, then releases and returns to configured `0.5` placement;
- all three physical gesture animations render and do not disturb plugin ownership;
- hide/show suppression preserves the active plugin and does not move surrounding windows;
- k4 → Standard → k4 clears host-scoped suppression/plugin state and restores the idle pill;
- final cleanup returns to normal K4-02 idle behavior.

Multi-monitor live routing was not applicable: the test machine currently exposes one monitor (`DP-3`). The multi-monitor routing contract remains source-covered and follows the pinned k4 host model, but has not yet received compositor validation on a multi-monitor setup.

### Gesture fidelity decision

The user supplied a recording of the K4-03 gestures. During the vertical gestures the full island silhouette visibly leaves the screen edge for a moment.

This is **intentional pinned-k4 behavior** and remains unchanged for the faithful-port stage. Upstream applies `Translate` to the island content/silhouette and explicitly describes vertical gestures as pushing the island into the screen:
- `empujon`: y → 26px, then returns with OutBack;
- `tiron`: y → 10px → 2px → 12px → 0;
- bottom placement reverses the direction.

A Vynx-specific alternative that keeps the inverse wings pinned while deforming only the body may be considered later as customization, but is not part of the fidelity port.

K4-03 is closed.

## K4-03 Standards + Spec review

### Standards

- Arbitration policy is isolated from `PanelWindow` rendering in `K4PluginController`.
- Long-lived host state is centralized in `IslandState`; feature plugins request behavior rather than writing host geometry directly.
- The Standard bar implementation and global ii service owners are untouched.
- No new notification/media/audio/network owner is introduced.
- The layer surface remains mapped during temporary suppression.
- Plugin views are lazy at the Loader boundary; inactive demo view components are not instantiated.
- Disabled simplified-lifecycle plugins cannot issue new active, placement, or gesture requests.
- Reviewer fixes preserve pinned k4 public state vocabulary rather than inventing an incompatible bridge.
- Existing unrelated Quickshell warnings are treated as baseline noise unless they point at k4bar/changed files or correlate with a failed K4 behavior check.

### Spec

K4-03 satisfies:
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

Dynamic catalog discovery, plugin persistence, external plugin loading, and destroy/recreate lifecycle remain intentionally deferred to K4-11.

## Next action

Begin `K4-04 — Core media/clock/volume parity` from `TICKETS.md` using small vertical slices and stop again at its live-shell validation boundary before advancing dependent work.
