# Fullscreen direct scanout for the K4 shell

## Problem

When a fullscreen game is active, the K4 bar and four fake screen-corner surfaces remain on the layer-shell overlay layer. Hyprland reports `solitaryBlockedBy: ["OVERLAYS"]`, does not enter direct scanout, and Bodycam renders at 60-70 FPS. Stopping Quickshell removes the overlays, enables direct scanout, and raises Bodycam to 90-100 FPS.

The screen-corner surfaces were previously kept mapped across fullscreen transitions because repeatedly destroying and recreating their `PanelWindow` surfaces could crash Quickshell. The fix must preserve that lifecycle behavior.

## Approved behavior

While a monitor has a fullscreen client:

- Keep the K4 bar and fake screen-corner `PanelWindow` objects alive.
- Hide the corner content and place the corner surfaces below the fullscreen client.
- Place the idle K4 bar below the fullscreen client so it cannot block solitary presentation or direct scanout.
- Promote the K4 bar back to the overlay layer when an explicit K4 view such as a notification, volume HUD, launcher, or another plugin is active. Direct scanout may pause while that UI is visible and resume after it closes.
- Do not change the user's K4 space-mode or screen-rounding settings.

The fullscreen edge-hover reveal is unavailable while the idle bar is below the game because it cannot receive pointer input through the fullscreen surface. Keyboard and event-driven K4 views remain available.

## Implementation

`ScreenCorners.qml` will retain its current `visible: roundingWindowEnabled` lifetime. Its layer will resolve per monitor: overlay during normal desktop use and top while that monitor is fullscreen. Existing fullscreen detection and content visibility remain unchanged.

`K4Bar.qml` will expose the per-monitor fullscreen state used by `effectiveSpaceMode`. When the configured mode is `fullscreen`, the bar is idle, and the monitor is fullscreen, the surface will use the top layer. When a non-idle plugin owns the island, it will use the overlay layer until the plugin closes. Other K4 space modes retain their existing behavior.

No service, process supervisor, game-specific rule, or persistent configuration option is added.

## Validation

Automated tests will assert that:

- Fake screen corners stay mapped but demote from overlay to top on fullscreen monitors.
- The K4 bar demotes only for an idle fullscreen surface.
- Explicit K4 plugin views still promote the bar to overlay.
- Existing K4 space-mode, notification, volume, launcher, and surface-lifecycle contracts continue to pass.

After deploying the two QML files to the live shell, restart `qs -c ii` and run Bodycam in the same borderless fullscreen scene. The runtime acceptance criteria are:

- `quickshell:screenCorners` and the idle `quickshell:k4bar` are absent from Hyprland's active overlay level while Bodycam is active.
- Hyprland reports Bodycam as solitary with no blocker and sets `directScanoutTo` to the Bodycam window.
- Bodycam returns to the observed 90-100 FPS range.
- Leaving fullscreen restores the normal K4 bar and corner presentation.

