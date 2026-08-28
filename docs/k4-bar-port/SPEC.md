# k4 Dynamic Island Bar Port — Selected-Scope Specification

Status: approved for implementation

## Source and review anchors

- Target repository: `LordVicky/ii-vynx`
- Working branch: `agent/k4-bar-port`
- Base branch: `agent/liquid-glass-stage1`
- Upstream project: `k4ditano/k4`
- Original implementation reference: `48993812c88f0af5d0c5345cd273467043b889f1` (2026-08-22)
- Selected v1.0 reference: `adcf4216038f7881c4a589baafaaaec841377ad5` (`v1.0.0`, 2026-08-24)
- Selected-v1 design: `docs/k4-bar-port/K4-V1-SYNC-DESIGN.md`
- k4 license: MIT. Substantially adapted/copied source must retain attribution under the repository convention.

The v1.0 tag is **not** a new full-parity target. Only explicitly approved v1.0 behaviors are part of this port.

## Goal

Provide the useful K4 Dynamic Island experience as a second, mutually exclusive ii-vynx bar implementation while preserving ii-vynx ownership of desktop services and rejecting upstream features that duplicate shell responsibilities or create unnecessary application/service bloat.

The existing Standard bar remains intact and is the default. Selecting K4 unloads Standard bar surfaces and loads the K4 island host instead. Switching variants preserves each variant's independent settings.

## Product boundary

### Included K4 experience

The selected K4 scope includes:

- edge-attached inverse-wing island host;
- top/bottom placement and left/center/right alignment presets;
- idle pill, workspace transition, media, Clock and Volume behavior;
- notifications/transient arbitration and recent history;
- K4 Control Center;
- Launcher, Apps, Clipboard, Files, Windows, System, Session, Shortcuts, Weather and Tray utilities;
- in-island K4 Settings;
- thin capture/record presentation over existing ii-vynx capture owners;
- lean monitor arrangement through existing Hyprland state and a narrow apply adapter;
- direct declarative built-in plugin registration and priority arbitration;
- selected K4 v1.0 bar-space behavior, Player track-change peek, compact Idle/Clock sizing and active-monitor API.

### Explicit exclusions

The following are product decisions, not deferred parity debt:

- Ask/embedded AI assistant;
- HyprTheme, wallpaper manager, animated wallpaper and wallpaper-derived palette ownership;
- Terminal, SSH and Agents applications;
- Game/Mazmorra and Digivice;
- K4's non-linear video editor, transcription and editor toolchain;
- Dual mode / transforming bottom dock;
- external/user plugin directories, plugin store/registry, publishing workflow, install/update/remove tooling and permission-manifest ecosystem;
- persisted per-plugin enable/disable UI and managed Loader lifecycle infrastructure;
- K4 standalone self-updater/version checker;
- live window-thumbnail API;
- generalized K4 auxiliary-window API expansion not required by an approved feature;
- upstream translation subsystem replacement;
- K4 agent-skill installer;
- duplicated workspace-to-monitor routing in Displays.

## Architecture principles

### 1. Variant ownership

`Config.options.bar.variant` is the sole top-level selector:

```qml
property string variant: "standard" // "standard" | "k4"
```

`IllogicalImpulseFamily.qml` owns mutual exclusion:

- Standard horizontal/vertical bar surfaces and Standard-only helper glass surfaces load only for `variant === "standard"`;
- the K4 island host loads only for `variant === "k4"`;
- unrelated ii-vynx modules remain available unless a demonstrated ownership conflict requires gating.

### 2. K4 persistence

K4 settings remain under `Config.options.bar.k4`; no second K4 settings file is introduced.

Current/approved host settings include:

```qml
property string position: "top"       // "top" | "bottom"
property int alignment: 50             // 15 | 50 | 85
property string spaceMode: "reserve"  // reserve | fullscreen | overlay | hidden
property bool playerPeekOnTrackChange: true
property bool trayInPill: false
property bool notificationsOnHover: true
property bool dismissNotificationsOnFocus: true
```

Add settings only with the behavior that consumes them.

### 3. Island host is the deep module

`modules/ii/k4bar/K4Bar.qml` owns:

- one layer-shell `PanelWindow` per eligible screen;
- top/bottom anchoring;
- per-screen reservation/overlay/hidden policy;
- inverse-wing silhouette and internal geometry animation;
- surface growth/shrink policy;
- per-screen input mask and Hidden reveal edge;
- keyboard focus policy;
- active-screen selection;
- active-plugin arbitration presentation;
- geometry publication;
- temporary suppression for capture/system dialogs;
- physical island gestures.

