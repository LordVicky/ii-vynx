# k4 Dynamic Island Port — Status

Working branch: `agent/k4-bar-port`
Source spec: `docs/k4-bar-port/SPEC.md`
Tickets: `docs/k4-bar-port/TICKETS.md`
Pinned k4 source: `48993812c88f0af5d0c5345cd273467043b889f1`
Liquid Glass snapshot synchronized into this branch: `d79f6ec9a5af38850a79e84406705966bf850de1`

## Current phase

`K4-07 — Launcher and everyday utility plugins`: **validated and closed**.

Next ticket: `K4-08 — k4 settings inside the island`.

A known K4-04 workspace-animation defect is intentionally deferred: when the three-workspace viewport re-slices during some reverse transitions such as `3 → 2` and `3 → 1`, the active pill can still skip the expected shrink/grow animation. This is no longer a K4-04/K4-05/K4-06/K4-07 blocker and will be revisited when workspace support is expanded beyond the current three-slot behavior.

## K4-01 — validated and closed

Validated in the live shell on 2026-08-22:
- Bar Settings exposes Standard and k4 Dynamic Island variants.
- k4 Position and Alignment controls appear while Standard-only settings are hidden.
- k4 mode replaces the Standard bar rather than coexisting with it.
- switching back restores Standard and preserves independent settings.

## K4-02 — validated and closed

Implemented and validated:
- faithful black k4 surface, inverse wings, 34px collapsed reservation and reflected bottom geometry;
- delayed layer-surface shrink while island width/height animate immediately;
- island-only input mask;
- centered clock with symmetric side reservation;
- moving three-workspace viewport after workspace changes;
- live MPRIS artwork/visualizer lifecycle;
- recording indicator through existing ii `Persistent.states.screenRecord` state;
- top/bottom and lock/unlock ownership;
- k4 MIT attribution in `licenses/k4-NOTICE.txt`.

Runtime fixes included the cold/restarted MPRIS lifecycle and missing Persistent-state import. The three-workspace viewport and vertical gesture motion remain intentional pinned-k4 behavior.

## K4-03 — validated and closed

The deep host/state/plugin seam is in place:
- `IslandState.qml` owns requested/active screen routing, geometry publication, placement, gestures, and temporary suppression;
- `K4Plugin.qml` defines the enabled/active/priority/dimensions/view/focus/background/hover contract;
- the pinned upstream transient property name is `transitorio`; an attempted English `transient` property caused Quickshell exit 255 because `transient` is a reserved QML identifier;
- `K4PluginController.qml` owns highest-priority arbitration, idle fallback, transient preemption, monitor ownership and hover timers;
- expanded content is shown on only the active screen while other eligible screens retain the idle pill;
- the exclusive zone stays at the collapsed 34px height;
- suppression removes input/focus without moving surrounding windows;
- placement and `sacudida` / `empujon` / `tiron` gestures follow the pinned host contract;
- the temporary `k4barDebug` demo harness remains available for host regression validation.

K4-03 source tests passed 16/16 during its live gate. Multi-monitor compositor validation remains unavailable on the single-monitor test machine; the routing contract is source-covered.

## Liquid Glass synchronization state

Liquid Glass was synchronized into the k4 branch linearly rather than merged. The parity branch is pinned to Liquid Glass snapshot `d79f6ec9a5af38850a79e84406705966bf850de1`; later movement on `agent/liquid-glass-stage1` is not pulled implicitly.

The synchronized checkpoint includes the dashboard glass control surfaces, the local control-mask prototype tooling, and the `d79f6ec9` dashboard checkpoint where the shader prototype owns control optics. This synchronization does not restyle the k4 island; the spec still requires k4's own dark parity surface.

## K4-04 — validated and closed with deferred workspace-animation debt

Implemented and validated:
- `K4Media.qml` delegates to ii's live MPRIS players and only polls position while a player view is watching;
- `K4Audio.qml` delegates to ii Audio rather than creating another PipeWire owner;
- k4 owns the volume HUD while selected, while unrelated ii brightness/gamma/protection OSD behavior remains available;
- `K4Clock.qml` delegates to ii DateTime without another timer;
- `K4Workspaces.qml` delegates to Hyprland workspace state;
- Clock priority 50, Player priority 55 and Volume priority 40 follow pinned k4 activation ordering;
- Player has artwork, visualizer, timeline/seek, previous/play-pause/next and recording controls;
- pausing from an expanded Player keeps that hover session available so Resume does not disappear;
- the ii-vynx volume HUD is suppressed while k4 owns volume presentation;
- the future k4 audio-panel output button remains deliberately inert until K4-06 rather than opening an ii sidebar.

