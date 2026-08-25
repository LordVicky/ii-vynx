# K4 Dynamic Island Port — Tracer Tickets

Source spec: `docs/k4-bar-port/SPEC.md`
Selected v1 sync design: `docs/k4-bar-port/K4-V1-SYNC-DESIGN.md`
Working branch: `agent/k4-bar-port`

Each ticket must deliver an end-to-end behavior that can be source-checked, live-validated and reviewed independently. Preserve one-owner service boundaries and the stable-proxy/Loader lifecycle invariant.

## Historical milestones

### K4-01 — Variant ownership seam — CLOSED

Standard/K4 mutual exclusion, K4 config boundary and Settings variant selector.

### K4-02 — Island shell and idle pill — CLOSED

Inverse-wing surface, top/bottom geometry, collapsed pill, workspace/media/recording content and multi-monitor host baseline.

### K4-03 — Island state and plugin arbitration — CLOSED

IslandState, priority arbitration, transient preemption, focus/input policy, active-screen routing, placement, gestures and temporary suppression.

### K4-04 — Media/Clock/Volume — CLOSED

Adapters over existing MPRIS, Audio, DateTime and Hyprland owners with K4 Player/Clock/Volume presentation.

### K4-05 — Notifications — CLOSED

Single ii notification owner, K4 Toast/history, transient/band arbitration and fullscreen presentation.

### K4-06 — K4 Control Center — CLOSED

Panel, Wi-Fi, Bluetooth, Sound, media, notification and shortcut surfaces over existing service owners.

### K4-07 — Launcher and everyday utilities — CLOSED

Launcher/Apps, Clipboard, Files, Windows, System, Session, Shortcuts, Weather and Tray.

### K4-08 — In-island Settings — CLOSED

K4 Settings using `Config.options.bar.k4`, plugin status/enablement and only live-backed options.

### K4-09 — Thin capture/record utility — CLOSED

Capture/record presentation over existing ii-vynx capture owners, including island suppression. The K4 editor/transcription stack is explicitly excluded.

### K4-10 — Selected remaining bundled features — CLOSED

Lean Displays/monitor arrangement only. Ask, HyprTheme, Terminal, SSH, Agents, Game and Digivice were explicitly rejected. Displays must not own workspace-to-monitor routing.

## Selected K4 v1.0 sync

These tickets implement only the user-approved v1.0 delta from `48993812...` to `adcf4216...`.

### K4-V1-01 — Space-mode seam: Reserve + On top

**Goal:** prove compositor reservation can change without destabilizing the existing K4 host.

Deliver end-to-end:

- add `Config.options.bar.k4.spaceMode`, default `reserve`;
- expose the four approved choices in `K4Settings` and the in-island Settings UI, but this tracer must make at least Reserve and On top operational;
- add a narrow `HyprlandData.monitorHasFullscreen(screenName)` query using existing monitor/workspace snapshots; no new polling/service owner;
- derive per-screen effective mode in `K4Bar.qml`;
- Reserve keeps the existing collapsed exclusive zone;
- On top sets `exclusiveZone` to zero while preserving current visible island/input behavior;
- source tests guard config, Settings, fullscreen-query ownership and host exclusive-zone semantics.

**Acceptance:** Reserve is a no-regression default; On top releases the 34 px strip and the island floats over windows at both top and bottom placement; Standard variant remains unchanged.

**Non-goal:** do not implement Hidden withdrawal/reveal in this ticket.

### K4-V1-02 — Hidden reveal + Away when fullscreen

**Goal:** implement the complete host-level hiding behavior and the per-monitor fullscreen rule.

Deliver end-to-end:

- Hidden uses zero exclusive zone;
- idle withdrawal after about 1600 ms;
- top/bottom translation beyond the edge using a non-overshooting ~360 ms animation;
- island-width 4 px reveal strip;
- input mask combines the reveal strip with returning/visible island input and removes both during `IslandState.suppressed`;
- edge brush returns only the pill; roughly 500 ms dwell enters normal hover expansion;
- any non-idle plugin activation returns the island immediately;
- `fullscreen` mode resolves to Hidden only on screens reported fullscreen by the existing HyprlandData query;
- source tests guard that no whole-edge catcher, duplicate fullscreen poller or second workspace owner is introduced.

