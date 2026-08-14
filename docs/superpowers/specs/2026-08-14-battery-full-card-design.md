# Battery Full Card Simplification

## Goal

Make the battery widget's full-card layout more minimal and visually consistent with its compact layout.

## Design

- Remove the full-card header, including its battery icon and device counter.
- Remove the aggregate charging footer, such as `1 charging`.
- Preserve each device's icon, name, stale state, and charging pill.
- Replace the percentage text at the right of each device row with a small `CircularProgress` ring.
- Center the rounded numeric percentage inside the ring without a `%` suffix.
- Color the ring and number with the existing device-level state color: tertiary while charging, error when low, and the normal foreground color otherwise.
- Implement the ring directly in the list delegate. Do not refactor the compact layout or introduce a shared component.
- Reduce the full card's authored height to account for the removed header and footer while preserving current row height and spacing.

## Behavior and Scope

This is a presentation-only change. Device discovery, polling, click-to-refresh, compact-device selection, animations, and settings remain unchanged.

## Verification

- Confirm the QML loads without a battery-widget error.
- Confirm multiple device rows render without clipping.
- Confirm charging, low-battery, and normal colors still follow existing state logic.
- Confirm compact mode remains unchanged.