The K4-04 source suite and all functional media/clock/volume runtime checks passed. The reverse workspace animation defect remains known but is accepted as deferred debt to be revisited alongside expanded workspace support rather than blocking the current port sequence.

## K4-05 — validated and closed

### One notification daemon/server

`dots/.config/quickshell/ii/services/Notifications.qml` remains the **single Freedesktop notification server** used by the shell.

Disabling that `NotificationServer` in k4 mode would also disable K4 delivery, so the port deliberately reuses the ii-owned server and does not instantiate pinned k4's separate notification server. Repository searches found no shell-managed Dunst, Mako, SwayNC or Fnott instance requiring a second shutdown path.

### No duplicate legacy ii presentation

Two legacy-presentation paths are gated while k4 owns the bar:
1. `IllogicalImpulseFamily.qml` loads `NotificationPopup` only for Standard.
2. ii's shared `Notifications.qml` inhibits the legacy popup/timer/unread presentation path while `panelFamily === "ii" && bar.variant === "k4"` while continuing to track, persist and emit notifications for K4.

`K4Notifications.qml` also arms transient presentation only while k4 owns the variant and clears outstanding transient state when leaving k4, preventing stale replay after Standard → k4 switching.

### Toast, arbitration and fullscreen behavior

Validated behavior:
- one normal K4 toast with no duplicate ii side popup;
- pinned 5-second timeout;
- hover holds the timeout and moving away resumes it;
- newest notification remains in history after toast dismissal;
- priority-59 `transitorio` arbitration;
- explicit user-opened plugin preempts a normal transient without deleting history;
- when a real explicit plugin already owns the island, notification presentation routes to the separate band and does not steal ownership;
- the band is non-reserving and does not move surrounding windows;
- normal notification toast is visible over true fullscreen content;
- fullscreen application remains fullscreen and stationary;
- K4 host temporarily uses `WlrLayer.Overlay` only for notification presentation and returns to `WlrLayer.Top` afterward;
- the explicit-owner band always uses Overlay and `ExclusionMode.Ignore`.

### Recent notification history

`K4NotifStrip.qml` implements the pinned max-three recent strip:
- newest first;
- maximum three visible rows;
- `+N more` overflow indicator;
- image/app-icon/bell fallback;
- per-row activation/dismissal;
- clear-all.

Live validation passed under Clock:
- Clock expands vertically for history;
- newest-first ordering and overflow indicator are correct;
- individual dismissal works;
- Clear All works.

Live validation also passed under Player:
- notification history renders beneath the Player controls without overlap;
- play/pause and seek remain usable with history present.

The automated runtime harness reported `Player did not own island during history test`, but the actual Player history and controls were visibly present and functional. This is accepted as a harness false negative rather than a product failure.

### Variant-switch regression

Validated Standard ↔ k4 ownership switching:
- Standard receives only Standard notification presentation while selected;
- switching back to k4 does not resurrect stale toast state;
- new notifications after returning to k4 are again owned by K4.

## K4-05 source validation

Final local source gate on 2026-08-23:
- tests: 31
- pass: 31
- fail: 0
- cancelled/skipped/todo: 0

Coverage includes:
- single shared notification owner;
- inhibited legacy ii popup pipeline;
- adapter actions/history;
- toast transient priority and dismissal;
- explicit-owner band routing;
- fullscreen Overlay layering;
- recent max-three strip;
- Clock/Player dynamic strip-height contracts;
- existing K4-01 through K4-04 source regressions.

## K4-05 Standards + Spec review

### Standards

- No second notification server or external daemon was added.
- Notification global ownership remains in the existing ii service; K4 uses a narrow adapter.
- Legacy Standard presentation is gated rather than cloning/bypassing the underlying server.
- Toast arbitration remains inside the existing K4 plugin-controller boundary.
- The explicit-owner band is a separate non-reserving surface, preserving island host clipping/input/exclusive-zone geometry.
- Fullscreen z-order is expressed through layer-shell rather than compositor-specific window hacks.
- Clock/Player share one notification-strip implementation.
- No K4-06 panel behavior or ii-sidebar substitution was introduced during K4-05.

