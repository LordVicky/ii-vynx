# OpenRGB Horizontal Widget Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the stacked OpenRGB desktop widget with the approved single-line spindle-style interface and verify it against the supplied reference twice.

**Architecture:** Keep the current state, staging, Apply, refresh, and power functions at the `AbstractBackgroundWidget` root. Replace only the visual tree inside `BackgroundWidgetCard` with a fixed-proportion horizontal `RowLayout`; continue using the shared card and blur mechanism without custom surface effects.

**Tech Stack:** Qt Quick/QML, Quickshell, ii-vynx appearance tokens, existing Node.js and Python OpenRGB tests, `grim` screenshots.

## Global Constraints

- Modify only `dots/.config/quickshell/ii/modules/ii/background/widgets/openrgb/OpenRgbWidget.qml` for production code.
- Use a `760 × 118` unscaled canvas and the existing desktop-widget scale control; this final review-derived width keeps status copy legible at the configured live scale.
- Use `BackgroundWidgetCard` as the only surface and blur mechanism.
- Add no custom translucency, tint, blur, border, decorative glow, colored halo, or outer bloom.
- Previous and next stage selections; only Apply activates them.
- Preserve refresh discovery of newly installed effects.
- Do not alter backend effect discovery, profile parsing, power targeting, or configuration schema.

---

### Task 1: Horizontal OpenRGB Composition

**Files:**
- Modify: `dots/.config/quickshell/ii/modules/ii/background/widgets/openrgb/OpenRgbWidget.qml`
- Test: `tests/openrgb-effects.test.js`
- Test: `tests/test_openrgb_power.py`

**Interfaces:**
- Consumes: `OpenRgb.available`, `OpenRgb.busy`, `OpenRgb.applying`, `OpenRgb.lightsEnabled`, `OpenRgb.deviceCount`, `OpenRgb.profiles`, `OpenRgb.effects`, `OpenRgb.activeProfile`, `OpenRgb.activeEffect`, `OpenRgb.effectAvailable`, `OpenRgb.lastError`, `OpenRgb.statusText`, `OpenRgb.refresh()`, `OpenRgb.toggleLights()`, `OpenRgb.applyProfile(name)`, and `OpenRgb.applyEffect(name)`.
- Produces: the same widget-level `showingEffects`, `stagedProfile`, `stagedEffect`, `cycleStaged(delta)`, and `applyStaged()` behavior in a `760 × 118` horizontal visual composition.

- [ ] **Step 1: Capture the current widget as the visual baseline**

Run:

```bash
grim /tmp/openrgb-horizontal-before.png
```

Expected: a screenshot containing the current stacked OpenRGB card for before/after comparison.

- [ ] **Step 2: Change only the card geometry and content layout**

In `OpenRgbWidget.qml`, retain the root properties, reconciliation functions, connections, and scale handlers. Set:

```qml
baseWidth: 760
baseHeight: 118
cornerRadius: Appearance.rounding?.verylarge ?? 30
contentPadding: 14
```

Replace the stacked `ColumnLayout` with one `RowLayout` containing, in order:

```qml
PowerControl
IdentityBlock
VerticalDivider
SelectionBlock
ApplyControl
VerticalDivider
PowerStatus
```

Use `Layout.fillWidth` only on `SelectionBlock`; all other regions keep bounded widths so the staged item remains the dominant text.

- [ ] **Step 3: Implement the power and identity regions**

Create local inline components in `OpenRgbWidget.qml`:

```qml
component VerticalDivider: Rectangle {
    implicitWidth: card.scaled(1)
    Layout.fillHeight: true
    Layout.topMargin: card.scaled(10)
    Layout.bottomMargin: card.scaled(10)
    color: root.adaptiveSubtextColor
    opacity: 0.22
}
```

Implement a 70-pixel circular power control using the existing `OpenRgb.toggleLights()` action and a 10-pixel status dot anchored at its lower-right. Implement a 126-pixel identity block with lightbulb icon, `OpenRGB`, and the live `OpenRgb.statusText` device count. Keep the existing hover-only refresh action in this block and call `OpenRgb.refresh()`.

