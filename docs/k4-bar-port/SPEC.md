# k4 Dynamic Island Bar Port — Selected-Scope Specification

Status: implemented and validated

## Source and review anchors

- Target repository: `LordVicky/ii-vynx`
- Working branch: `agent/k4-bar-port`
- Base branch: `dev`
- Upstream project: `k4ditano/k4`
- Original implementation reference: `48993812c88f0af5d0c5345cd273467043b889f1` (2026-08-22)
- Selected v1.0 reference: `adcf4216038f7881c4a589baafaaaec841377ad5` (`v1.0.0`, 2026-08-24)
- Selected-v1 design: `docs/k4-bar-port/K4-V1-SYNC-DESIGN.md`
- k4 license: MIT. Substantially adapted/copied source must retain attribution under the repository convention.

The existing Standard bar remains intact and is the default. Selecting K4 unloads Standard bar surfaces and loads the K4 island host instead. Switching variants preserves each variant's independent settings.

## Product boundary

Included K4 scope:

- edge-attached inverse-wing island host;
- top/bottom placement and 15/50/85 alignment;
- idle pill, workspace transition, media, Clock and Volume;
- notifications/transient arbitration and recent history;
- K4 Control Center;
- Launcher, Apps, Clipboard, Files, Windows, System, Session, Shortcuts, Weather and Tray;
- in-island K4 Settings;
- thin capture/record presentation over existing ii-vynx capture owners;
- lean monitor arrangement through existing Hyprland state and a narrow apply adapter;
- direct declarative built-in plugin registration and priority arbitration;
- selected K4 v1.0 space behavior, Player track-change peek, compact Idle/Clock sizing and active-monitor API.

Explicit exclusions include Ask/embedded AI, HyprTheme/wallpaper ownership, Terminal/SSH/Agents, Game/Digivice, editor/transcription tooling, Dual mode/dock, external plugin ecosystem, managed built-in lifecycle, K4 self-update, live window thumbnails, generalized auxiliary-window API expansion, upstream translation replacement, agent-skill installer and duplicated workspace-to-monitor routing.

## Architecture

`Config.options.bar.variant` is the sole top-level selector. `IllogicalImpulseFamily.qml` gives Standard or K4 exclusive bar ownership.

K4 persistence stays under `Config.options.bar.k4`:

```qml
property string position: "top"
property int alignment: 50
property string spaceMode: "reserve"
property bool playerPeekOnTrackChange: true
property bool trayInPill: false
property bool notificationsOnHover: true
property bool dismissNotificationsOnFocus: true
```

`K4Bar.qml` owns layer-shell hosting, top/bottom anchoring, reservation/overlay/hidden policy, inverse-wing geometry, input mask/reveal behavior, focus policy, active-screen selection, arbitration presentation, suppression and physical island gestures.

`IslandState.qml` is the plugin-facing host state and publishes hover/current occupant, requested/active screen, focused-screen fallback, placement, per-screen island rectangles, gestures and suppression state.

Built-ins are ordinary declaratively owned QML objects registered by `K4BuiltinPlugins.qml`. The controller arbitrates those stable objects; no manual or managed dynamic QObject lifetime system is part of the port.

K4 presentation reuses existing ii-vynx/Quickshell owners for MPRIS, Audio/PipeWire, notifications, Cliphist, networking/Bluetooth, desktop apps, Session, Hyprland state and capture/record facilities. No new daemon, persistent helper process, external dependency or competing owner is introduced.

## Selected v1.0 behavior

K4 supports four space modes:

1. Reserve space — reserve collapsed K4 height.
2. Away when fullscreen — Reserve normally; Hidden per fullscreen monitor.
3. On top — zero compositor reservation while visible.
4. Hidden — zero reservation and host-owned idle withdrawal/reveal.

Fullscreen detection is a narrow query over existing `HyprlandData`. Hidden uses host translation rather than per-frame layer resizing, an island-width 4 px reveal strip rather than a whole-edge catcher, and returns immediately for non-idle plugin activation.

Player track-change peek reuses `K4Media`, compares settled title + artist identity, ignores initial/empty/unchanged metadata and activates Player briefly for a real transition.

Idle and Clock use sequential measured left/center/right zones rather than mirrored maximum-side reservation. `IslandState.activeScreen` is the stable active-monitor contract.

## Capture and Displays

K4 Capture is a thin presentation/adapter over existing ii-vynx capture/record owners. The upstream editor/transcription/Python capture stack is excluded.

K4 Displays is monitor-layout only:

```text
K4 Displays UI
  -> existing HyprlandData monitor snapshot
  -> in-memory draft
  -> one-shot hyprctl eval apply
```

No workspace-routing ownership, generated compositor config or persistent helper process is added.

## Visual and input requirements

- retain K4's dark surface and visual language;
- preserve edge-attached inverse wings and reflected bottom geometry;
- alternate Standard-bar surface experiments are outside this port;
- highest-priority enabled active plugin wins;
- idle remains fallback;
- idle does not grab keyboard focus;
- focus/input policy remains host-controlled;
- Escape closes the active plugin after nested controls have first chance to consume it;
- invisible/suppressed UI must not eat clicks.

## Acceptance

The selected K4 port is complete when Standard remains default, Standard and K4 never simultaneously own the bar, K4 settings persist, selected utilities reuse existing service owners, all four space modes behave as specified, Player peek and asymmetric sizing behave correctly, active-screen routing is stable, Capture/Displays remain thin adapters, no rejected v1 feature or duplicate service owner is introduced, attribution is retained, and source/real-shell validation is accepted.

The requested manual matrix covering variant switching, placement/alignment, space modes, Hidden reveal, fullscreen behavior, notifications/Volume/capture while Hidden, Player peek, Idle/Clock combinations, active-screen routing, representative utilities and Displays was accepted before clean-history reconstruction.

## Delivery

Historical K4-01 through K4-10 remain completed milestones. The selected v1 sync through K4-V1-05 and K4-12 final selected-scope validation are accepted. K4-11 is withdrawn. The branch has been reconstructed directly on `dev`; a focused post-reconstruction smoke is the remaining merge-side confidence check.
