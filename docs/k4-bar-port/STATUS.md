# K4 Dynamic Island Port — Current Status

Working branch: `agent/k4-bar-port`
Source spec: `docs/k4-bar-port/SPEC.md`
Tickets: `docs/k4-bar-port/TICKETS.md`
Selected v1 design: `docs/k4-bar-port/K4-V1-SYNC-DESIGN.md`
Original K4 implementation reference: `48993812c88f0af5d0c5345cd273467043b889f1`
Selected K4 v1.0 reference: `adcf4216038f7881c4a589baafaaaec841377ad5`

## Current phase

**K4-V1 selected upstream sync — ready for implementation.**

Next ticket: **K4-V1-01 — Space-mode seam: Reserve + On top.**

K4-11 built-in lifecycle work is deliberately paused while the approved v1.0 sync changes host reservation, Hidden behavior, Player ambient activation and Idle/Clock geometry.

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

## K4-11 accepted lifecycle architecture

The original manual dynamic-object approach using `Qt.createComponent()`, `createObject()` and `.destroy()` caused native QtQmlModels/QQmlIncubator crashes and is permanently rejected.

Validated replacement:

```text
stable K4ManagedPlugin proxy -> declarative Loader -> implementation
```

Evidence:

- isolated Loader probe completed 21 create/release cycles with matching counts and no crash signatures;
- Displays disable/re-enable, persisted-disabled boot, 20-cycle stress and clean shutdown passed;
- Displays deliberate load failure remained isolated, Error/Retry/disable behavior passed, and restore+Retry recovered;
- Keys/Shortcuts repeated the managed lifecycle and failure/recovery matrix successfully;
- deliberate fault injection produces only the expected `__K4MissingManagedPlugin.qml: File not found` warning.

The System/Windows/Session low-coupling proxy batch is committed at `f1cf5eb714a73cd230faa25d7ac25e7040d9c750` but **has not yet received live-shell validation** because the upstream v1 review interrupted the sequence.

## Selected K4 v1.0 review

Compared original reference `48993812...` with K4 `v1.0.0` `adcf4216...` (38 commits).

### Approved

- U1 bar space/overlay modes;
- U2 per-monitor fullscreen detection;
- U3 Hidden edge reveal;
- U4 Player track-change peek;
- U6 compact asymmetric Idle/Clock sizing;
- U12 lifecycle/extensibility ideas only if useful, never upstream manual QObject ownership;
- U17 active-island-monitor API;
- U19 capture-only review, port only if applicable.

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

Rejected items are product decisions, not deferred parity work.

## U19 capture audit

The applicable upstream v1 capture delta is structured/localized failure-reason plumbing in K4's own Python capture/editor stack. ii-vynx K4 Capture intentionally delegates to existing ii capture/record owners and does not own that stack.

**Result: no U19 runtime port is required.**

The editor/transcription stack remains excluded. K4-V1 Hidden validation must still prove that capture confirmation reveals a hidden island through ordinary plugin activation.

## K4-V1 implementation plan

### K4-V1-01

Add persisted `spaceMode`, narrow `HyprlandData.monitorHasFullscreen()` query, K4 Settings choice and host effective-mode/exclusive-zone seam. Live gate Reserve versus On top before implementing Hidden animation.

### K4-V1-02

Add Hidden withdrawal/reveal edge/input-mask behavior and Away-when-fullscreen per-monitor rule.

### K4-V1-03

Add configured Player track-change peek using existing `K4Media`, with metadata settling and initial-discovery guard.

### K4-V1-04

Restructure Idle/Clock to asymmetric measured zones and formalize `IslandState.activeScreen` as stable plugin-facing active-monitor state.

### K4-V1-05

Run selected-v1 Standards + Spec review and real-shell validation matrix.

After K4-V1-05, resume K4-11 lifecycle migration and then finish with K4-12.

## Important architectural constraints

- one owner per global desktop facility;
- no new daemon/persistent service/external dependency without explicit approval;
- K4 uses existing ii-vynx media/audio/notification/network/clipboard/session/Hyprland/capture owners;
- K4 remains dark-styled; Liquid Glass is separate Standard-bar work;
- Displays does not own dynamic workspace routing;
- external plugin ecosystem remains out;
- no manual QObject lifetime for plugins.

## Deferred debt

- Reverse workspace animation can skip the desired shrink/grow on some reverse transitions such as `3 -> 2` / `3 -> 1`; revisit only when workspace presentation itself is expanded/redesigned.
- Real multi-monitor Displays relative placement and K4 per-monitor fullscreen behavior require hardware validation in K4-12 if unavailable earlier.

## Next action

Implement **K4-V1-01** with the smallest vertical slice:

1. red source contract for `spaceMode`, fullscreen query and host reservation semantics;
2. Config/K4Settings/Settings UI;
3. existing-owner fullscreen query in `HyprlandData`;
4. K4 host Reserve/On top effective mode;
5. source review;
6. user live validation before K4-V1-02.
