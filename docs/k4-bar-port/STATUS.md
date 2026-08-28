# K4 Dynamic Island Port — Current Status

Working branch: `agent/k4-bar-port`
Source spec: `docs/k4-bar-port/SPEC.md`
Tickets: `docs/k4-bar-port/TICKETS.md`
Selected v1 design: `docs/k4-bar-port/K4-V1-SYNC-DESIGN.md`
Original K4 implementation reference: `48993812c88f0af5d0c5345cd273467043b889f1`
Selected K4 v1.0 reference: `adcf4216038f7881c4a589baafaaaec841377ad5`

## Current phase

The selected K4 port is in final stabilization/audit work.

K4-01 through K4-10 are closed. The selected v1 behavior has been implemented through K4-V1-04. K4-V1-05 has static review evidence but must not be described as fully runtime-green while the bottom passive-hover regression remains open as issue #22.

The K4-11 managed-plugin lifecycle experiment has been **withdrawn and reverted**. It is no longer a port requirement or completion gate. The current path is K4-V1-05 -> K4-12.

## Closed milestones

- K4-01 variant ownership seam — closed.
- K4-02 island shell and idle pill — closed.
- K4-03 island state/plugin arbitration — closed.
- K4-04 media/Clock/Volume — closed, with known reverse workspace-animation debt deferred.
- K4-05 notifications — closed.
- K4-06 K4 Control Center — closed.
- K4-07 launcher/everyday utilities — closed.
- K4-08 in-island K4 Settings — closed.
- K4-09 thin capture/record utility — closed; editor/transcription explicitly excluded.
- K4-10 selected remaining bundled features — closed; lean Displays only.
- K4-V1-01 Reserve-space + On-top space modes — closed and live-validated.
- K4-V1-02 Hidden + Away-when-fullscreen — closed and live-validated.
- K4-V1-03 Player track-change peek — closed and live-validated.
- K4-V1-04 asymmetric Idle/Clock sizing + active-monitor contract — implementation/live behavior accepted.

Detailed historical review documents remain under `docs/k4-bar-port/`.

## K4-10 Displays boundary

Displays remains monitor-layout only:

```text
K4 Displays UI
  -> existing HyprlandData monitor snapshot
  -> in-memory draft
  -> one-shot hyprctl eval
```

Validated on available one-monitor hardware:

- Displays opens and reads monitor data;
- Refresh discards draft;
- Apply works for available mode/scale/placement controls;
- no persistent helper process/files;
- workspace routing was removed as redundant with ii-vynx dynamic workspaces.

Real multi-monitor relative-placement QA remains for K4-12.

## K4-11 lifecycle experiment — withdrawn

The managed lifecycle is not current architecture.

Removed from the port:

- `K4ManagedPlugin` proxy/Loader ownership;
- persisted per-plugin disablement;
- plugin status/Error/Retry Settings UI;
- lifecycle fault/debug IPC and probe infrastructure;
- lifecycle-specific tests.

Affected utilities are again directly/declaratively owned by `K4BuiltinPlugins.qml`. Their actual utility implementations and unrelated fixes remain intact.

The earlier manual dynamic-object approach using `Qt.createComponent()`, `createObject()` and `.destroy()` remains rejected because it caused native Qt/QML lifetime failures. Withdrawal means static declarative ownership, not a return to manual QObject lifetime.

## Selected K4 v1.0 review

Compared original reference `48993812...` with K4 `v1.0.0` `adcf4216...`.

### Approved

- U1 bar space/overlay modes;
- U2 per-monitor fullscreen detection;
- U3 Hidden edge reveal;
- U4 Player track-change peek;
- U6 compact asymmetric Idle/Clock sizing;
- U17 active-island-monitor API;
- U19 capture-only review if applicable.

### Rejected

- U5 Dual/dock;
- U7-U9 HyprTheme wallpaper/video/palette stack;
- U10-U11 plugin store/public plugin ecosystem;
- U13 K4 self-update status;
- U14 agent skill installer;
- U15 live window thumbnails;
- U16 generalized auxiliary-window API expansion;
- U18 upstream translation subsystem;
- U20 installer/docs polish as runtime scope.

The prior U12 lifecycle/extensibility exploration was subsequently withdrawn from the port; upstream manual QObject ownership remains rejected.

## U19 capture audit

The applicable upstream v1 capture delta is structured/localized failure-reason plumbing in K4's own Python capture/editor stack. ii-vynx K4 Capture intentionally delegates to existing ii capture/record owners and does not own that stack.

**Result: no U19 runtime port is required.**

The editor/transcription stack remains excluded.

## K4-V1 behavior evidence

### Space modes / fullscreen / Hidden

The host supports:

```text
Reserve space
Away when fullscreen
On top
Hidden
```

The implementation reuses existing `HyprlandData` state, keeps one K4 layer surface per screen, uses a narrow island-width reveal target, and does not add a second fullscreen/workspace owner.

### Player track-change peek

Player track-change peek reuses `K4Media`, settles split metadata before comparison, ignores initial discovery/empty/unchanged identity and exposes the persisted `playerPeekOnTrackChange` setting.

### Asymmetric Idle/Clock sizing

Collapsed Idle and expanded Clock use sequential measured zones rather than mirroring the wider side. `IslandState.activeScreen` remains the plugin-facing active-monitor contract.

## Open runtime exception

Issue #22 — `K4: bottom passive hover double-spawns after expansion` — remains open/deferred.

Evidence shows one K4 layer surface whose hover/session state is lost and later reopened; it is not a duplicate host. Previous timer/bridge/surface-resize workarounds did not resolve it. Do not add another speculative timing/surface workaround without new runtime evidence.

K4-V1-05 therefore remains not fully runtime-green while #22 is open.

## Important architectural constraints

- one owner per global desktop facility;
- no new daemon/persistent service/external dependency without explicit approval;
- K4 uses existing ii-vynx media/audio/notification/network/clipboard/session/Hyprland/capture owners;
- K4 remains dark-styled; Liquid Glass is separate Standard-bar work;
- Displays does not own dynamic workspace routing;
- external plugin ecosystem remains out;
- built-in plugins are directly/declaratively owned; no manual QObject lifetime system.

## Deferred debt

- Bottom passive-hover double-spawn: issue #22.
- Reverse workspace animation can skip the desired shrink/grow on some reverse transitions such as `3 -> 2` / `3 -> 1`; revisit only when workspace presentation itself is expanded/redesigned.
- Real multi-monitor Displays relative placement and K4 per-monitor fullscreen behavior require hardware validation in K4-12 if unavailable earlier.

## Next action

Run the consolidated K4 source suite and one live smoke after the lifecycle-removal cleanup. If green, proceed with the remaining K4-V1-05/K4-12 closure work; do not perform per-plugin lifecycle validation because that feature no longer exists.
