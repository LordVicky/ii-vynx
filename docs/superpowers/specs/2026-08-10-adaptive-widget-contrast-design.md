# Adaptive Widget Contrast Design

## Goal

Keep text readable when a ported desktop widget is dragged over a bright part of the wallpaper, without changing text colors, adding glyph effects, or increasing continuous GPU load.

## Scope

The feature applies to every desktop widget using `WidgetBlurBackground`, including the custom media widget and older independently implemented frosted widgets. Callers may explicitly opt out when adaptive contrast is inappropriate. Existing manual widget tint and brightness settings remain authoritative inputs.

## Chosen Approach

Measure the wallpaper source through one shared CPU-backed QML `Canvas`. The sampler draws a requested source region into an 8×8 image and computes WCAG relative luminance from those 64 pixels. It does not capture the rendered card, read back a blurred GPU texture, or run a shader.

The shared sampler loads the same wallpaper URL used by `WidgetBlurBackground` once. Its Canvas remains 8×8 and uses `Canvas.Image`, avoiding a persistent GPU framebuffer and avoiding one wallpaper decode or Canvas allocation per widget.

## Coordinate Mapping

Each card maps its four corners into `wallpaperSourceItem` local coordinate space and submits the resulting normalized rectangle with its request. The shared sampler converts that displayed rectangle into source-image coordinates while accounting for `Image.PreserveAspectCrop` cover scaling. When only numeric wallpaper geometry is available, the card derives the normalized rectangle from the existing wallpaper render rectangle and widget offset values. Invalid or unloaded geometry disables automatic correction rather than guessing.

## Sampling Lifecycle

Sampling is event-driven, not frame-driven:

- Re-sample when the wallpaper URL changes or finishes loading.
- Re-sample after widget position or scale changes, coalesced through one timer.
- While a widget is being dragged or resized, submit no more than one request every 150 ms.
- Take a final sample after movement settles.
- Do no work while the wallpaper, card, or blur backdrop is unavailable.

The shared sampler coalesces pending work by card identifier, services requests sequentially, and retains only the newest request for each card. It has no animation loop or idle polling timer.

## Contrast Model

The sampler returns average relative luminance from 0 to 1. Automatic darkening remains zero through dark regions, begins gradually around luminance 0.35, and reaches its conservative maximum around 0.65. These values are calibrated against the live pink/orange wallpaper, whose visually bright regions measure lower in WCAG luminance than neutral whites. A smoothstep curve avoids visible threshold steps.

The resulting black scrim opacity is capped at 0.32. This is enough to stabilize light text over pale wallpaper without turning the frosted card into dark opaque glass.

A small luminance deadband prevents opacity churn over noisy image regions. The scrim opacity uses the existing fast element animation, so infrequent sample updates blend smoothly rather than flash.

## Interaction With Manual Brightness

Manual brightness keeps its current behavior. Automatic darkening is a separate black scrim layered after the manual brightness scrim and before the tint/rim. The effects therefore compose predictably:

- Negative manual brightness and automatic darkening reinforce each other.
- Positive manual brightness still brightens the backdrop, but automatic contrast can recover legibility on an already bright local crop.
- A missing or failed sample produces zero automatic opacity and preserves current behavior.

## Component Boundaries

- `WallpaperLuminanceSampler.qml`: a singleton that owns the one wallpaper load, request queue, cover-crop conversion, CPU Canvas sampling, and per-card luminance results.
- `WidgetBlurBackground.qml`: enables adaptive contrast by default, derives a stable client identifier, maps its local crop to normalized wallpaper coordinates, throttles movement requests, converts its returned luminance to automatic scrim opacity, and draws the inexpensive black rectangle.
- `BackgroundWidgetCard.qml`: supplies the same live widget geometry for the nine ported cards. Independently implemented frosted widgets use their existing `WidgetBlurBackground` instances without per-widget changes.

## Performance Constraints

- No `ShaderEffectSource`, `grabToImage`, or rendered-scene GPU readback.
- No continuous animation or per-frame callback.
- Exactly one Canvas render target, fixed at 8×8 pixels and CPU-backed.
- Exactly one wallpaper source load shared by every participating card.
- Per-card request rate capped during motion; the shared sampler is idle when its queue is empty.
- The blur effect is never invalidated by luminance updates; only a rectangle's opacity changes.
- Wallpaper decode dimensions are reused where Qt caching permits; the sampler must not request a unique source size per widget.

## Failure Handling

Image load errors, zero-sized geometry, invalid mapped rectangles, or Canvas read failures set the sample as unavailable. Automatic darkening then becomes zero. Errors should not spam logs during dragging.

## Verification

- QML configuration loads without new runtime errors.
- Ported cards remain unchanged over dark and midtone wallpaper regions.
- Bright local regions produce a smooth, bounded darkening response.
- Dragging does not create continuous GPU activity after the widget settles.
- Rapid dragging coalesces requests to at most one per 150 ms per moving card, and superseded queued requests are discarded.
- Existing manual brightness, tint, blur, parallax, and resize behavior still work.
- Only targeted files are installed into the live shell and compared with the branch.
