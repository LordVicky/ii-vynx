# K4 Dynamic Island Port — Tracer Tickets

Source spec: `docs/k4-bar-port/SPEC.md`
Selected v1 sync design: `docs/k4-bar-port/K4-V1-SYNC-DESIGN.md`
Working branch: `agent/k4-bar-port`

Each ticket must deliver an end-to-end behavior that can be source-checked, live-validated and reviewed independently. Preserve one-owner service boundaries and direct declarative ownership of built-in K4 plugins.

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
K4 Settings using `Config.options.bar.k4` and only live-backed options.

### K4-09 — Thin capture/record utility — CLOSED
Capture/record presentation over existing ii-vynx capture owners, including island suppression. The K4 editor/transcription stack is explicitly excluded.

### K4-10 — Selected remaining bundled features — CLOSED
Lean Displays/monitor arrangement only. Ask, HyprTheme, Terminal, SSH, Agents, Game and Digivice were explicitly rejected. Displays must not own workspace-to-monitor routing.

## Selected K4 v1.0 sync

Only the approved v1.0 delta from `48993812...` to `adcf4216...` is part of the port.

### K4-V1-01 — Space-mode seam — CLOSED
Reserve and On top behavior plus the existing-state fullscreen query seam.

### K4-V1-02 — Hidden reveal + Away when fullscreen — CLOSED
Host-owned withdrawal/reveal behavior and per-monitor fullscreen resolution.

### K4-V1-03 — Player track-change peek — CLOSED
Settled metadata comparison, initial-discovery suppression and configured transient Player activation.

### K4-V1-04 — Compact Idle/Clock sizing + active-monitor contract — CLOSED
Asymmetric measured zones and stable `IslandState.activeScreen` contract.

### K4-V1-05 — Selected v1 Standards + Spec review — CLOSED
The requested selected-v1 source/live validation bundle and real-shell matrix were accepted before clean-history reconstruction.

## K4-11 — Built-in plugin lifecycle/extensibility — WITHDRAWN

The managed built-in lifecycle experiment was reverted and is not part of the selected K4 port.

Current architecture keeps ordinary built-ins directly/declaratively owned by `K4BuiltinPlugins.qml`. The port does not provide persisted per-plugin disabling, Loader-backed lifecycle proxies, lifecycle Error/Retry UI, fault-injection IPC or lifecycle probe infrastructure.

The earlier manual `Qt.createComponent()` / `createObject()` / `.destroy()` approach also remains rejected because it caused native Qt/QML lifetime failures. Withdrawal means **static declarative ownership**, not a return to manual QObject lifetime.

## K4-12 — Final selected-scope review — ACCEPTED

The selected scope, ownership model, performance/resource boundary, attribution and requested real-shell matrix were accepted before the branch was reconstructed directly on `dev`.

The rewritten branch requires a focused post-reconstruction source/runtime smoke before merge because its ancestry and unrelated base code changed while the selected K4 behavior was preserved.

## Dependency graph

Historical K4-01 -> ... -> K4-10 are closed.

Selected-v1 path:

`K4-V1-01 -> K4-V1-02 -> K4-V1-03 -> K4-V1-04 -> K4-V1-05 -> K4-12`

K4-11 is withdrawn and is not a dependency or completion gate.
