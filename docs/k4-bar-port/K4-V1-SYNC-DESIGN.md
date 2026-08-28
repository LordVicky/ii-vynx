# K4 v1.0 Selected Upstream Sync — Design

Status: approved for implementation

## Source anchors

- Existing port source pin: `k4ditano/k4@48993812c88f0af5d0c5345cd273467043b889f1` (2026-08-22).
- Reviewed release: `k4ditano/k4@adcf4216038f7881c4a589baafaaaec841377ad5` (`v1.0.0`, 2026-08-24).
- Delta inspected: 38 commits.
- This document is a **selected sync**, not a new full-parity target. Later upstream `main` commits are not implicitly in scope.

## Product decisions

Approved:

- **U1** bar space/overlay modes.
- **U2** per-monitor fullscreen detection.
- **U3** hidden-edge reveal interaction.
- **U4** Player track-change peek.
- **U6** compact asymmetric Idle/Clock sizing.
- **U17** active-island-monitor plugin API.
- **U19** review capture-only fixes and port only if they apply to the ii-vynx adapter.

Reviewed then withdrawn:

- **U12** lifecycle/extensibility ideas. The managed Loader/proxy experiment was subsequently reverted and is not part of the selected port. Upstream manual QObject lifetime remains rejected.

Rejected:

- **U5** Dual mode/dock.
- **U7-U9** HyprTheme wallpaper/video/palette stack.
- **U10-U11** plugin store/public ecosystem.
- **U13** standalone K4 self-update status.
- **U14** K4 coding-agent skill installer.
- **U15** live window thumbnails.
- **U16** generalized auxiliary-window API expansion.
- **U18** upstream translation-system changes.
- **U20** upstream installer/docs polish as runtime scope.

These are explicit product decisions. Rejected/withdrawn items are not deferred parity debt.

## Sequencing

The selected v1.0 behavior is independent of the withdrawn K4-11 lifecycle experiment. Built-ins remain directly/declaratively owned while the v1 host, Player and layout changes proceed.

## V1-A — bar space management (U1, U2, U3)

### Configuration

Extend `Config.options.bar.k4` with:

```qml
property string spaceMode: "reserve"
// "reserve" | "fullscreen" | "overlay" | "hidden"
```

Labels in K4 Settings:

- **Reserve space** — current behavior and default.
- **Away when fullscreen** — reserve normally; on a monitor whose active workspace has fullscreen content, resolve to Hidden for that monitor only.
- **On top** — never reserve compositor space; keep the island visible over windows.
- **Hidden** — never reserve compositor space; withdraw the idle island past the configured edge until it is needed.

Persistence stays in ii-vynx `Config`; do not add another K4 settings file.

### Fullscreen ownership

Do not copy upstream `services/Workspaces.qml` and do not add another `hyprctl` owner.

`services/HyprlandData.qml` already owns monitor/workspace snapshots and refreshes them from Hyprland events. Add one narrow query such as:

```qml
function monitorHasFullscreen(screenName) -> bool
```

It should resolve the monitor by connector name, find its active workspace, and return that workspace's fullscreen flag from the existing snapshot. If data is incomplete, fail open to `false` rather than hiding the bar unexpectedly.

The existing Hyprland raw-event refresh path must continue to refresh fullscreen state. Add a regression check specifically for `fullscreen` and `closewindow` responsiveness rather than a second polling loop.

### Per-screen effective mode

Each `K4Bar.qml` `PanelWindow` derives:

```text
effectiveMode =
  spaceMode == fullscreen && monitorHasFullscreen(screen)
    ? hidden
    : spaceMode
```

Then:

- `reserve` -> `exclusiveZone = K4Theme.baseHeight`
- `overlay` -> `exclusiveZone = 0`
- `hidden` -> `exclusiveZone = 0` plus withdrawal behavior

Expanded views continue to overlay windows; only the collapsed reservation policy changes.

### Hidden withdrawal

Hidden mode is host behavior, not plugin behavior.

Per screen, the host owns a `withdrawn` state:

- return immediately when the edge/island is being sought or a non-idle plugin has something to show;
- after the island is idle and not hovered, wait about 1600 ms before withdrawing;
- translate the island drawing beyond the configured top/bottom edge by its current height plus a small safety margin;
- animate both directions for about 360 ms with a non-overshooting curve (`OutCubic`), not the island's normal `OutBack` geometry animation.

Do not resize/unmap the layer surface per frame to hide it.

### Reveal edge and input mask

When Hidden is the effective mode, keep an invisible **4 px edge strip** aligned to the island width and current placement. It exists only to bring the island back.

The layer input mask must combine:

- the island input region when the island is visible/returning; and
- the edge strip whenever Hidden mode is active.

The strip must remain in the mask while the island animates back. This avoids the Qt/Wayland hover gap where the transformed island region is still off-screen and the underlying window captures the pointer.

The strip must not span the whole monitor edge; only the island-width region may capture the pointer.

`IslandState.suppressed` remains a stronger, separate mechanism for capture/system-dialog hiding: when suppressed, both island and reveal-strip input are removed.

### Reveal semantics

A plugin becoming active is already the K4 signal that there is something to show. Therefore notifications, volume HUD, capture confirmation, launcher/utilities and other explicit owners bring a Hidden bar back automatically without a new notification mechanism.

When Hidden and idle, brushing the reveal edge should bring back only the collapsed pill. Remaining at the edge for roughly 500 ms may then begin the normal hover expansion session. Preserve ordinary immediate hover behavior for non-Hidden modes.

## V1-B — Player track-change peek (U4)

Extend `Config.options.bar.k4` with:

```qml
property bool playerPeekOnTrackChange: true
```

Expose it under a Player section in the in-island K4 Settings view.

