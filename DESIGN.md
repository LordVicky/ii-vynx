# Desktop Widgets Design System

This document defines the visual language, interaction model, component architecture, and implementation rules for the desktop widgets under:

`dots/.config/quickshell/ii/modules/ii/background/widgets/`

It is derived from the current widget implementation and should be treated as the design reference when creating or modifying desktop widgets.

## 1. Design Intent

Desktop widgets are **wallpaper-native, glanceable surfaces** rather than miniature application windows. They should feel embedded in the desktop, remain legible over arbitrary wallpapers, and expose only the information or controls that are useful at a glance.

The system combines:

- Material 3-derived theme tokens from `Appearance.qml`
- rounded, expressive geometry
- frosted wallpaper glass with adaptive contrast
- compact information hierarchy
- direct manipulation: drag, snap, resize, and lightweight inline controls
- restrained, state-driven animation

A widget should look like part of the same family even when its content is unique.

## 2. Core Principles

### 2.1 Wallpaper first

Widgets live on top of the wallpaper, not on an opaque dashboard. The default card treatment is translucent/frosted and preserves visual continuity with the desktop.

Do not introduce an opaque background unless the widget explicitly needs a solid fallback/state. When blur is disabled, specialized widgets may provide their own themed fallback surface.

### 2.2 Glanceable before exhaustive

A widget should answer one small question quickly: current time, weather, CPU load, unfinished tasks, currently playing media, battery state, etc.

Prefer:

- one dominant value or state
- a short title
- a small number of supporting labels
- one or two obvious actions

Avoid dense settings, long-form navigation, or application-like chrome on the front face.

### 2.3 Theme-driven, not hard-coded

Use `Appearance.colors`, `Appearance.font`, and `Appearance.rounding` rather than literal colors, font families, or arbitrary radii.

Hard-coded measurements are acceptable for authored widget geometry, but repeated visual tokens should come from `Appearance` or shared widget components.

### 2.4 Adaptive readability

The wallpaper can be light, dark, high-contrast, animated, zoomed, or panning. Readability must not depend on a fixed wallpaper.

Frosted widgets use the shared adaptive-contrast path. Secondary text may switch between a dark and near-white neutral based on sampled local wallpaper luminance. Primary headings remain on-layer text.

### 2.5 Motion communicates state

Animation is used for:

- resizing and layout transitions
- moving/snap placement
- hover affordances
- content changes
- front/back flips where a widget has two modes
- media motion only while media is active

Do not add decorative infinite animation to otherwise idle widgets.

### 2.6 Direct manipulation stays consistent

Free-position widgets share the same drag, snap, resize, hover, and locking behavior. New widgets should inherit that behavior rather than reimplementing it.

## 3. Architecture

### 3.1 Base widget shell

All desktop widgets should derive from:

`AbstractBackgroundWidget.qml`

It provides:

- config lookup through `configEntryName`
- screen and wallpaper geometry
- free / least-busy / most-busy placement
- drag support
- widget locking behavior
- lock-screen visibility handling
- wallpaper-aware text colors
- the shared `adaptiveSubtextColor`
- animated opacity and drag scale

Typical root:

```qml
AbstractBackgroundWidget {
    id: root
    configEntryName: "example"
    hoverEnabled: true

    property real dragScale: -1
    readonly property real widgetScale: dragScale >= 0
        ? dragScale
        : (Config.options.background.widgets.example.scale ?? 1)
}
```

### 3.2 Standard card shell

For conventional frosted cards, use:

`BackgroundWidgetCard.qml`

It owns the standard:

- frosted backdrop
- adaptive contrast hookup
- drop shadow
- corner radius
- content padding
- scale wrapper
- resize handle

Default authored values:

| Token | Value |
|---|---:|
| Default base width | 276 px |
| Default base height | 252 px |
| Content padding | 16 px |
| Corner radius | `Appearance.rounding.verylarge` = 30 px in rounded mode |
| Shadow radius | 8 px |
| Resize range | 0.5×–3.0× |
| Resize handle | 16×16 px |

Use this shell unless the widget has a strong structural reason to own its geometry, such as Weather, Calendar, World Clock, Resources, Media, User Card, or Clock.

### 3.3 Frosted background

Use:

`WidgetBlurBackground.qml`

The visual stack is:

