# Battery Full Card Simplification

## Goal

Make the battery widget's full-card layout more minimal and visually consistent with its compact layout.

## Design

- Remove the full-card header, including its battery icon and device counter.
- Remove the aggregate charging footer, such as `1 charging`.
- Preserve each device's icon, name, stale state, and charging pill.
- Add a reusable `BatteryProgressRing.qml` component in the battery widget directory.
- Give the shared ring percentage, color, size, line-width, center-icon, center-text, and scale inputs. The component owns the `CircularProgress` and centered content but does not own device-state decisions.
- Replace the percentage text at the right of each device row with the shared ring.
- Center the rounded numeric percentage inside the ring without a `%` suffix.
- Color the ring and number with the existing device-level state color: tertiary while charging, error when low, and the normal foreground color otherwise.
- Replace the compact layout's inline `CircularProgress` and centered icon with the shared ring while preserving its current dimensions, colors, icon, and behavior.
- Keep state selection in `BatteryWidget.qml`, allowing a future third layout to reuse the visual component without coupling it to a device model.
- Reduce the full card's authored height to account for the removed header and footer while preserving current row height and spacing.

## Behavior and Scope

This is a presentation-only change. Device discovery, polling, click-to-refresh, compact-device selection, animations, and settings remain unchanged. The shared component is private to the battery widget module for now.

## Verification

- Confirm the QML loads without a battery-widget error.
- Confirm multiple device rows render without clipping.
- Confirm charging, low-battery, and normal colors still follow existing state logic.
- Confirm compact mode remains visually and behaviorally unchanged after adopting the shared ring.
