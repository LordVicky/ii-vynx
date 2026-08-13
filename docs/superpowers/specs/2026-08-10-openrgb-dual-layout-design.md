# OpenRGB Dual-Layout Widget Design

## Goal

Give the OpenRGB desktop widget the same hover-driven layout switching pattern as the music widget, while reducing the horizontal layout to its essential controls and restoring the earlier vertical card as an alternate layout.

## Layout Model

Persist `Config.options.background.widgets.openRgb.layout` with two values:

- `spindle`: the optimized single-line layout and default for the current live configuration.
- `card`: the restored vertical mode-switch layout.

A small hover-only layout button appears on both layouts when desktop widgets are unlocked. It follows the music widget's opacity, lock-state, icon, pointer, and click behavior. Clicking it switches between `spindle` and `card`, updates the persisted setting, and changes the widget's base dimensions without changing staged or active OpenRGB state.

The two layouts are separate QML `Component` trees selected by a `Loader`. OpenRGB behavior remains at the widget root so switching layouts cannot apply, discard, or otherwise mutate a profile/effect selection.

## Spindle Layout

The horizontal layout contains only:

1. A circular power button with no attached status dot.
2. The flexible selection region: `Profiles`/`Effects` and previous/staged/next.
3. A circular Apply button and caption at the far right.

Remove the OpenRGB name, lightbulb, device count, both light-status dots, `Lights on`/`Lights off` copy, connection/active metadata row, and dividers from the spindle layout. Delete the obsolete QML for those elements rather than retaining hidden instances.

Reduce the spindle to a `420 × 100` canvas with compact internal gaps. Preserve enough flexible width for ordinary profile/effect names at the user's configured live scale and elide unusually long names.

## Card Layout

Restore the earlier `300 × 218` vertical card composition with:

- OpenRGB identity, live status, and refresh affordance.
- Profiles/Effects segmented switch.
- Power control.
- Previous/staged/next selector.
- Explicit Apply action.
- Active-item and collection-status text.

The card layout retains its fuller identity and status presentation because those details suit the larger stacked format. Previous/next continue to stage only; Apply remains the sole activation action.

## Shared Behavior and Surface

- Both layouts use the same `showingEffects`, staged selections, active selections, refresh, Apply, and scoped power behavior.
- Effect refresh continues discovering newly installed effects.
- Both layouts rely exclusively on `BackgroundWidgetCard` and the existing widget blur mechanism. Add no custom translucency, tint, blur, border, glow, or halo.
- Use the same `0.8` wallpaper blur default as the calendar widget so the OpenRGB surface reflects the wallpaper rather than reading as a darker opaque card.
- Layout switching is disabled while widgets are locked, matching the music widget.
- Busy, unavailable, empty, and error states continue using existing backend properties and appearance tokens.

## Scope

Modify:

- `Config.qml` to add the persisted OpenRGB layout value.
- `OpenRgbWidget.qml` to introduce the two layout components, music-style toggle, compact spindle composition, and restored card composition.

Do not modify OpenRGB backend discovery, profile/effect application, device-scoped power behavior, shared card/blur components, or unrelated widgets.

## Verification

- Verify layout switching works in both directions and survives a Quickshell reload.
- Verify each layout preserves staged selections and does not apply during switching.
- Verify the spindle has no identity block, device count, light-status copy, status dots, or obsolete spacing.
- Verify the card exposes the restored controls and both layouts retain explicit Apply behavior.
- Verify refresh still discovers effects and existing JavaScript/Python tests pass.
- Deploy to the live configuration and check Quickshell logs for OpenRGB-specific errors.
- Capture and compare the first live screenshot for hierarchy, compactness, clipping, toggle placement, and absence of custom glow; correct concrete discrepancies.
- Capture and compare a second live screenshot in both layouts before completion.
