# OpenRGB Icon Layout Design

## Goal

Add a third OpenRGB presentation that occupies only one circular action while
idle and expands into the Compact spindle controls on hover.

## Layout Identity

The persisted layout value is `icon`. OpenRGB layout cycling becomes:

```text
card → spindle → icon → card
```

The collapsed presentation uses the **Condensed** Widget Presentation Tier.
Its authored canvas is `72 × 72`, matching the Compact spindle height and
leaving one shared prominent-action control centered inside Condensed padding.

## Collapsed Action

Reuse the existing circular Power control rather than introducing a new icon
component or image asset. Preserve its diameter, accent/background states,
hover treatment, disabled state, and click behavior. Replace only its internal
`power_settings_new` glyph with the same `lightbulb` vector glyph used by the
OpenRGB card header.

Clicking the collapsed lightbulb toggles RGB power through
`OpenRgb.toggleLights()`. The button remains the leading power action while the
layout is expanded.

## Hover Expansion

Hovering anywhere over the collapsed widget expands it horizontally into the
existing Compact spindle presentation. Expansion keeps the `72`-pixel authored
height and uses the existing label-driven spindle width, clamped to `330–410`
pixels.

The expansion reveals the existing Profiles/Effects mode switch, Previous and
Next controls, selected name, and Apply action. These controls retain their
current staging and explicit-Apply behavior. The revealed content fades in as
the card width animates through the existing element-resize animation.

Leaving the complete expanded widget starts a short `180ms` collapse delay.
Re-entering before the timer fires cancels collapse. This prevents flicker while
the pointer crosses controls or the animated boundary. Pressed controls and an
active resize gesture keep the layout expanded until interaction ends.

The layout toggle appears in the expanded state using the existing hover-only
affordance. It does not occupy permanent space in the collapsed circle.

## Architecture

Keep `layoutMode` as the persisted mode and introduce a separate transient
`iconExpanded` state. Persistence never changes merely because the pointer
enters or leaves. Card geometry selects among three modes:

- `card`: unchanged Standard card dimensions and component.
- `spindle`: unchanged Compact dimensions and component.
- `icon`, collapsed: `72 × 72`, circular card, icon-only component.
- `icon`, expanded: label-driven Compact width, `72` height, spindle component
  with the lightbulb leading action.

Reuse the spindle selection and Apply components. Parameterize the prominent
Power control's glyph so spindle keeps `power_settings_new` while Icon uses
`lightbulb`. Avoid duplicating the complete spindle layout.

## Behavior and Compatibility

Profile/effect discovery, staged selection, explicit Apply, device-scoped
power, power restoration, wallpaper-derived colors, blur, scale persistence,
and card/spindle behavior remain unchanged. Hover expansion must not apply an
item, change the persisted layout, or toggle power.

## Verification

- Test layout parsing and the three-step cycle order.
- Test collapsed/expanded base dimensions and label-driven width bounds.
- Test that Icon uses `lightbulb` and still routes clicks to
  `OpenRgb.toggleLights()`.
- Test that hover changes only transient expansion state.
- Verify the `180ms` delayed collapse is cancelled on re-entry.
- Visually review collapse, expansion, interaction, and re-collapse at the
  current scale twice across a shell reload.
- Verify Card and Spindle layouts remain unchanged.
- Run all Node and Python tests, `git diff --check`, source/live parity, and
  inspect the desktop-shell log for OpenRGB errors.
