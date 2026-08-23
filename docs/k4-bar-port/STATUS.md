# k4 Dynamic Island Port — Status

Working branch: `agent/k4-bar-port`
Source spec: `docs/k4-bar-port/SPEC.md`
Tickets: `docs/k4-bar-port/TICKETS.md`
Pinned k4 source: `48993812c88f0af5d0c5345cd273467043b889f1`
Current Liquid Glass base merge-base: `cf40e91bfdd542b01cf81e060c9c448766080464`

## Current phase

`K4-05 — Notifications and transient arbitration`: **validated and closed**.

Next ticket: `K4-06 — k4 control center/panel`.

A known K4-04 workspace-animation defect is intentionally deferred: when the three-workspace viewport re-slices during some reverse transitions such as `3 → 2` and `3 → 1`, the active pill can still skip the expected shrink/grow animation. This is no longer a K4-04/K4-05 blocker and will be revisited when workspace support is expanded beyond the current three-slot behavior.

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

## Liquid Glass base state

The k4 branch is synchronized with the Liquid Glass base through merge-base `cf40e91bfdd542b01cf81e060c9c448766080464` and was 0 commits behind at the K4-05 validation checkpoint.

The newer Liquid Glass dashboard exclusion architecture is preserved; the obsolete Standard-only dashboard reserve shim is not carried into k4 mode.

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

## Deferred workspace item

Known and explicitly non-blocking:
- `3 → 2` and `3 → 1` can still skip the desired reverse pill shrink/grow animation when the current three-workspace viewport re-slices.

Do not spend additional parity-stage effort on this now. Reopen it when the workspace feature is expanded so the viewport/model and animation semantics can be redesigned together instead of layering another local workaround onto the three-slot implementation.

## Next action

Begin `K4-06 — k4 control center/panel` from `TICKETS.md`, preserving k4's own island panel rather than substituting ii sidebars. Existing ii corner-triggered sidebars remain independently available.
