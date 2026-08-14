# Apple Device Glyphs Design

## Goal

Give iPhone, Apple Watch, and AirPods battery entries recognizable Apple-device silhouettes without adding a model database or changing non-Apple devices.

## Design

- Add three small monochrome SVG assets: a modern iPhone with Dynamic Island, an Apple Watch with bands and crown, and paired AirPods.
- Select the asset from the existing iCloud `deviceClass`; specific model names do not affect selection.
- Keep the existing Material icon as a fallback for unknown Apple classes.
- Carry the optional custom icon through the existing battery model.
- Render it with `CustomIcon` in list rows and in the shared ring when the compact card is not charging.
- Color the glyph with the widget's existing adaptive/list or battery-level/compact color.

## Constraints

- No Apple logo, model catalog, new service, or dependency.
- Charging continues to replace the compact ring's center glyph with the existing bolt.
- Laptop and Bluetooth battery behavior remains unchanged.