1. correctly mapped wallpaper crop
2. blur and vibrancy treatment
3. manual brightness scrim
4. automatic contrast scrim
5. optional theme tint
6. one-pixel illuminated rim
7. rounded opacity mask

Important defaults:

| Property | Current behavior |
|---|---|
| `blur` | `0.6` by default |
| blur range | `0` disables the live blurred backdrop; `1` = strongest frosted treatment |
| tint color | `Appearance.colors.colPrimaryContainer` |
| global `widgetTint` | `0` by default |
| global `widgetBrightness` | `0`, range conceptually -1…1 |
| backdrop saturation | `0.35` |
| backdrop effect brightness | `0.04` |
| max blur radius | `96` |
| edge | 1 px adaptive light/dark rim |

The wallpaper crop should receive the live wallpaper item whenever possible:

```qml
wallpaperSourceItem: root.wallpaperSourceItem
wallpaperRenderX: root.wallpaperRenderX
wallpaperRenderY: root.wallpaperRenderY
wallpaperRenderWidth: root.wallpaperRenderWidth
wallpaperRenderHeight: root.wallpaperRenderHeight
parallaxBackdrop: root.parallaxBackdrop
```

Do not replace this with a static translucent rectangle for a standard desktop card.

### 3.4 Scale-safe text and symbols

For widgets that scale the whole authored layout, prefer:

- `TransformSafeText`
- `TransformSafeSymbol`

These rasterize text/icons at their final on-screen size instead of scaling a low-resolution glyph texture.

Example:

```qml
TransformSafeText {
    text: Translation.tr("Example")
    basePixelSize: Appearance.font.pixelSize.normal
    scaleFactor: root.widgetScale
    requestedWeight: Font.DemiBold
    color: Appearance.colors.colOnLayer0
}
```

Do not use parent transform scaling as the only mechanism for text enlargement when a widget supports arbitrary user scaling.

## 4. Surface Language

### 4.1 Card geometry

The dominant card shape is a large rounded rectangle:

```qml
radius: Appearance.rounding.verylarge
```

Rounded-mode values from `Appearance.qml`:

| Radius token | px |
|---|---:|
| `verysmall` | 8 |
| `small` | 12 |
| `normal` | 17 |
| `large` | 23 |
| `verylarge` | 30 |
| `full` | pill/circle |

`sharpMode` intentionally collapses these radii to zero. New widgets must preserve that behavior by using the tokens.

### 4.2 Shape accents

Use circular, pill, or Material expressive shapes for **small accents**, not as arbitrary decoration.

Existing examples:

- Weather: full pill/circular main silhouette
- Resources: distinct Material shapes behind stat icons
- Calendar: pill month label and circular day selection
- User Card: pill action button and circular icon buttons
- Pomodoro/Battery: circular progress rings

The large containing surface should normally remain quiet while accent shapes carry hierarchy.

### 4.3 Shadows

Use `StyledDropShadow` / `StyledRectangularShadow` instead of inventing custom shadow colors.

The default shared card shadow uses:

- radius 8 px at 1× scale
- `Appearance.colors.colShadow`

Shadows should separate glass from wallpaper, not create a floating-window aesthetic.

### 4.4 Glass rim

Frosted surfaces have a one-pixel edge highlight. This is part of the material language and should not be duplicated with a second card border unless the border communicates an interactive state.

## 5. Color System

The desktop widget palette is semantic. Use token roles rather than choosing literal colors.

### 5.1 Primary text

Use:

`Appearance.colors.colOnLayer0`

for the principal title/value/body text that must remain strongly readable.

For widgets with a colored container whose semantic foreground is already established, use the corresponding `colOn*Container` token.

### 5.2 Secondary text

For secondary labels inside wallpaper-backed widgets, prefer:

`root.adaptiveSubtextColor`

instead of `Appearance.colors.colSubtext`.

The adaptive value falls back to `colSubtext` until a wallpaper sample is available.

Use fixed `colSubtext` only when the element is intentionally non-adaptive or the design explicitly requires a stable muted color.

### 5.3 Accent roles

Typical usage:

| Role | Token |
|---|---|
| primary accent | `colPrimary` |
| primary surface | `colPrimaryContainer` |
| primary surface foreground | `colOnPrimaryContainer` |
| second metric/category | `colSecondary` / `colSecondaryContainer` |
| third metric/category | `colTertiary` / `colTertiaryContainer` |
| warning/critical/privacy active | `colError` |
| muted outline | `colOutline` / `colOutlineVariant` |

