# Fake Screen Corners Toggle

## Goal

Add a separate settings toggle that completely disables the shell's fake monitor-edge rounding without changing Hyprland window rounding or the existing Default/Sharp interface style.

## Behavior

- Add `appearance.fakeScreenRoundingEnabled`, defaulting to `true` for compatibility.
- Show an **Enable fake screen corners** switch beside the existing screen-corner mode controls.
- When disabled, unmap the four `quickshell:screenCorners` surfaces and disable the wrapped-frame presentation.
- Preserve `appearance.fakeScreenRounding` while disabled so enabling the switch restores the previous No, Yes, Not fullscreen, or Wrapped selection.
- Hide or disable wrapped-frame-only controls while the master switch is off.
- Do not modify `appearance.sharpMode`, `appearance.defaultBorderRadius`, `appearance.toggleWindowRounding`, or Hyprland's `decoration:rounding` value.

## Implementation

The persisted boolean belongs beside `fakeScreenRounding` in `Config.qml`. `QuickConfig.qml` owns the switch. `ScreenCorners.qml`, `WrappedFrame.qml`, and `IllogicalImpulseFamily.qml` gate their surfaces and layout behavior on the new boolean as well as the existing mode.

## Validation

Add a focused Node regression test covering persistence, settings wiring, screen-corner unmapping, and wrapped-frame suppression. Run that test before and after the implementation, then run the related K4 settings and fullscreen tests. After syncing the changed QML files to the live configuration, verify with `hyprctl layers -j` that `quickshell:screenCorners` disappears while the switch is off and that `decoration:rounding` remains unchanged.
