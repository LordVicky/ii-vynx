# Rounded charging bolt design

## Goal

Replace the charging ring's sharp, inconsistently filled font glyph with a
small solid bolt that remains legible at both battery-widget ring sizes.

## Scope

- Change only the charging indicator rendered by `BatteryProgressRing.qml`.
- Preserve the existing ring diameter, stroke width, percentage, colors,
  animations, and full/compact card layouts.
- Keep the charging indicator centered inside the ring.

## Visual design

Render the bolt as a compact custom vector path with rounded joins and caps.
The shape is fully filled and inherits `ringColor`, so it follows the same
normal, charging, low-battery, and high-battery color transitions as the ring.

The vector is sized relative to `ringSize` and centered within the component.
It must not touch the progress stroke or alter the ring's implicit dimensions.

## Component behavior

`BatteryProgressRing` retains its existing `charging` property. When charging,
the vector bolt replaces the normal center icon or percentage, matching the
current first-pass charging behavior. When not charging, existing center-icon
and center-text behavior remains unchanged.

The vector lives inside the reusable ring component; callers require no new
properties and both full and compact battery cards receive the same treatment.

## Verification

- Confirm the bolt is a filled vector using `ringColor`.
- Confirm rounded joins/caps are configured.
- Confirm the vector dimensions are derived from `ringSize`.
- Run the battery source-contract test and the complete JavaScript suite.
- Install the shared ring live and verify the installed file matches `dev`.
