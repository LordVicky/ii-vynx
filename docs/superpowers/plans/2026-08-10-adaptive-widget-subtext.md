# Adaptive Widget Subtext Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Switch secondary widget text between light and dark neutrals using each card's existing wallpaper luminance sample while keeping headings white.

**Architecture:** Extend the pure contrast math with effective-luminance and hysteresis decisions. `WidgetBlurBackground` publishes one adaptive secondary color to its owning `AbstractBackgroundWidget`; text nodes bind to that shared property. No new sampling or rendering resources are introduced.

**Tech Stack:** Quickshell, QtQuick/QML, JavaScript, Node.js tests

## Global Constraints

- No additional sampler clients, Canvas instances, wallpaper decodes, timers, shaders, or GPU readbacks.
- Headings and primary body text remain unchanged.
- Only text changes; icons and other graphics retain their existing colors.
- Media changes only its track title; artist/album remains muted gray.

---

### Task 1: Test and implement adaptive text decision math

**Files:**
- Modify: `tests/adaptive-contrast.test.js`
- Modify: `dots/.config/quickshell/ii/modules/ii/background/widgets/AdaptiveContrast.js`

**Interfaces:**
- Produces: `effectiveLuminance(luminance, scrimOpacity) -> number` and `shouldUseDarkText(effectiveLuminance, currentlyDark) -> bool`.

- [ ] Add failing tests for scrim-adjusted luminance and 0.40/0.52 hysteresis thresholds.
- [ ] Run `node --test tests/adaptive-contrast.test.js` and confirm failure.
- [ ] Implement clamped effective luminance and hysteresis.
- [ ] Run the tests and confirm success.

### Task 2: Publish one adaptive color per widget

**Files:**
- Modify: `AbstractBackgroundWidget.qml`
- Modify: `WidgetBlurBackground.qml`
- Modify: `BackgroundWidgetCard.qml`
- Modify direct blur consumers: calendar, clock, image converter, media, notes, resources, user card, weather, and world clock widgets.

**Interfaces:**
- `AbstractBackgroundWidget.adaptiveSubtextColor: color` is the consumer-facing property.
- `WidgetBlurBackground.contrastHost: Item` explicitly identifies the owner.
- `WidgetBlurBackground.adaptiveSubtextColor: color` is derived from the existing sample and automatic scrim.

- [ ] Add the host fallback property and fast color Behavior.
- [ ] Add hysteretic state and palette-derived near-white/dark neutral colors to `WidgetBlurBackground`.
- [ ] Bind the blur result to `contrastHost.adaptiveSubtextColor` declaratively.
- [ ] Pass `contrastHost: root` from every direct blur consumer.
- [ ] Run `qs-probe` and confirm no new QML errors.

### Task 3: Convert only secondary text roles

**Files:**
- Modify ported widgets: battery, clipboard, lyrics, pomodoro, song recognition, todo, updates, and privacy where applicable.
- Modify older widgets: resources, user card, world clock, calendar, and image converter secondary labels.
- Modify: `media/MediaWidget.qml` track title instances only.

**Interfaces:**
- Consumes: `root.adaptiveSubtextColor`.

- [ ] Replace textual `colSubtext` bindings while leaving symbol/icon bindings unchanged.
- [ ] Replace older reduced-opacity secondary text colors with the adaptive property and remove opacity only where it was serving as the text-muted color.
- [ ] Change both deck and spindle media track-title instances; leave both track-subtitle instances unchanged.
- [ ] Audit heading bindings and confirm they remain white/current on-layer colors.

### Task 4: Verify and install live

**Files:**
- Install only modified runtime QML/JS files under matching paths in `~/.config/quickshell/ii`.

- [ ] Run `node --test tests/adaptive-contrast.test.js`, `git diff --check`, and `qs-probe`.
- [ ] Install targeted files with `install -D -m 644`; do not sync the whole tree.
- [ ] Confirm branch/live byte parity and healthy live reload logs.
- [ ] Use temporary diagnostics to confirm sampler client count/rate did not increase, then remove them.
- [ ] Inspect the live desktop on both light and dark regions and confirm media changes only its track title.