**Acceptance:** Hidden works top/bottom; notification, Volume, Capture and explicit utility activation reveal it; true fullscreen hides only the affected monitor; underlying window clicks are not stolen outside the island-width reveal zone.

### K4-V1-03 — Player track-change peek

**Goal:** let the Player surface a new track even when the bar is Hidden.

Deliver end-to-end:

- add `Config.options.bar.k4.playerPeekOnTrackChange`, default true;
- add Player setting in K4 Settings;
- settle title+artist metadata for about 350 ms before comparison;
- initial player discovery does not peek;
- unchanged/empty identities do not peek;
- a real transition activates Player for about 3200 ms;
- Escape/close ends peek;
- reuse `K4Media`; no new MPRIS owner;
- ambient peek from idle routes through existing focused-screen fallback.

**Acceptance:** one real track change produces one peek; split metadata does not double-trigger; disabling the setting suppresses it; Hidden returns for the peek.

### K4-V1-04 — Compact Idle/Clock sizing + active-monitor contract

**Goal:** adopt the v1.0 asymmetric layout improvement and formalize the already-existing active-monitor API.

Deliver end-to-end:

- restructure Idle into sequential left-media / center-clock-workspace / right-indicator zones;
- stop mirroring the wider side into the opposite side;
- use measured zone widths with conservative first-frame fallbacks;
- restructure Clock hover into date / time / contextual-right sequential measured zones;
- publish measured Clock zone widths to the stable Clock plugin object and derive island width from them;
- preserve notification-strip height behavior;
- add explicit source/runtime contract for `IslandState.activeScreen` as the plugin-facing active-monitor value.

**Acceptance:** contextual content no longer pays doubled width, zones do not overlap, supported alignment presets stay within screen bounds, explicit/ambient routing publishes the correct active screen.

### K4-V1-05 — Selected v1 Standards + Spec review

**Goal:** close the approved upstream sync by evidence.

Review fixed branch point against:

- `docs/k4-bar-port/K4-V1-SYNC-DESIGN.md`;
- `docs/k4-bar-port/SPEC.md`;
- upstream `v1.0.0` only for U1-U4/U6/U17 behavior;
- explicit reject list.

Checks:

- source regression suite;
- real-shell top/bottom space-mode matrix;
- fullscreen behavior;
- Hidden edge/input behavior;
- Player peek;
- compact sizing combinations;
- no rejected Dual/HyprTheme/Tienda/window-thumbnail/API-expansion code;
- no new desktop service owner/dependency.

## K4-11 — Built-in plugin lifecycle/extensibility

**Status:** in progress, temporarily paused for K4-V1 selected sync.

Accepted architecture:

```text
stable K4ManagedPlugin proxy -> declarative Loader -> implementation
```

Already live-validated:

- Loader probe stress;
- Displays disable/re-enable/persisted boot/stress/shutdown;
- Displays load-failure isolation and Retry;
- Keys/Shortcuts managed lifecycle and failure/recovery.

Committed but not yet live-validated:

- low-coupling System/Windows/Session proxy batch.

Resume after K4-V1-05. Continue migrating built-ins in small risk-ordered slices. Keep Volume, Clock, Player, Toast and other ambient/cross-plugin owners static until ordinary utilities demonstrate the seam sufficiently.

K4-11 explicitly excludes external/user plugin directories, plugin store/registry, manifests/permissions, publishing/install/update/remove tooling and upstream manual QObject lifetime.

## K4-12 — Final selected-scope, performance, Standards + Spec review

**Goal:** finish the entire port by evidence rather than upstream feature count.

Deliver:

- selected-scope review against `SPEC.md`;
- relevant repository source checks;
- real-shell manual matrix;
- multi-monitor QA when hardware is available, including Displays relative placement and K4 per-monitor fullscreen hiding;
- resource/performance inspection for idle/expanded/Hidden states;
- review duplicate polling/process ownership;
- licensing/attribution audit;
- Standards review and Spec review as independent axes;
- document intentional divergences and remaining deferred debt.

## Dependency graph

Historical K4-01 -> ... -> K4-10 are closed.

Current path:

`K4-11 accepted lifecycle foundation -> K4-V1-01 -> K4-V1-02 -> K4-V1-03 -> K4-V1-04 -> K4-V1-05 -> resume K4-11 -> K4-12`

The K4-V1 tickets may reuse the already accepted lifecycle foundation, but they must not depend on unfinished low-coupling proxy migrations.
