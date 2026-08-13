# OpenRGB Standard Card Metrics Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Migrate OpenRGB card mode to the shared Standard presentation tier without changing its behavior or `300 × 218` canvas.

**Architecture:** Extend `DesktopWidgetMetrics` with the missing semantic typography roles, then replace card-specific geometry and direct font references in `OpenRgbWidget.qml`. Reuse the existing pixel-snapping helpers for circular actions.

**Tech Stack:** QML/QtQuick, Quickshell, Node.js built-in test runner, Python `unittest`.

## Global Constraints

- Preserve OpenRGB discovery, staging, Apply, power, device scoping, colors, blur, persistence, and layout switching.
- Keep card mode at `300 × 218` authored pixels.
- Keep spindle mode behavior and geometry unchanged.
- Use semantic desktop-widget tokens rather than direct `Appearance.font` sizes for card content.

---

### Task 1: Complete the shared typography contract

**Files:**
- Modify: `tests/desktop-widget-metrics.test.js`
- Modify: `dots/.config/quickshell/ii/modules/ii/background/widgets/DesktopWidgetMetrics.qml`

**Interfaces:**
- Produces: `DesktopWidgetMetrics.typography.body` and `DesktopWidgetMetrics.typography.actionLabel`.

- [ ] Add failing assertions for `body` and `actionLabel` typography properties.
- [ ] Run `node --test tests/desktop-widget-metrics.test.js`; expect failure because the properties are absent.
- [ ] Add `body: Appearance.font.pixelSize.normal` and `actionLabel: Appearance.font.pixelSize.small`.
- [ ] Re-run the focused test; expect PASS.

### Task 2: Migrate card mode to Standard-tier tokens

**Files:**
- Modify: `tests/openrgb-layout.test.js`
- Modify: `dots/.config/quickshell/ii/modules/ii/background/widgets/openrgb/OpenRgbWidget.qml`

**Interfaces:**
- Consumes: shared typography, glyph, control, spacing, and padding groups.
- Consumes: `OpenRgbLayout.pixelScaled()` and `OpenRgbLayout.centeredContentY()` for circular actions.

- [ ] Add a source-contract test that extracts the `cardLayout` component and asserts it references `DesktopWidgetMetrics.padding.standard`, shared spacing tiers, `typography.body`, `typography.actionLabel`, `typography.primaryLabel`, `glyph.standardAction`, `control.compact`, `control.standard`, and `control.prominent`; assert the card block contains no direct `Appearance.font.pixelSize` references.
- [ ] Run the test and verify it fails against the current partially migrated card.
- [ ] Change card padding to `padding.standard`. Replace header, selector, Apply, footer, control, glyph, and spacing literals with their approved semantic roles. Pixel-snap the card Power circle and center it using the existing layout helper. Keep `baseWidth: 300` and `baseHeight: 218`.
- [ ] Run focused tests and verify they pass.
- [ ] Run `node --test tests/*.test.js`, `python -m unittest discover -s tests -p 'test_*.py'`, and `git diff --check`.
- [ ] Back up the live QML, deploy the metrics and OpenRGB files, reload Quickshell, and inspect logs.
- [ ] Review card mode twice at the current scale and after a reload; switch back to spindle and confirm no regression.
- [ ] Commit only the metrics, OpenRGB QML, and associated tests.
