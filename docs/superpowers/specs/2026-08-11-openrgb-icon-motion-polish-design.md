# OpenRGB Icon Motion Polish Design

## Goal

Polish the OpenRGB Icon layout's hover transition so the lightbulb remains a
stable visual anchor while the widget opens and closes to its right. Eliminate
the overlapping controls and ghosted second lightbulb visible during collapse
in `recording_2026-08-11_09.30.22.mp4`.

## Motion Model

Use one persistent leading `PowerControl` for the entire Icon presentation.
Its position, size, glyph, opacity, styling, hover response, disabled state,
and click behavior remain unchanged throughout expansion and collapse.

Only the trailing panel and secondary controls transition:

- Expansion grows the card from the collapsed width to the calculated spindle
  width over the existing `300 ms` element-resize animation.
- Secondary controls remain hidden through the first `35%` of width expansion,
  then reveal until the live trailing viewport can contain the selector, row
  spacing, and Apply control. They combine a fade with an `8 px` scale-aware
  horizontal translation from left to right.
- Collapse reverses the staging: secondary controls fade and translate toward
  the anchor first, then the panel retracts from right to left.
- The left edge and the persistent lightbulb do not move during either
  direction.
- Re-entering during collapse reverses the current transition from its current
  visual state without flashing, remounting, or briefly showing two bulbs.

The existing `180 ms` pointer-exit delay remains unchanged. Pressed controls
and active resize interactions continue to defer collapse.

## Component Structure

Replace the mutually cross-fading Icon and spindle loaders with a single Icon
presentation composed of two stable regions:

1. A fixed-width leading region containing the persistent lightbulb
   `PowerControl`.
2. A trailing region containing the existing `SelectionBlock` and
   `ApplyControl`.

The trailing region is clipped to the animated card boundary. Expansion
progress is derived from the current animated width, normalized between the
collapsed and expanded widths. Trailing opacity maps that progress from `0` at
`35%` to `1` only when the live trailing viewport physically fits the selector,
row spacing, and Apply control, clamped outside that range; horizontal
translation maps from `-8 px` at opacity `0` to `0 px` at opacity `1`. Because
presentation is derived from live geometry, interrupted transitions remain
coherent. The regular Spindle layout continues to use its current complete row
and power glyph; Card layout remains unchanged.

The layout toggle remains unavailable while Icon is fully collapsed and fades
with the trailing controls while expanded. It must not create a separate hover
target outside the current card boundary.

## Timing and Easing

- Card width: existing `Appearance.animation.elementResize` timing and easing
  (`300 ms`).
- Trailing reveal: begins at `35%` expansion and completes only when the live
  viewport fits the complete trailing row. On collapse this reverses naturally,
  hiding controls before the row would become clipped.
- Translation: `-8 px` at fully hidden to `0 px` at fully revealed, multiplied
  by the widget scale.
- Hover-exit delay: unchanged at `180 ms`.

All animation objects continue to come from the existing Appearance animation
system so project-wide animation and reduced-motion behavior remain respected.
No independent timer is introduced for visual staging; reveal progress and
card geometry stay interruptible and reversible.

## Behavior and Compatibility

The polish changes presentation only. It must not alter:

- persisted `card`, `spindle`, or `icon` layout selection;
- profile/effect discovery or selection;
- explicit Apply behavior;
- OpenRGB power behavior;
- label-driven width calculation and its bounds;
- widget scaling, placement, blur, or adaptive colors;
- the current collapse-delay and active-interaction guards.

The persistent leading lightbulb remains the same power action before, during,
and after the transition.

## Verification

- Add source-contract coverage proving Icon uses one persistent leading power
  control rather than two cross-fading full-layout loaders.
- Verify the trailing controls own opacity/translation staging and are clipped
  during width changes.
- Run the focused OpenRGB layout tests, all Node tests, Python tests, and
  `git diff --check`.
- Visually verify expansion, collapse, rapid leave/re-entry reversal, control
  interaction, and resize interaction at the current widget scale.
- Confirm the lightbulb's on-screen center is unchanged throughout each Icon
  transition and no frame contains a duplicate or ghosted lightbulb.
- Confirm Card and Spindle layouts remain visually and behaviorally unchanged.