Individual plugins must not independently manipulate compositor reservation or reproduce host-level hiding behavior.

### 4. Island state

`IslandState.qml` is the shell-wide K4 host state and plugin-facing contract. It owns/publishes:

- hover state;
- current occupant/open state;
- requested and active screen;
- focused-screen fallback;
- base and temporary placement;
- island rectangles per screen;
- gesture requests/cooldown;
- temporary suppression/system-dialog state.

`IslandState.activeScreen` is the stable active-monitor API corresponding to approved v1.0 U17 behavior.

### 5. Plugin arbitration and ownership

K4 keeps a plugin interface for activation, priority, dimensions, view, focus, hover/background policy, transient behavior and open/close actions.

Built-ins are ordinary declaratively owned QML objects registered by `K4BuiltinPlugins.qml`:

```text
K4BuiltinPlugins -> K4FooPlugin {}
```

Required invariants:

- the controller arbitrates the stable directly owned built-in objects;
- `enabled` remains an internal arbitration field, not a persisted per-plugin user setting;
- the port does not add a dynamic Loader/proxy lifecycle for built-ins;
- no K4 plugin-lifetime path uses `Qt.createComponent()`, `createObject()` or manual `.destroy()`;
- no external plugin ecosystem is introduced implicitly through internal plugin infrastructure.

The previously explored managed Loader lifecycle was withdrawn after proving the mechanism because it was not required for the requested port and added maintenance cost without meaningful user-facing benefit. The earlier manual QObject ownership experiment remains rejected because it crashed the target Qt/Quickshell runtime.

### 6. One owner per desktop facility

K4 presentation must reuse existing ii-vynx/Quickshell owners for global facilities wherever they already exist.

Examples:

- Media -> existing live MPRIS state;
- Audio -> ii Audio/PipeWire owner;
- Notifications -> ii notification server/state;
- Clipboard -> ii Cliphist owner;
- networking/Bluetooth -> existing ii/Quickshell ownership;
- applications -> existing desktop-app discovery;
- session/power -> existing ii Session;
- monitor/workspace snapshots -> `HyprlandData` / Quickshell Hyprland state;
- capture/record -> existing ii-vynx capture/record scripts and state.

No new daemon, persistent helper process, external dependency or competing service owner may be added without explicit approval.

## Selected v1.0 behavior

### Space modes

K4 exposes four host modes:

1. **Reserve space** (`reserve`) — current/default behavior; reserve collapsed K4 height.
2. **Away when fullscreen** (`fullscreen`) — reserve normally, but resolve to Hidden only on a monitor whose active workspace has fullscreen content.
3. **On top** (`overlay`) — reserve zero compositor space while keeping the island visible.
4. **Hidden** (`hidden`) — reserve zero space and withdraw the idle island beyond its configured top/bottom edge until it is needed.

Fullscreen detection must be a narrow query over existing `HyprlandData` state. Do not create a second workspace/monitor service or polling loop.

Hidden behavior belongs to the host:

- withdraw only after an idle delay;
- animate by translating island drawing, not by resizing the layer surface per frame;
- use a non-overshooting return/withdraw curve;
- keep a 4 px invisible reveal strip aligned to the island width, not the full monitor edge;
- keep the strip in the input mask while the island returns so transformed-input lag cannot leak pointer ownership to the underlying window;
- temporary capture/system-dialog suppression is stronger than Hidden and removes both island and reveal-strip input.

A non-idle plugin becoming active is already the signal that there is something to show, so notifications, Volume, capture confirmation and explicitly opened utilities automatically bring a Hidden island back.

When idle and Hidden, brushing the reveal edge brings back the collapsed pill first; dwelling around 500 ms may then enter normal hover expansion.

### Player track-change peek

The Player may briefly activate when a real track changes, controlled by `playerPeekOnTrackChange`.

Requirements:

- use the existing `K4Media` MPRIS adapter;
- compare settled user-visible track identity (title + artist);
- allow about 350 ms for split metadata updates to settle;
- do not peek on initial player discovery, empty identity or unchanged identity;
- on a real change, keep Player active for about 3200 ms;
- Escape/close ends the peek;
- ambient peek from idle routes to the focused screen through existing controller behavior;
- Hidden mode must return automatically for a Player peek.

### Compact asymmetric Idle/Clock sizing

