# Adaptive Widget Subtext Design

## Goal

Make secondary text readable as desktop widgets move between light and dark wallpaper regions, while headings remain white and the existing adaptive-contrast sampler stays the only wallpaper analysis path.

## Scope and Text Roles

The feature applies to desktop widgets derived from `AbstractBackgroundWidget` that use `WidgetBlurBackground`.

- Heading text remains white/current `colOnLayer0` and never switches.
- Secondary text currently using `Appearance.colors.colSubtext` switches between a near-white and dark neutral according to the card's sampled background.
- Material symbols, status dots, borders, controls, and other non-text elements are unchanged.
- Primary body text already using `colOnLayer0` is unchanged.
- In `MediaWidget`, only the track title becomes adaptive. The artist/album subtitle remains muted gray.

## Data Flow

`WidgetBlurBackground` already receives local wallpaper luminance from the one shared `AdaptiveContrast` sampler. It derives an `adaptiveSubtextColor` from that existing value without issuing another sample.

Each blur background receives an explicit `contrastHost` reference to its owning `AbstractBackgroundWidget`. The host exposes `adaptiveSubtextColor`, allowing text anywhere inside the widget's layout to bind to `root.adaptiveSubtextColor` without knowing the sampler client ID or blur component structure.

The binding remains declarative. `WidgetBlurBackground` does not imperatively assign the host property; each widget binds its host property to the blur background's published color through an explicit `Binding` or direct property binding.

## Color Decision

The decision uses sampled local wallpaper luminance and the automatic black-scrim opacity already applied to the card. It estimates the darkening effect as `effectiveLuminance = sampledLuminance * (1 - automaticScrimOpacity)`.

- Dark background: near-white secondary text derived from the shell's on-layer color.
- Light background: dark neutral secondary text derived from the shell's layer/on-layer palette rather than hard-coded black.
- Unknown sample: fall back to `Appearance.colors.colSubtext`.

The switch uses a narrow 0.44–0.48 hysteresis band around the decision boundary. This prevents rapid toggling on noisy wallpaper without letting text color remain path-dependent after a card leaves a very bright region. The selected color animates with the existing fast color animation.

## Component Boundaries

- `AbstractBackgroundWidget.qml`: declares the shared `adaptiveSubtextColor` fallback property.
- `WidgetBlurBackground.qml`: exposes the derived adaptive color and stable light/dark state from its existing luminance sample.
- `BackgroundWidgetCard.qml`: binds its host's adaptive text property to its blur background for all nine ported cards.
- Independently implemented frosted widgets: bind their root property to their local `WidgetBlurBackground` instance.
- Individual widget text nodes: replace only approved secondary-text color bindings with `root.adaptiveSubtextColor`.

## Performance Constraints

- No additional Canvas, wallpaper load, sampler client, timer, shader, or GPU readback.
- Color calculation runs only when the existing luminance result or theme palette changes.
- Color animation changes text color only; it does not invalidate the blur chain.

## Verification

- Unit-test the effective luminance and hysteresis decision logic.
- Confirm headings remain white across all modified widgets.
- Confirm textual secondary labels switch on dark/light regions while icons remain unchanged.
- Confirm media track title switches and artist/album does not.
- Confirm the live shell reports no new QML errors.
- Confirm sampler client count and sampling rate do not increase.
