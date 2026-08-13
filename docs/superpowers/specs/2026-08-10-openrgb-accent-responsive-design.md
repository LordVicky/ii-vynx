# OpenRGB Accent and Responsive Spindle Design

## Goal

Make OpenRGB use the same wallpaper-derived accent hierarchy as the other ii-vynx widgets and remove the remaining wasted space from its spindle layout.

## Root Cause

OpenRGB currently colors its emphasized controls with `colPrimaryContainer` and `colOnPrimaryContainer`. Working widgets such as Calendar use the actual wallpaper-theme accent pair, `colPrimary` and `colOnPrimary`, for their prominent selected and action states. The darker container tones make OpenRGB appear disconnected from the active wallpaper palette even though its shared blurred surface is correct.

## Palette

Use the established theme hierarchy in both spindle and card layouts:

- Power, Apply, and the selected Profiles/Effects tab use `Appearance.colors.colPrimary` with `Appearance.colors.colOnPrimary`.
- Their hover states use `Appearance.colors.colPrimaryHover`.
- Previous and next controls are secondary actions and use `Appearance.colors.colSecondaryContainer`, `colSecondaryContainerHover`, and `colOnSecondaryContainer`.
- Disabled controls retain the shared surface/subtext tokens.
- Do not add OpenRGB-specific colors, extract a second palette, or alter `WidgetBlurBackground`.

## Responsive Spindle Geometry

Remove the `Apply` caption; the check icon is the complete Apply affordance. Keep its tooltip/accessibility meaning in code where supported.

Measure the staged profile/effect label with `TextMetrics`. Derive the spindle's unscaled width from that measurement, clamped between `330` and `410` pixels. Short ordinary names therefore produce the smallest card, while long names receive extra room without allowing the widget to grow indefinitely. Empty-state labels use the same measurement path.

Within the spindle:

- Power and Apply keep bounded circular footprints.
- The selector is the only flexible region.
- Outer RowLayout spacing is derived from available base width and clamped between `3` and `7` pixels.
- Selector arrow/name spacing is derived independently and clamped between `4` and `8` pixels.
- The current name continues to elide in the middle at the maximum width.
- Reduce spindle height after removing the Apply caption while preserving comfortable targets and the pill silhouette.

The vertical card remains `300 × 218`; only its color tokens change.

## Behavior and Scope

Profile/effect staging, explicit Apply activation, card/spindle switching, refresh discovery, scoped power, and persisted state remain unchanged. Modify only `OpenRgbWidget.qml` for production behavior; retain the existing shared blur and the already-migrated `0.8` OpenRGB blur setting.

## Verification

- Confirm primary actions visually match Calendar's wallpaper accent and secondary arrows remain quieter.
- Confirm Apply has no caption in spindle but remains labeled in card mode.
- Capture spindle screenshots with a short and a long installed name; verify width responds within `330–410`, no content clips, and gaps tighten at the minimum.
- Verify both card and spindle layouts after live deployment in two visual review passes.
- Run all existing JavaScript/Python tests, `git diff --check`, compare the source/live QML, and inspect Quickshell logs for OpenRGB-specific errors.