The old symmetric rule that mirrors the wider side around the clock is no longer the selected target.

Idle becomes three sequential measured zones:

```text
left media | center clock/workspaces | right indicators
```

Clock hover becomes:

```text
date | gap | time | gap | tray/recording/context
```

Each side consumes its own measured width. Conservative first-frame estimates are allowed; once views are laid out, measured widths are authoritative. The accepted tradeoff is a small center shift when contextual content appears in exchange for avoiding doubled empty reservation and overlap pressure.

Notification-strip height behavior remains unchanged.

## Capture scope

K4 Capture remains a thin presentation/adapter over existing ii-vynx capture and recording owners.

The v1.0 capture-only audit found upstream changes for structured/localized failure reason plumbing in K4's Python capture/editor stack. They do not apply to this ownership model and require no runtime port.

The editor, transcription, camera/editor timeline and upstream Python capture stack remain out of scope.

## Displays scope

K4 Displays is monitor-layout only:

```text
K4 Displays UI
  -> existing HyprlandData monitor snapshot
  -> in-memory draft
  -> one-shot hyprctl eval apply
```

No workspace-to-monitor assignment, workspace rules, workspace moves, generated Hyprland config or persistent helper process may be added. ii-vynx's existing dynamic workspace system remains the sole workspace behavior owner.

## Visual requirements

- retain K4's dark surface and visual language for this port;
- preserve edge-attached inverse wings and reflected bottom geometry;
- do not restyle K4 with Material or Liquid Glass during selected-scope completion;
- Standard Liquid Glass work remains independent.

## Focus/input/arbitration requirements

- highest-priority enabled active plugin wins;
- idle remains fallback;
- explicit non-transient views dismiss/preempt lower transient presentation as already defined;
- expanded global action appears on the requested/focused active screen while other monitors retain idle behavior;
- idle does not grab keyboard focus;
- text-entry/exclusive/on-demand/on-hover focus policies remain host-controlled;
- Escape closes the active plugin after nested controls get first chance to consume it;
- invisible/suppressed UI must not eat clicks.

## Acceptance criteria

The selected K4 port is complete when:

1. Standard remains default and regression-equivalent to the base branch at the variant boundary.
2. Standard and K4 never simultaneously own the bar surface.
3. K4 top/bottom placement and 15/50/85 alignment persist independently.
4. K4 silhouette/animations match the selected K4 visual language.
5. Idle/media/workspace/notification/control-center and approved daily-driver utilities work through existing service owners.
6. Reserve/On top/Hidden/Away-when-fullscreen behave as specified, including per-monitor fullscreen resolution.
7. Hidden edge reveal does not capture the whole monitor edge and does not leak clicks during return animation.
8. Player track changes create at most one configured peek and initial discovery does not peek.
9. Idle and Clock use asymmetric measured zones without content overlap.
10. `IslandState.activeScreen` correctly identifies the expanded host monitor.
11. Capture remains a thin adapter; no editor/transcription stack is introduced.
12. Displays remains monitor-only and does not duplicate dynamic workspace routing.
13. Built-ins remain directly/declaratively owned; no manual or managed dynamic plugin lifetime system is required for completion.
14. No rejected v1.0 feature appears implicitly through infrastructure work.
15. No duplicate desktop service owner or unapproved external dependency is introduced.
16. K4-derived code remains attributed under repository convention.
17. Relevant source checks pass and compositor/hardware behavior has explicit real-shell validation.
18. Final review is performed independently against repository standards and this specification.

## Manual validation matrix

At minimum cover:

- Standard -> K4 -> Standard ownership/config preservation;
- K4 top and bottom, each alignment preset;
- Reserve and On top with tiled/maximized windows;
- Hidden withdraw, edge brush, dwell expansion and explicit-plugin reveal;
- Away when fullscreen on real fullscreen content; multi-monitor behavior when hardware is available;
- notification, Volume and capture confirmation while Hidden;
- Player initial discovery vs real track change, including split MPRIS metadata;
- Idle/Clock with media, tray, recording and notification history combinations;
- active/requested screen routing;
- representative utility open/close behavior after direct plugin ownership restoration;
- Displays Refresh/Apply and absence of workspace-routing UI.

## Delivery strategy

Continue using tracer bullets. Historical K4-01 through K4-10 remain completed milestones. The selected v1.0 sync is implemented as its own ticket sequence; K4-11 is withdrawn and K4-12 remains the final selected-scope/performance/review gate.
