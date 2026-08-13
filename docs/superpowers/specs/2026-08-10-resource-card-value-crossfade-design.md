# Resource Card Value Crossfade

## Goal

Make live Resource Monitor values change smoothly without adding noticeable
rendering cost or distracting motion.

## Behavior

Each `StatCard` crossfades only its large value text when the displayed string
changes. CPU, RAM, Battery/Disk, and Network use the same behavior. Icons,
labels, card surfaces, and layout remain stationary.

The transition lasts approximately 130 ms and uses the existing appearance
animation easing. The outgoing value fades to transparent while the incoming
value fades to opaque. There is no translation, blur, scale, or per-digit
animation.

If values change faster than the transition completes, the component abandons
stale intermediate values and converges on the newest string. Initial creation
shows the current value immediately rather than fading in from an empty state.

## Architecture

Add a small reusable value-text component local to `ResourcesWidget.qml`. It
owns the displayed and pending strings plus the opacity transition. `StatCard`
uses this component in place of its current large `StyledText` while preserving
the existing typography and color.

## Verification

- Confirm all four cards use the animated value component.
- Confirm the initial value appears immediately.
- Confirm a changed value fades out and the newest value fades in.
- Confirm rapid changes cannot leave an outdated value displayed.
- Confirm Resource Monitor horizontal and vertical layouts remain unchanged.
- Run the focused automated test and Quickshell runtime validation.
