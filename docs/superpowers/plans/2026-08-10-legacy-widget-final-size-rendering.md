# Legacy Widget Final-Size Rendering Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove parent scale transforms from Notes, Resources, User Card, Weather, Clock, and Image Converter so text and geometry render at final size.

**Architecture:** Each widget keeps its existing persisted scale but sizes its wrapper directly at final dimensions. Authored visual metrics are multiplied explicitly through a local `scaled(value)` helper; text and symbols receive final pixel sizes with Qt rendering. Media is excluded.

**Tech Stack:** Quickshell, QtQuick/QML

## Global Constraints

- Do not modify `media/MediaWidget.qml` or its supporting components.
- Preserve service logic, configuration keys, drag/drop behavior, layout modes, and resize persistence.
- Do not add rendering layers, shadows on text, Canvas work, or polling.
- Preserve adaptive contrast and dynamic subtext behavior.

---

### Task 1: Convert simple fixed-layout widgets

**Files:**
- Modify: `weather/WeatherWidget.qml`
- Modify: `resources/ResourcesWidget.qml`

- [ ] Remove wrapper transforms and size wrappers at final dimensions.
- [ ] Add local `scaled(value)` helpers.
- [ ] Scale fixed card, symbol, text, spacing, and resize geometry exactly once.
- [ ] Run `qs-probe` and audit both files for remaining parent transforms.

### Task 2: Convert fixed-card content widgets

**Files:**
- Modify: `notes/NotesWidget.qml`
- Modify: `images/ImageConverterWidget.qml`

- [ ] Convert wrapper and card dimensions to final geometry.
- [ ] Scale note rows, editor controls, drop zone, labels, icons, radii, margins, and hit targets.
- [ ] Set direct text to Qt rendering at final pixel sizes.
- [ ] Run `qs-probe` and audit for unscaled visual constants.

### Task 3: Convert overlapping and dynamic-layout widgets

**Files:**
- Modify: `usercard/UserCardWidget.qml`
- Modify: `clock/ClockWidget.qml`

- [ ] Convert wrapper geometry without disturbing avatar/card overlap or clock-style switching.
- [ ] Scale text, symbols, controls, overlays, margins, radii, and shadow geometry.
- [ ] Preserve all time/player/lock behavior and resize handles.
- [ ] Run `qs-probe` and audit for parent transforms and double scaling.

### Task 4: Verify and install live

**Files:**
- Install only the six converted widget files under matching paths in `~/.config/quickshell/ii`.

- [ ] Run `node --test tests/adaptive-contrast.test.js`, `git diff --check`, and final `qs-probe`.
- [ ] Confirm `media/MediaWidget.qml` has no diff from this conversion.
- [ ] Install targeted files with `install -D -m 644` and confirm byte parity.
- [ ] Inspect small/default/enlarged live widgets for crisp text and proportional layout.
- [ ] Remove any temporary diagnostics and confirm healthy live reload logs.
