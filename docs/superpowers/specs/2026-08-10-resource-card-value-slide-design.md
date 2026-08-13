# Resource Card Value Slide

## Goal

Replace the Resource Monitor's fade-through transition with a clearer, snappy
vertical slide-and-fade for changing values.

## Behavior

When a card value changes, the outgoing value moves upward by 4 px while fading
out. The incoming value begins 4 px below its resting position and moves into
place while fading in. Both complete in approximately 140 ms using the existing
appearance easing language.

The two strings remain spatially separated during the transition so differing
glyphs do not create the doubled-text artifact seen in the original crossfade.
The component clips its animation to the value area so text never escapes into
the label or icon region.

CPU, RAM, Battery/Disk, and Network all use the same animation. Icons, labels,
cards, and layout stay stationary. Initial values appear immediately.

If another update arrives during an animation, only the newest pending string
is retained. After the active transition completes, one follow-up transition
runs when the pending value differs from the displayed value.

## Architecture

Update `CrossfadeValueText.qml` to use two clipped text layers with simultaneous
opacity and vertical-position animations. Rename the component to
`AnimatedValueText.qml` because it is no longer a pure crossfade, and update the
Resource widget reference accordingly.

## Verification

- Confirm outgoing and incoming strings have distinct vertical positions.
- Confirm the animation is clipped to the value area.
- Confirm initial and rapidly changing values converge correctly.
- Confirm the Resource widget loads without component diagnostics.
- Deploy the verified files to the live shell and restart its single instance.
