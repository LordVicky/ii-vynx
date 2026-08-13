# Legacy Widget Final-Size Rendering Design

## Goal

Eliminate text pixelation in the remaining older resizable desktop widgets by removing parent scene-graph scaling and rendering all content at its final on-screen size.

## Scope

Included widgets:

- Notes
- Resources
- User Card
- Weather
- Clock
- Image Converter

The custom Media widget is explicitly excluded. Calendar and World Clock already size themselves without a parent `scale` transform and are also excluded.

## Architecture

Each included widget retains its persisted `widgetScale` and drag-to-resize behavior. The widget root and former scale-wrapper are sized directly to their final dimensions. The wrapper no longer has `transformOrigin` or `scale`.

Every authored visual metric is multiplied explicitly by `widgetScale`:

- font pixel sizes and icon sizes;
- fixed widths, heights, and implicit sizes;
- layout spacing, margins, offsets, and padding;
- corner radii, borders, shadows, and stroke widths;
- resize controls and other interaction geometry.

Proportional or parent-relative geometry continues to derive from the now-final parent dimensions and is not multiplied twice.

## Text Rendering

Text is rasterized at its final pixel size with `Text.QtRendering`, preserving the shell font family, variable axes, adaptive subtext color, and existing font-weight roles. No outlines, shadows, or text-layer effects are introduced.

## Widget-Specific Considerations

- Notes: note rows, editor controls, swipe actions, and colored note content retain their proportions.
- Resources: horizontal/vertical arrangements, graph/card shapes, and value/label hierarchy remain unchanged.
- User Card: avatar overlap, content card, quip, and action buttons scale as one coherent layout.
- Weather: pill geometry, temperature, and weather symbol preserve their relative alignment.
- Clock: all clock styles and lock/status overlays use final-size metrics; time-driven behavior remains unchanged.
- Image Converter: drop zone, format controls, status states, and drag/drop hit targets scale together.

## Performance

Removing parent transforms avoids scaled intermediate glyph rasterization. It does not add layers, Canvas instances, shaders, polling, or GPU readbacks. Existing adaptive contrast sampling remains unchanged.

## Verification

- Audit included widgets for remaining parent `scale` transforms.
- Audit fixed visual metrics for missing or double scale factors.
- Confirm resize-handle behavior and persisted scale values are unchanged.
- Test small, default, and enlarged sizes in the live shell.
- Confirm text remains crisp at each size.
- Confirm Media files and behavior are unchanged.
- Run unit tests, `git diff --check`, and the isolated QML probe before targeted live installation.
