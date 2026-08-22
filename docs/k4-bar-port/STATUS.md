# k4 Dynamic Island Port — Status

Working branch: `agent/k4-bar-port`
Source spec: `docs/k4-bar-port/SPEC.md`
Tickets: `docs/k4-bar-port/TICKETS.md`
Pinned k4 source: `48993812c88f0af5d0c5345cd273467043b889f1`
Current Liquid Glass base merge-base: `cf40e91bfdd542b01cf81e060c9c448766080464`

## Current phase

`K4-05 — Notifications and transient arbitration`: **implementation complete; final live validation pending**.

Do not begin `K4-06 — k4 control center/panel` until the consolidated K4-05 runtime gate passes.

One K4-04 validation item is intentionally carried into that final gate: the workspace-change idle animation should be retested once with the final K4-05 branch state.

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
- the parser failure was fixed across plugin, controller and demo contracts, then covered by regression tests;
- `K4PluginController.qml` owns highest-priority arbitration, idle fallback, transient preemption, monitor ownership and hover timers;
- expanded content is shown on only the active screen while other eligible screens retain the idle pill;
- the exclusive zone stays at the collapsed 34px height;
- suppression removes input/focus without moving surrounding windows;
- placement and `sacudida` / `empujon` / `tiron` gestures follow the pinned host contract;
- the temporary `k4barDebug` demo harness remains available for host regression validation.

The parser-fix live retest reached `INFO: Configuration Loaded` with no `modules/ii/k4bar` load error. Existing unrelated Quickshell warnings remain baseline noise unless they point at a changed K4 file or correlate with a failed behavior.

K4-03 source tests passed 16/16 during its live gate. Multi-monitor compositor validation remains unavailable on the single-monitor test machine; the routing contract is source-covered.

## Liquid Glass base state

The branch was previously merged with the newer Liquid Glass dashboard exclusion architecture rather than preserving the obsolete Standard-only dashboard reserve shim.

At the K4-05 checkpoint the branch compares against `agent/liquid-glass-stage1` as:
- behind: 0;
- merge-base: `cf40e91bfdd542b01cf81e060c9c448766080464`.

No base sync is required before the K4-05 final test.

## K4-04 — core media/clock/volume

Implementation is complete and source-reviewed:
- `K4Media.qml` delegates to ii's live MPRIS players and only polls position while a player view is watching;
- `K4Audio.qml` delegates to ii Audio rather than creating another PipeWire owner;
- k4 owns the volume HUD while selected, while unrelated ii brightness/gamma/protection OSD behavior remains available;
- `K4Clock.qml` delegates to ii DateTime without another timer;
- `K4Workspaces.qml` delegates to Hyprland workspace state;
- Clock priority 50, Player priority 55 and Volume priority 40 follow pinned k4 activation ordering;
- Player has artwork, visualizer, timeline/seek, previous/play-pause/next and recording controls;
- the future k4 audio-panel output button remains deliberately inert until K4-06 rather than opening an ii sidebar.

The remaining K4-04 validation debt is a workspace-change idle-animation retest. It is folded into the consolidated pre-K4-06 runtime gate.

## K4-05 — notification ownership decision

### One daemon/server

`dots/.config/quickshell/ii/services/Notifications.qml` remains the **single Freedesktop notification server** used by the shell.

This is deliberate. Disabling that `NotificationServer` in k4 mode would also disable K4 notification delivery. The port therefore does not instantiate pinned k4's separate `services/Notifs.qml` server; `K4Notifications.qml` is an adapter over ii's existing server/state.

Repository searches found no shell-managed Dunst, Mako, SwayNC or Fnott daemon launch/configuration that would form a second notification owner.

### No duplicate legacy ii presentation in k4 mode

Two independent legacy-presentation paths are gated:
1. `IllogicalImpulseFamily.qml` loads `NotificationPopup` only for the Standard bar variant.
2. ii's shared `Notifications.qml` marks the legacy popup pipeline inhibited while `panelFamily === "ii" && bar.variant === "k4"`; notifications are still tracked, persisted and emitted to the K4 adapter, but the old popup flag/timer/unread path is not armed.

`K4Notifications.qml` also arms K4 transients only while the k4 variant owns presentation. Leaving k4 dismisses any pending K4 toast, preventing a Standard notification from being replayed after a quick Standard → k4 switch.

### Toast and arbitration