Use the existing `K4Media` MPRIS adapter. Do not add another MPRIS controller/service.

The Player built-in should gain an ambient `peekActive` state. Its active rule becomes conceptually:

```text
normal player hover OR peekActive
```

Track identity is based on user-visible metadata (title + artist), not only `xesam:trackid`, because some players omit or churn track IDs.

MPRIS metadata may arrive in pieces. Debounce/settle metadata for about 350 ms before comparing identities. Do not peek:

- for the first discovered track after shell startup/player discovery;
- when the new identity is empty;
- when the settled identity is unchanged;
- when the setting is disabled.

On a real track transition, keep the Player active for about 3200 ms. Because this is an ambient activation from idle, existing controller routing should place it on the focused monitor unless a screen was already explicitly requested.

Closing/Escape should end the peek, while normal hover semantics continue to work.

## V1-C — compact asymmetric Idle/Clock sizing (U6)

This is a layout change, not only a width-formula change.

### Idle pill

Current ii-vynx K4 Idle still reserves `max(left, right)` on **both** sides to keep the clock mathematically centered. Replace that with three sequential measured zones:

```text
left media zone | center clock/workspaces | right indicators
```

Each side consumes only its own measured width. Preserve the existing media, workspace-transition, tray and recording behavior.

Keep small fallback estimates for the first layout frame, but once delegates exist the measured widths are authoritative.

The accepted tradeoff matches upstream v1.0: the center clock may move slightly when a contextual indicator appears, in exchange for avoiding permanent doubled empty space.

### Clock hover view

Replace left/date + mathematically centered time + right/tray anchoring with a sequential measured layout:

```text
date | gap | clock | gap | tray/recording/indicator zone
```

`K4ClockView` should publish the measured left/center/right widths back to the stable Clock plugin object. The plugin computes island width from those measurements with conservative first-frame fallbacks and a reasonable cap on the contextual right side.

Notification-strip height behavior remains unchanged.

## V1-D — active monitor API (U17)

The port already has the needed behavior as `IslandState.activeScreen`, populated by the host/controller for every expanded global action.

Treat `IslandState.activeScreen` as a stable plugin-facing contract and add explicit regression coverage. Do not add a second monitor-routing service merely to copy upstream's Spanish `K4.Isla.pantalla` name.

## U12 lifecycle review — withdrawn

Upstream v1.0's lifecycle/extensibility work was reviewed, and both manual dynamic ownership and a port-specific managed Loader/proxy layer were explored.

The current decision is simpler:

```text
K4BuiltinPlugins -> directly owned K4FooPlugin {}
```

There is no persisted per-plugin disablement, lifecycle Error/Retry UI or `K4ManagedPlugin` Loader seam in the selected port.

Upstream's `Qt.createComponent()`, `createObject()` and manual `destroy()` implementation remains explicitly rejected because that ownership approach produced native QtQmlModels/QQmlIncubator failures on the target Quickshell runtime.

## U19 capture audit

The capture-specific v1.0 delta after the original pin is not a new capture behavior that applies to this port. The relevant upstream changes route structured failure reason/detail values through upstream's own Python capture/editor services and localize those messages before showing notifications. Editor-related changes remain outside scope.

Our `K4CapturePlugin` deliberately delegates capture/recording to existing ii-vynx owners and does not own upstream's Python capture/error-localization stack. Copying the U19 delta would duplicate responsibility without changing the approved user-facing capture behavior.

**Decision: no U19 runtime port is required.** Keep the existing K4-09 thin-adapter implementation. Hidden-mode work must still verify that capture confirmation brings the island back automatically because Capture is an active plugin.

## Non-goals for this sync

- no Dual/dock implementation;
- no wallpaper/video/palette ownership;
- no plugin store, external plugin registry or user plugin directories;
- no managed per-plugin Loader lifecycle or persisted plugin disabling;
- no live window thumbnails;
- no generalized `K4.Ventana` API expansion;
- no K4 self-updater;
- no upstream translation subsystem;
- no capture editor/transcription stack;
- no manual QObject plugin creation/destruction.

## Acceptance matrix

### Space modes

- Reserve remains the default and preserves current 34 px reservation.
- On top uses zero exclusive zone and tiled/maximized windows may occupy the bar's former strip while the island stays visible.
- Hidden uses zero exclusive zone, withdraws after idle delay, and returns on the island-width edge strip.
- Edge brush returns the pill without immediately expanding Clock/Player; dwelling opens normal hover behavior.
- Any explicit/ambient non-idle owner brings a hidden island back.
- Away when fullscreen resolves per monitor; fullscreen on one monitor must not hide another monitor's bar.
- top and bottom placement both work in all four modes.
- capture/system-dialog suppression still removes invisible input completely.

### Player peek

- first discovered track does not peek;
- a real track change peeks for roughly 3.2 s;
- title/artist arriving separately creates one peek, not two;
- disabling the setting prevents automatic peek;
- Escape ends an active peek;
- hidden mode returns automatically for the peek.

### Compact sizing

- Idle no longer mirrors the larger side into the opposite side;
- Clock view zones do not overlap as tray/recording indicators appear/disappear;
- notification strip still sizes correctly;
- pill/clock remain within screen bounds at supported alignments.

### Active monitor contract

- explicit opens still route to the requested monitor;
- ambient Player peek from idle uses the focused monitor;
- plugin-facing `IslandState.activeScreen` matches the expanded host screen.

## Review boundary

Review this selected sync against:

- original port behavior at the branch commit immediately before its first runtime slice;
- upstream `v1.0.0` only for U1-U4/U6/U17 semantics;
- this document's explicit reject/withdraw list;
- existing ii-vynx ownership rules and direct declarative built-in plugin ownership.