Use secondary and tertiary colors to distinguish parallel data categories, not simply to make a widget more colorful.

### 5.4 Adaptive contrast behavior

The shared sampler measures the local wallpaper region, not the entire image.

Current behavior:

- automatic darkening begins around relative luminance `0.35`
- reaches its maximum around `0.65`
- automatic black scrim is capped at `0.32` opacity
- secondary-text switching uses hysteresis:
  - switch toward dark text at approximately `0.52` effective luminance
  - switch back toward light text below approximately `0.40`

Do not add a second contrast sampler, screenshot/readback path, or per-widget luminance loop.

## 6. Typography

Typography comes from `Appearance.font`.

### 6.1 Size scale

Current pixel-size tokens:

| Token | px | Typical widget use |
|---|---:|---|
| `smallest` | 10 | tertiary metadata |
| `smaller` | 12 | secondary labels, list rows |
| `smallie` | 13 | compact body values |
| `small` | 14 | standard body |
| `normal` | 15 | headings/body |
| `large` | 17 | stronger headings/icons |
| `larger` | 19 | emphasized values |
| `huge` | 22 | large values |
| `hugeass` | 23 | dominant compact values |
| `title` | 28 | authored title treatment |

### 6.2 Weight

Typical hierarchy:

- `Font.DemiBold` for widget titles and important values
- `Font.Medium` for supporting labels/actions
- `Font.Normal` for secondary body/metadata

Do not create hierarchy by size alone.

### 6.3 Alignment

Text should usually align to the content it describes rather than defaulting everything to center.

Centered treatment is appropriate for intrinsically radial/hero layouts such as clocks, weather, timers, and battery gauges. Lists, resources, notes, clipboard, updates, and task content should generally align to the start edge.

## 7. Spacing and Density

The system is compact but not cramped.

Typical authored spacing:

| Use | px |
|---|---:|
| card content inset | 12–16 |
| major vertical gap | 10–12 |
| heading icon/text gap | 8 |
| normal internal gap | 6–8 |
| tight row gap | 4 |
| list row height | 26–28 |

Prefer a small number of consistent gaps over arbitrary per-element spacing.

## 8. Widget Placement and Manipulation

### 8.1 Placement strategies

The shared widget host supports:

- `free`
- `leastBusy`
- `mostBusy`

Do not implement separate placement behavior inside a new widget.

### 8.2 Dragging

Free widgets use the shared drag behavior from the widget canvas infrastructure.

When widgets are locked:

- drag affordances disappear
- resize affordances disappear
- hover editing chrome should not remain visible

### 8.3 Resizing

Continuous-scale widgets use the shared bottom-right `WidgetResizeHandle`.

The established pattern is:

```qml
property real dragScale: -1
readonly property real widgetScale: dragScale >= 0
    ? dragScale
    : Config.options.background.widgets.example.scale
```

During drag, update `dragScale`. On commit, persist the value and reset `dragScale` to `-1` so the binding returns to Config.

Do not leave `dragScale` initialized to a normal scale value such as `1`, because that breaks live binding to persisted config.

## 9. Animation

Use the shared motion tokens from `Appearance.animation`.

Current notable durations:

| Token | ms |
|---|---:|
| `elementMoveFast` | 200 |
| `elementMove` | 300 |
| `elementMoveEnter` | 400 |
| `elementMoveExit` | 250 |
| `menuOpen` | 350 |
| `menuClose` | 200 |

Typical widget transitions should use `Appearance.animation.elementMoveFast` unless the component already establishes a different motion pattern.

Preferred easing:

`Appearance.animation.elementMoveFast.type`

which currently maps to an expressive Material easing curve.

Avoid linear animation for primary UI transitions.

## 10. Hover and Editing Affordances

Hover-only controls should stay visually quiet until needed.

Common pattern:

```qml
opacity: root.hovered && !GlobalStates.desktopWidgetsLocked ? 1 : 0
```

Use this for:

- resize handles
- secondary actions
- edit buttons
- destructive controls

Do not hide the widget's primary purpose behind hover.

## 11. Information Hierarchy

A conventional information widget should normally follow this hierarchy:

```text
┌──────────────────────────────────┐
│ [accent icon]  Title      status │
│                                  │
│ dominant value / primary content │
│ supporting row / list / chart    │
│                                  │
│ secondary metadata / action      │
└──────────────────────────────────┘
```