Implemented:
- newest notification adapter model over `Notifications.list`;
- pinned 5-second toast timer;
- hover hold/resume;
- image → app icon → generic bell fallback;
- non-default action buttons delegated to ii's tracked notification actions;
- default body action when the live notification exposes one;
- close hides the transient while preserving notification history;
- priority-59 `transitorio` toast plugin;
- 440px toast with pinned 96/112px height split;
- pinned typography, icon fit, action-chip sizing/alignment and action hover accent;
- explicit non-transient plugin preemption through the existing K4-03 controller.

### Explicit-owner notification band

Pinned k4 does not steal the island when a real user-opened plugin already owns it. The port preserves that rule:
- idle/clock/player/volume are passive owners and may be replaced by the normal toast;
- an explicit plugin latches the new notification into a separate band for that toast's lifetime;
- closing the explicit plugin mid-toast does not jump the same notification from band to island;
- the band follows the active screen's published island geometry;
- the band uses `ExclusionMode.Ignore`, so it never reserves compositor space or changes the 34px bar exclusive zone;
- hover holds the shared toast timer, body click activates the notification, and close dismisses only the transient.

### Fullscreen guarantee

Pinned k4's generic `K4.Ventana` overlay surfaces use `WlrLayer.Overlay`, but its main island host normally uses the Top layer. A fullscreen surface may share/compete with Top ordering, so K4-05 explicitly hardens notification presentation:
- normal non-notification K4 host state stays `WlrLayer.Top`;
- while the toast plugin owns a screen, only that per-screen K4 host surface becomes `WlrLayer.Overlay`;
- the separate notification band always uses `WlrLayer.Overlay`;
- when the toast closes, the normal host returns to Top.

This is an intentional robustness extension to guarantee the user's required notification visibility over fullscreen applications without making the entire k4 bar permanently overlay fullscreen content.

### Recent notification history

`K4NotifStrip.qml` ports the pinned max-three recent strip:
- newest-first shared history;
- max three visible rows;
- notification count plus `+N more`;
- clear-all;
- image/app-icon/bell fallback;
- one-line normalized summary/body;
- per-row dismissal and activation.

Clock and Player now render this strip and reserve the pinned vertical amounts:
- Clock: `68 + stripHeight + 18` when history exists;
- Player: base `115/140 + stripHeight + 15` when history exists.

## K4-05 source-contract coverage

`tests/k4-notifications.test.js` covers:
- K4 adapter has no `NotificationServer`;
- ii service contains the single shared `NotificationServer`;
- legacy ii popup window and popup-state pipeline are inhibited during k4 ownership;
- priority-59 transient contract;
- toast content/actions/dismissal;
- passive-vs-explicit band routing;
- non-reserving band window;
- notification Overlay layer vs ordinary Top layer;
- max-three newest-first recent strip;
- Clock/Player dynamic strip-height formulas.

The source tests have been authored but are not marked executed by this status update because the GitHub connector environment does not provide a runnable checkout. They must be run in the final local gate.

## K4-05 Standards + Spec review

### Standards

- No second notification server or external daemon was added.
- Notification global ownership remains in the existing ii service; K4 uses a narrow adapter.
- Legacy Standard presentation is gated instead of cloning or bypassing the underlying server.
- Toast arbitration remains inside the existing plugin-controller boundary.
- The band is a separate non-reserving surface because extending the island host surface would change clipping/input/exclusive-zone geometry.
- Fullscreen z-order is controlled explicitly through layer-shell rather than compositor-specific window hacks.
- Clock/Player consume one shared notification-strip component rather than duplicating history-row implementations.
- No K4-06 panel behavior or ii-sidebar substitution was introduced.

### Spec

K4-05 implementation satisfies the ticket requirements in source:
- explicit shared notification-owner decision;
- K4 toast/history adapter;
- island toast plugin;
- action/dismiss/history behavior;
- transient timing and hover hold;
- explicit-plugin preemption/band behavior;
- no competing `NotificationServer`;
- no duplicate Standard popup presentation in k4 mode.

Runtime/compositor acceptance remains pending the consolidated manual gate, especially fullscreen Overlay behavior.

## Final gate before K4-06

Run one consolidated local/source + live-shell validation pass covering:
- all existing K4 source-contract tests including `k4-core-desktop.test.js` and `k4-notifications.test.js`;
- shell startup/load;
- Standard notification regression;
- k4 single-delivery notification arrival from idle;
- action/close/timeout/hover behavior;
- notification arrival while an explicit plugin owns the island;
- fullscreen normal toast and fullscreen explicit-owner band;
- recent strip under Clock and Player;
- Standard → k4 → Standard notification ownership switching;
- the deferred K4-04 workspace-change idle animation;
- existing media/volume/recording regressions.

Only after this gate passes should K4-05 be marked validated/closed and K4-06 begin.