### Spec

K4-05 satisfies:
- explicit shared notification-owner decision;
- K4 toast/history adapter;
- island toast plugin;
- action/dismiss/history behavior;
- transient timing and hover hold;
- explicit-plugin preemption/band behavior;
- no competing `NotificationServer`;
- no duplicate Standard popup presentation in k4 mode;
- notification visibility over fullscreen content.

K4-05 is closed.

## K4-06 — validated and closed

Review point: `54493ba51ec8ad3f46c3440dbc7338e11a133c75`.

### Panel host and interaction

Implemented:
- priority-60 `K4PanelPlugin` with pinned 860px width and controls/detail heights;
- Controls, Notifications, Wi-Fi, Bluetooth and Sound routes inside the island;
- unconsumed island background taps open the K4 Controls panel on the requested screen;
- keyboard ownership, Escape/back behavior and hover-exit close semantics remain inside the plugin contract;
- notifications arriving while the panel is open close the panel and continue through normal K4 notification arbitration;
- the Player output-device action opens K4 Sound rather than an ii sidebar.

### Existing-service adapters

K4 panel integrations preserve the existing system owners:
- `K4Wifi.qml` is a presentation adapter over `Network.qml`; it does not create another `nmcli` process owner;
- `K4Bluetooth.qml` uses `Quickshell.Bluetooth` plus ii's `BluetoothStatus` ordering/status seam;
- `K4AudioDevices.qml` uses ii `Audio` device candidates and default-device setters instead of owning PipeWire;
- the Sound view scopes its `PwObjectTracker` to the visible Sound detail only;
- shortcut state is persisted through ii's XDG state directory and resolves shortcut targets through the live K4 plugin registry.

### Runtime startup regression and guard

The first full deployment exposed a QML type-resolution failure: several k4 singleton adapters used the Quickshell `Singleton` base without explicitly importing the parent `Quickshell` module. The failure first surfaced at `K4AudioDevices.qml` as `Singleton is not a type` and prevented the shell from loading.

The affected singleton files now explicitly import `Quickshell`, and `tests/k4-singleton-imports.test.js` guards the invariant for every k4 QML singleton so another masked instance cannot reappear one file at a time.

### Live validation — 2026-08-23

The complete K4-06 manual matrix passed in the live shell:
- island background interaction opens K4 Control Center inside the island and does not substitute the ii sidebar;
- Controls, Wi-Fi, Bluetooth, Sound and Notifications navigation works;
- existing ii corner-triggered sidebars remain independently usable;
- Sound shows physical outputs and inputs, supports default-device switching, volume, mute, selected-device markers and natural-level/+dB presentation;
- Wi-Fi toggle, scan, saved-network connection/forget, password flow and password-prompt Escape handling work;
- Bluetooth discovery and connect/disconnect behavior work and discovery is scoped to the open Bluetooth detail;
- media controls, notification actions/Clear All and shortcut-strip behavior work;
- Standard → k4 → Standard switching preserves the variant boundary;
- the synchronized Liquid Glass Standard dashboard continues to behave correctly after the K4-06 changes.

### Source coverage and execution status

Source coverage at the review point includes:
- `tests/k4-panel.test.js` for panel ownership/geometry, background taps, adapter ownership, Wi-Fi lifecycle/password behavior, composition, shortcuts, detail actions, notifications and Player-to-Sound navigation;
- `tests/k4-panel-parity.test.js` for natural audio levels, raw audio candidate discovery/view-scoped tracking and XDG shortcut persistence;
- `tests/k4-singleton-imports.test.js` for explicit Quickshell imports on k4 singleton types.

The connected GitHub environment has no CI status checks attached to the review commit and cannot execute the repository's local Node/QML test suite, so no new automated pass count is claimed here. The live shell acceptance matrix above is the runtime gate for closing K4-06.

## K4-06 Standards + Spec review

### Standards