Recommended heading row:

- accent icon: `Appearance.font.pixelSize.large`
- title: `Appearance.font.pixelSize.normal`, DemiBold
- title color: `colOnLayer0`
- optional status/meta: `smaller`, `adaptiveSubtextColor`
- horizontal spacing: 8 px

The title should not compete with the widget's dominant metric.

## 12. Controls

### 12.1 Buttons

Small icon actions are generally 26–30 px and circular/pill-shaped.

Use semantic hover fills such as:

- `colPrimaryContainer`
- `colPrimaryContainerHover`
- matching `colOnPrimaryContainer` foreground

Use `Qt.PointingHandCursor` for clickable controls.

### 12.2 Progress

Circular progress is established for timer and battery state. Use it when progress has a natural bounded 0–1 meaning.

Avoid decorative gauges for values that are better compared numerically.

### 12.3 Lists

Lists should be shallow and glanceable.

Existing conventions:

- 26–28 px rows
- compact 2–6 px row spacing
- elide single-line text rather than widening the widget without bound
- clip scrolling content to the card
- use an explicit empty state

### 12.4 Charts

Charts are secondary to the value itself. They should remain low-noise and use semantic accent colors.

Resource/network logic should favor one immediately readable value over multiple competing graph traces unless the trend is the main purpose of the widget.

## 13. Responsive and Size Modes

There are two supported design approaches.

### Continuous scale

Use when the information architecture is unchanged at every size.

Reference widgets:

- To-do
- Pomodoro
- Lyrics
- Clipboard
- Updates
- Privacy
- Battery
- Weather
- Notes
- Resources
- Media

Store a scalar `scale` in widget config and preserve the `dragScale = -1` binding pattern.

### Discrete layout modes

Use when shrinking/growing should change composition instead of scaling the same layout.

Reference widgets:

- Calendar
- World Clock
- Media layout variants are also a content-layout mode, although the entire result can still be scaled afterward

Define named modes and snap dragged dimensions to the nearest supported breakpoint. Do not create dozens of near-identical breakpoints.

## 14. Lock Screen Behavior

Widgets default to:

`Config.options.lock.showWidgets`

for lock-screen visibility.

Clock explicitly remains lock-visible and can force itself to screen center. Any new widget that overrides lock behavior should do so intentionally and avoid exposing private content on the lock screen.

## 15. Performance Rules

Desktop widgets are persistent shell UI. Small inefficiencies multiply across many simultaneously enabled widgets.

### Required

- reuse `WidgetBlurBackground`
- reuse the shared adaptive contrast sampler
- keep polling services active only while a consumer exists where the service supports instance counting
- stop timers/animations when their state is inactive
- use cached/shared wallpaper decoding paths
- change inexpensive overlays instead of reconfiguring blur effects during interactive sliders
- throttle/coalesce wallpaper luminance sampling during drag/resize

### Avoid

- one wallpaper decoder per custom widget implementation
- per-frame `grabToImage`, GPU readback, or screenshot sampling
- `ShaderEffectSource` for contrast analysis
- independent luminance canvases per widget
- continuously running animations with no visible state purpose
- binding frequently changing slider values into an expensive `MultiEffect`

The current adaptive contrast path is deliberately request-driven and caps motion sampling to roughly one request per 150 ms per moving card.

## 16. Accessibility and Legibility

- never assume a dark wallpaper
- do not communicate critical state using color alone; pair it with icon/text/state
- use `colError` for critical states, with a meaningful symbol/label
- preserve adequate tap/click target area even when the visible icon is small
- elide text only when the full value is nonessential; otherwise allow wrapping or a larger mode
- keep primary values visually distinct from metadata
- preserve focus behavior for actual text-entry controls

## 17. Implementation Template

Use this as the default starting point for a new conventional desktop widget:

