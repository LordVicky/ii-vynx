# OpenRGB Horizontal Widget Design

## Goal

Replace the OpenRGB widget's stacked card with a wide, single-line desktop control inspired by the approved reference and the media widget's spindle layout. Preserve all existing profile, effect, refresh, Apply, and scoped power behavior.

## Chosen Approach

Use one dedicated horizontal QML composition inside the existing `BackgroundWidgetCard`. This is more faithful and less complex than adding multiple responsive layouts or coupling OpenRGB to media-widget components. The widget will use a `760 × 118` unscaled canvas, the shared widget surface, and the existing desktop-widget scale control. The wider final width is required for the reference copy to remain legible at the user's configured live scale.

The OpenRGB component will not add translucency, tint, blur, borders, decorative glow, colored halo, or custom outer bloom. It will rely exclusively on `BackgroundWidgetCard` and the existing widget blur mechanism for its surface and depth treatment.

## Layout

The content is divided into five horizontal regions:

1. A circular power control with a small lower-right status dot.
2. OpenRGB identity: lightbulb icon, `OpenRGB`, and the live device count, followed by a thin divider.
3. The flexible selection area. A compact `Profiles`/`Effects` segmented switch sits above a row containing previous, staged-item name, and next controls. A status line beneath reports plugin/connection state and the currently applied item.
4. A circular check control with an `Apply` caption, followed by a thin divider.
5. A compact far-right power summary with a green or muted dot and `Lights on`/`Lights off`.

Spacing and typography follow the reference hierarchy without reproducing its oversized presentation dimensions. The selected item is the dominant label; `OpenRGB` is secondary; metadata, connection text, and captions are subdued. Long names elide rather than expanding the widget.

## Interaction and State

- Previous and next controls only stage a profile or effect.
- Apply activates the staged item and is disabled when no item exists or OpenRGB is busy.
- The power control keeps the existing scoped off/on behavior. Its status dot and far-right summary reflect `lightsEnabled`.
- The mode switch changes the collection shown by the selector without applying anything.
- Refresh remains available through the status/identity area as a compact hover affordance and continues to discover newly installed effects.
- Busy, unavailable, empty, and error states reuse existing backend state and adaptive colors.

## Scope

Modify only `OpenRgbWidget.qml` for the visual redesign. Do not change `OpenRgb.qml`, effect discovery, profile parsing, power targeting, configuration schema, `BackgroundWidgetCard`, `WidgetBlurBackground`, or other shared widget chrome.

## Verification

- Run the existing OpenRGB JavaScript and Python tests to ensure the untouched backend still passes.
- Run `git diff --check` and reload the live `ii` Quickshell configuration.
- Capture a fresh desktop screenshot and compare structure, alignment, hierarchy, proportions, and absence of border glow against the supplied reference.
- Make a first correction pass, capture a second screenshot, and perform a second comparison before completion.
- Check the Quickshell log for QML load, binding-loop, and runtime errors after each live reload.