No blocking findings at review point `54493ba51ec8ad3f46c3440dbc7338e11a133c75`:
- panel state and arbitration stay behind `K4PanelPlugin`/`K4Panel` rather than leaking into unrelated shell surfaces;
- adapters are narrow and preserve Network, Bluetooth and Audio ownership instead of creating competing service/process owners;
- expensive audio tracking is scoped to the Sound detail lifecycle;
- shortcut persistence uses the existing XDG state seam;
- Wi-Fi and Bluetooth scan/discovery lifetimes follow panel visibility rather than running permanently;
- ii sidebars remain separate surfaces instead of being embedded or repurposed for K4;
- the singleton startup regression is covered by a repository-wide k4 invariant test.

### Spec

K4-06 satisfies its ticket and the approved spec:
- k4's own control-center panel is preserved inside the island;
- Wi-Fi, Bluetooth, audio/device, media, notification and shortcut surfaces are present;
- existing ii service owners are reused through adapters where ownership is global;
- background taps open the K4 panel;
- existing ii corner sidebars remain independently available;
- the k4 parity surface remains k4-styled rather than adopting Material/Liquid Glass styling.

K4-06 is closed.

## K4-07 — validated and closed

Review point: `bae6ffdd52e663091cef642d0973225d45c462b7`.
Detailed review: `docs/k4-bar-port/K4-07-REVIEW.md`.

### Daily-driver utility surface

Implemented:
- Spotlight-style K4 Launcher using ii-vynx desktop application discovery/launch ownership;
- Apps utility grid over the same live plugin registry;
- Clipboard through ii `Cliphist`;
- on-demand Files search with open/reveal/copy-directory actions;
- Windows switcher through `HyprlandData`;
- demand-driven System metrics;
- Session/power through ii `Session`;
- shortcut viewer through existing Hyprland keybind state;
- Weather through ii weather state plus K4 forecast/search presentation;
- Tray through existing `TrayService` / SystemTray objects.

### Fullscreen launcher remediation

The first live pass showed that `dont_inhibit` correctly allowed the Super binding to fire, but K4 Launcher still remained invisible over a true fullscreen client because the island host stayed on `WlrLayer.Top`.

The final fix temporarily promotes the launcher-owned island to `WlrLayer.Overlay`, reusing the already validated notification fullscreen presentation seam. Normal idle/clock/player/panel owners remain on Top. The fullscreen application remains fullscreen while the launcher appears above it.

### Source validation — 2026-08-24

Final local source gate:
- tests: 102
- pass: 102
- fail: 0
- cancelled/skipped/todo: 0

The suite includes explicit coverage for shortcut inhibition bypass and launcher Overlay presentation, plus the full K4 regression suite accumulated through K4-07.

### Live validation — 2026-08-24

The focused K4-07 live matrix is fully passing. The last failing case—opening the K4 Launcher over a true fullscreen client with Super—now passes after the Overlay remediation.

Quickshell loads the deployed configuration successfully. No K4-07 QML load error is present in the supplied startup log.

### Standards + Spec review

No blocking findings at the fixed code review point:
- global desktop facilities keep one owner and K4 uses narrow adapters;
- demand-driven utilities do not add unnecessary persistent polling/process owners;
- Standard Overview and K4 Launcher are mutually exclusive at the family boundary;
- custom keybinds retain final override ownership;
- fullscreen visibility uses layer-shell rather than window hacks;
- no package-manager subsystem or Material/Liquid Glass restyle was introduced;
- source checks and real-shell compositor evidence satisfy the K4-07 acceptance gate.

K4-07 is closed.

## Deferred workspace item

Known and explicitly non-blocking:
- `3 → 2` and `3 → 1` can still skip the desired reverse pill shrink/grow animation when the current three-workspace viewport re-slices.

Do not spend additional parity-stage effort on this now. Reopen it when the workspace feature is expanded so the viewport/model and animation semantics can be redesigned together instead of layering another local workaround onto the three-slot implementation.

## Next action

Begin `K4-08 — k4 settings inside the island`.

The K4-08 boundary is already specified: add the K4 Settings plugin/view, expose plugin enable/disable/error state, keep top/bottom and alignment backed by `Config.options.bar.k4`, and only expose settings that have a live consuming behavior. Preserve the ii Bar Settings variant boundary rather than creating a second independent settings source.
