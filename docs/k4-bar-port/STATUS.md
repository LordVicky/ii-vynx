# K4 Dynamic Island Port — Current Status

Working branch: `agent/k4-bar-port`
Source spec: `docs/k4-bar-port/SPEC.md`
Tickets: `docs/k4-bar-port/TICKETS.md`
Selected v1 design: `docs/k4-bar-port/K4-V1-SYNC-DESIGN.md`
Original K4 implementation reference: `48993812c88f0af5d0c5345cd273467043b889f1`
Selected K4 v1.0 reference: `adcf4216038f7881c4a589baafaaaec841377ad5`

## Current phase

**K4-V1 selected upstream sync — implementation and live validation in progress.**

Current ticket: **K4-V1-04 — asymmetric Idle/Clock sizing + active-monitor API.**

K4-V1-01 through K4-V1-03 are live-validated. V1-04 slice 1 (collapsed Idle + active-monitor contract) has completed live-shell validation; slice 2 (expanded Clock measured sizing) is implemented and awaiting source/live validation.

K4-11 built-in lifecycle work remains deliberately paused while the approved v1.0 sync changes Player ambient activation and Idle/Clock geometry.

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

The editor/transcription stack remains excluded.

## K4-V1 implementation evidence

### K4-V1-01 — closed

Implemented persisted `spaceMode`, a narrow `HyprlandData.monitorHasFullscreen()` query, K4 Settings controls and mode-aware host `exclusiveZone` behavior.

Live validation passed:

- Reserve space reflows windows correctly at top and bottom;
- On top releases the exclusive zone and floats above windows at top and bottom;
- selection persists across Quickshell restart.

A fullscreen regression discovered during this slice was also fixed: Volume now promotes the K4 surface to Overlay while its HUD is active, so volume feedback remains visible above fullscreen clients.

### K4-V1-02 — closed

Implemented all four approved space modes:

```text
Reserve space
Away when fullscreen
On top
Hidden
```

Hidden/Away-fullscreen behavior now:

- resolves Away-when-fullscreen per monitor using the existing `HyprlandData` owner;
- keeps the layer surface stable and translates only the island drawing through the edge;
- leaves only a 4 px island-width reveal target, not a full-width edge catcher;
- delays normal Clock/Player hover opening by 500 ms while immediately holding existing hover/notification expiry;
- reveals automatically for ordinary plugin ownership such as Volume;
- keeps fullscreen-capable reveal/HUD presentation on Overlay;
- adds no new polling process or `hyprctl` service owner.

User source validation reached 127/127 at the completed Hidden tracer. Hidden runtime behavior passed, including the follow-up Volume rule: while withdrawn, a volume change reveals the HUD, repeated changes extend its existing HUD lifetime, and after the HUD ends the island returns directly to the edge unless the pointer or another plugin keeps it open.

### K4-V1-03 — closed

Player track-change peek follows the selected upstream v1.0 behavior while retaining ii-vynx ownership:

- MPRIS ownership remains in existing `K4Media`; no second watcher/service was added;
- track identity uses title + artist;
- metadata changes settle for 350 ms before comparison;
- first discovery, empty state and unchanged metadata do not trigger a peek;
- a genuine track change activates Player independently of transient `isPlaying` state;
- peek lasts 3200 ms and restarts on another genuine track change;
- `Peek Player on track change` is persisted in `Config.options.bar.k4`, defaults on, and is exposed in K4 Settings;
- disabling the Player plugin clears any transient peek state so re-enable cannot resurrect an old track card.

Live validation passed the complete matrix: initial discovery stayed quiet, genuine track changes peeked while Hidden, repeated changes restarted the lifetime, the preference disabled/re-enabled autonomous peek without breaking hover, Away-when-fullscreen worked over fullscreen clients, and disable/re-enable did not resurrect stale state. The source suite reached 129/129 and the crash/error grep returned no output.

### K4-V1-04 — implementation and validation in progress

#### Slice 1 — collapsed Idle + active-monitor contract

Implemented the approved collapsed Idle sizing and formalized the existing active-monitor seam:

- collapsed Idle measures media and right-side indicators independently instead of mirroring the larger side around the clock;
- the layout is a chained `left media -> center clock/workspaces -> right tray/recording` sequence;
- the center zone remains a fixed 46 px while total body width is the sum of actual left/right widths plus existing padding/gaps;
- existing workspace animation, media visualizer, tray and recording behavior remain owned by the same components;
- `IslandState.activeScreen` is explicitly documented and regression-tested as the stable plugin-facing active-island-monitor state;
- no duplicate monitor property, process or `hyprctl` owner is introduced.

Live validation is green. The supplied recording showed independent media-left and recording-right growth with no overlap, workspace/clock presentation remained intact, and the follow-up Hidden reveal/withdraw check passed. The broad runtime grep only surfaced pre-existing shared-widget, portal and MPRIS warnings; no warning pointed at the K4-V1-04 geometry path.

Focused/full source-suite confirmation for the current V1-04 branch still needs to be captured together with slice 2 rather than inferred from repository inspection.

#### Slice 2 — expanded Clock measured sizing

Source contract committed at `1dcad6529fc3a030836abb8e449428c00e1f59e9` and implementation committed at `6f0c2ad091eef2eeae57b8a368ac9634302031c6`.

The expanded Clock now follows the selected v1.0 sequential layout:

```text
date -> 24 px gap -> clock -> 24 px gap -> tray/recording
```

Implementation details:

- `K4ClockView` publishes measured left/date, center/time and right/contextual implicit widths;
- the stable Clock plugin receives those widths through declarative `Binding` objects;
- 96 px date and 92 px clock estimates remain first-frame fallbacks;
- the contextual right estimate accounts only for ii-vynx-owned tray/recording content and is capped at 480 px as the safety bound;
- the old symmetric `2 * max(left, right)` width reservation is removed;
- no upstream agent/game/plugin-store indicator ownership was imported;
- notification-strip height calculation remains unchanged.

Repository-side Standards + Spec review found no ownership/lifecycle expansion and no selected-v1 scope leak. Executable source checks and live-shell Clock validation remain pending on the target machine.

## Remaining K4-V1 plan

### K4-V1-04

Validate expanded Clock sizing and the complete V1-04 source suite. If green, close K4-V1-04.

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

Validate **K4-V1-04 slice 2**:

1. run `tests/k4-clock-sizing.test.js` plus the related core/tray/notification source contracts, then the full `tests/k4-*.test.js` suite;
2. deploy the branch to the live shell;
3. hover Clock with no tray/recording and verify the compact date/time layout has no overlap or excessive mirrored empty space;
4. add/remove tray items and verify only the contextual right side grows/shrinks;
5. start/stop recording, both with and without tray items, and verify the right zone remains chained after the clock without overlap;
6. show recent notifications and verify the notification strip still receives its existing vertical space;
7. verify supported screen alignments plus top/bottom placement keep the expanded Clock inside the screen;
8. repeat the runtime warning/crash grep and distinguish unrelated pre-existing shared-shell warnings from K4-specific regressions.