```qml
import QtQuick
import QtQuick.Layouts
import qs
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.ii.background.widgets

AbstractBackgroundWidget {
    id: root
    configEntryName: "example"
    hoverEnabled: true

    property real dragScale: -1
    readonly property real widgetScale: dragScale >= 0
        ? dragScale
        : (Config.options.background.widgets.example.scale ?? 1)

    implicitWidth: card.implicitWidth
    implicitHeight: card.implicitHeight

    BackgroundWidgetCard {
        id: card
        host: root
        scaleFactor: root.widgetScale
        baseWidth: 276
        baseHeight: 168

        onRequestScale: v => root.dragScale = v
        onCommitScale: v => {
            Config.options.background.widgets.example.scale = v
            root.dragScale = -1
        }

        ColumnLayout {
            anchors.fill: parent
            spacing: card.scaled(8)

            RowLayout {
                Layout.fillWidth: true
                spacing: card.scaled(8)

                TransformSafeSymbol {
                    text: "widgets"
                    baseIconSize: Appearance.font.pixelSize.large
                    scaleFactor: root.widgetScale
                    color: Appearance.colors.colPrimary
                }

                TransformSafeText {
                    Layout.fillWidth: true
                    text: Translation.tr("Example")
                    basePixelSize: Appearance.font.pixelSize.normal
                    scaleFactor: root.widgetScale
                    requestedWeight: Font.DemiBold
                    color: Appearance.colors.colOnLayer0
                }
            }

            TransformSafeText {
                Layout.fillWidth: true
                text: Translation.tr("Secondary information")
                basePixelSize: Appearance.font.pixelSize.smaller
                scaleFactor: root.widgetScale
                color: root.adaptiveSubtextColor
            }

            Item { Layout.fillHeight: true }
        }
    }
}
```

Also add the corresponding config object with at least:

```qml
property JsonObject example: JsonObject {
    property bool enable: false
    property string placementStrategy: "free"
    property real x: 400
    property real y: 100
    property real blur: 0.6
    property real scale: 1
}
```

Then instantiate the widget in `Background.qml`, forwarding all screen and wallpaper geometry fields used by the other widgets.

## 18. New Widget Checklist

Before considering a new widget visually complete, verify:

- [ ] derives from `AbstractBackgroundWidget`
- [ ] uses `BackgroundWidgetCard` unless a specialized silhouette/layout justifies otherwise
- [ ] uses `WidgetBlurBackground` for wallpaper-backed surfaces
- [ ] forwards live wallpaper geometry and `wallpaperSourceItem`
- [ ] uses semantic `Appearance` color tokens
- [ ] primary heading/value remains clearly readable
- [ ] appropriate secondary text uses `root.adaptiveSubtextColor`
- [ ] uses `TransformSafeText` / `TransformSafeSymbol` when continuously scaled
- [ ] follows the 12–16 px content inset and compact 4–12 px internal rhythm
- [ ] uses `Appearance.rounding` tokens
- [ ] persists scale or size mode through Config
- [ ] resize affordance disappears when widgets are locked
- [ ] hover-only controls are discoverable but unobtrusive
- [ ] timers, polling, and animation stop when unnecessary
- [ ] content is useful at a glance and does not behave like a miniature full application
- [ ] lock-screen visibility is intentional
- [ ] no duplicate adaptive-contrast or wallpaper-processing pipeline was introduced

## 19. Anti-Patterns

Do not:

- build a new frosted card from a plain semi-transparent `Rectangle` when the shared glass component fits
- hard-code white/black secondary text based on an assumed wallpaper
- add another Network card/widget while throughput is already part of Resources
- scale ordinary `StyledText` through a transformed parent and accept blurry glyphs
- add large persistent controls that only matter during editing
- create a unique radius/shadow/padding language for a single widget without a functional reason
- animate expensive effects continuously
- use literal brand-like colors where a semantic theme token exists
- turn a glanceable widget into a settings panel

## 20. Source of Truth

When this document and the implementation diverge, the following files are authoritative for current behavior:

- `modules/common/Appearance.qml` — color, type, radius, and motion tokens
- `modules/common/Config.qml` — widget defaults and user-configurable behavior
- `modules/common/widgets/widgetCanvas/AbstractWidget.qml` — drag/snap/lock interaction
- `modules/ii/background/widgets/AbstractBackgroundWidget.qml` — desktop widget host behavior
- `modules/ii/background/widgets/BackgroundWidgetCard.qml` — standard card composition
- `modules/ii/background/widgets/WidgetBlurBackground.qml` — frosted glass and adaptive readability
- `modules/ii/background/widgets/WidgetResizeHandle.qml` — resize interaction
- `modules/ii/background/widgets/TransformSafeText.qml` — scale-safe typography
- `modules/ii/background/widgets/TransformSafeSymbol.qml` — scale-safe iconography
- `modules/ii/background/Background.qml` — live widget registration/loading

Update this document when a shared design primitive changes, not for every internal service or data-source change.