- [ ] **Step 4: Implement mode, selector, and metadata regions**

Build `SelectionBlock` as three compact rows:

```qml
ColumnLayout {
    Layout.fillWidth: true
    spacing: card.scaled(4)
    // 26px Profiles / Effects segmented switch
    // previous button + dominant elided staged name + next button
    // connection state + separator dot + currently active item
}
```

The mode tabs update only `root.showingEffects`. The chevrons call `root.cycleStaged(-1)` and `root.cycleStaged(1)`. The dominant label uses `root.currentLabel`, centered, `Font.DemiBold`, and `Text.ElideMiddle`. The metadata uses the existing effect/plugin availability text and `root.activeName`, with error coloring when `OpenRgb.lastError` is non-empty.

- [ ] **Step 5: Implement Apply and far-right light status**

Create a 58-pixel circular Apply control with a `check` glyph and an `Apply` caption beneath it. Its mouse area must use:

```qml
enabled: OpenRgb.available
    && root.hasCurrentItems
    && !OpenRgb.busy
    && (!root.showingEffects || OpenRgb.effectAvailable)
onClicked: root.applyStaged()
```

Create a bounded far-right status row containing a 9-pixel status dot and `Lights on`/`Lights off`; use the primary color only when lights are enabled.

- [ ] **Step 6: Verify backend regression coverage**

Run:

```bash
node --test tests/openrgb-effects.test.js
python -m unittest tests/test_openrgb_power.py
git diff --check -- dots/.config/quickshell/ii/modules/ii/background/widgets/openrgb/OpenRgbWidget.qml
```

Expected: all Node and Python tests pass and `git diff --check` produces no output.

### Task 2: Live Deployment and Two Visual Review Passes

**Files:**
- Source: `dots/.config/quickshell/ii/modules/ii/background/widgets/openrgb/OpenRgbWidget.qml`
- Deploy: `/home/lordvicky/.config/quickshell/ii/modules/ii/background/widgets/openrgb/OpenRgbWidget.qml`

**Interfaces:**
- Consumes: completed Task 1 QML and the current live `ii` configuration.
- Produces: a reloaded live widget plus `/tmp/openrgb-horizontal-pass1.png` and `/tmp/openrgb-horizontal-pass2.png` visual evidence.

- [ ] **Step 1: Preserve and update the live component**

Copy the current live `OpenRgbWidget.qml` to a timestamped sibling backup, then copy the worktree version into the same live path. Do not replace the live configuration directory or shared widget files.

- [ ] **Step 2: Reload Quickshell and check runtime output**

Run the existing `ii` reload command, wait for the shell to settle, and inspect its current log. Search for `OpenRgbWidget`, `TypeError`, `ReferenceError`, `binding loop`, and `Unable to assign`.

Expected: the shell loads and no new OpenRGB QML runtime errors appear.

- [ ] **Step 3: Capture and review pass one**

Run:

```bash
grim /tmp/openrgb-horizontal-pass1.png
```

Compare it with the supplied reference for: one-line silhouette, left power prominence, identity/divider grouping, centered mode and selection hierarchy, Apply separation, far-right power status, balanced vertical alignment, and absence of custom border glow. Record concrete discrepancies before editing.

- [ ] **Step 4: Apply first visual corrections**

Adjust only `OpenRgbWidget.qml` dimensions, spacing, typography, alignment, and token-based colors needed to resolve pass-one discrepancies. Redeploy that single file and reload Quickshell.

- [ ] **Step 5: Capture and review pass two**

Run:

```bash
grim /tmp/openrgb-horizontal-pass2.png
```

Compare again with the reference using the same checklist. Confirm no clipping at the configured live scale, long labels elide, all five regions remain legible, and the shared blur is the only surface effect.

- [ ] **Step 6: Apply only necessary final corrections and reverify**

If pass two identifies a concrete mismatch, correct it, redeploy, and reload. Then rerun:

```bash
node --test tests/openrgb-effects.test.js
python -m unittest tests/test_openrgb_power.py
git diff --check
```

Expected: all tests pass, the diff check is clean, the live widget loads without new errors, and the final composition matches the approved horizontal design.
