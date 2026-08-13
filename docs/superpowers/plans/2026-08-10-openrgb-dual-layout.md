# OpenRGB Dual-Layout Widget Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add persistent card/spindle switching to the OpenRGB widget and compact the spindle layout to power, selection, and Apply controls.

**Architecture:** Add one persisted `layout` property to the existing OpenRGB config. Keep all service state and actions at the widget root, select independent card/spindle visual components through a `Loader`, and overlay a music-style hover layout toggle.

**Tech Stack:** Qt Quick/QML, Quickshell JSON configuration, ii-vynx widget components and appearance tokens, Node.js/Python regression tests, `grim` visual verification.

## Global Constraints

- Persist only `card` or `spindle`; default to `spindle`.
- Use the existing widget blur/card mechanism exclusively.
- Spindle contains only power, mode/selection, and Apply.
- Spindle contains no identity block, device count, metadata row, light-status copy, status dots, or dividers.
- Use a `420 × 100` spindle canvas and the calendar-matching `0.8` wallpaper blur default.
- Card restores the prior `300 × 218` stacked control layout.
- Layout switching must never apply or discard a staged selection.
- Do not change OpenRGB backend behavior.

---

### Task 1: Persisted Layout State

**Files:**
- Modify: `dots/.config/quickshell/ii/modules/common/Config.qml`
- Modify: `dots/.config/quickshell/ii/modules/ii/background/widgets/openrgb/OpenRgbWidget.qml`

**Interfaces:**
- Produces: `Config.options.background.widgets.openRgb.layout: string`, `root.layoutMode: string`, and `root.cycleLayout(): void`.
- Consumes: existing `Config.options.background.widgets.openRgb` JSON object.

- [ ] **Step 1: Add the config property**

Add this beside the OpenRGB scale property:

```qml
property string layout: "spindle"
```

- [ ] **Step 2: Add validated widget state and switching**

Add:

```qml
readonly property string layoutMode: {
    const configured = Config.options.background.widgets.openRgb.layout ?? "spindle";
    return configured === "card" ? "card" : "spindle";
}

function cycleLayout() {
    Config.options.background.widgets.openRgb.layout = root.layoutMode === "spindle" ? "card" : "spindle";
}
```

- [ ] **Step 3: Bind dimensions and content to layout**

Bind card geometry to `layoutMode`, using `300 × 218` for card and `420 × 100` for spindle. Load `cardLayout` or `spindleLayout` through one `Loader` anchored to the card content.

### Task 2: Two Visual Components and Toggle

**Files:**
- Modify: `dots/.config/quickshell/ii/modules/ii/background/widgets/openrgb/OpenRgbWidget.qml`

**Interfaces:**
- Consumes: root staging/apply/power functions and `layoutMode` from Task 1.
- Produces: `cardLayout`, `spindleLayout`, and a hover-only toggle that calls `cycleLayout()`.

- [ ] **Step 1: Build the compact spindle component**

Use a 62-pixel circular power control with no status dot. Follow it directly with the flexible mode/selector block, then the Apply control. Delete the identity, device-count, connection/active metadata, lights-status, status-dot, and divider instances. Use small token-based gaps and preserve ordinary-length item names at the configured live scale.

- [ ] **Step 2: Restore the vertical card component**

Recreate the approved earlier `300 × 218` composition: identity/status/refresh, segmented mode switch, power plus selector, explicit Apply, active item, collection status, and light status. Reuse root actions so arrows stage only and Apply activates.

- [ ] **Step 3: Add music-style layout control**

Overlay a 16-pixel rounded button near the upper-right visible edge. Show it only on hover and while widgets are unlocked. Use `crop_16_9` in card mode and `dashboard` in spindle mode, and call `root.cycleLayout()` on click.

- [ ] **Step 4: Run static and behavior regressions**

Run:

```bash
node --test tests/*.test.js
python -m unittest discover -s tests -p 'test_*.py'
git diff --check
```

Expected: all tests pass and the diff check is silent.

### Task 3: Live Deployment and Two Visual Reviews

**Files:**
- Deploy: `/home/lordvicky/.config/quickshell/ii/modules/common/Config.qml`
- Deploy: `/home/lordvicky/.config/quickshell/ii/modules/ii/background/widgets/openrgb/OpenRgbWidget.qml`

**Interfaces:**
- Consumes: completed source configuration and QML.
- Produces: live persistent switching and screenshot evidence for both layouts.

- [ ] **Step 1: Back up and deploy only the two changed live files**

Preserve timestamped copies, copy the source versions, reload `ii`, and confirm `Configuration Loaded`.

- [ ] **Step 2: Review pass one**

Capture spindle and card screenshots. Check layout-toggle visibility, clipping, dead space, hierarchy, absence of removed spindle content, card completeness, and exclusive use of shared blur. Record concrete discrepancies.

- [ ] **Step 3: Correct pass-one discrepancies**

Change only QML geometry, typography, spacing, or toggle position; redeploy and reload.

- [ ] **Step 4: Review pass two**

Capture both layouts again. Confirm switching in both directions, persistence across reload, staging preservation, compact spindle width, and faithful card restoration.

- [ ] **Step 5: Final verification**

Rerun all Node/Python tests, `git diff --check`, compare source and live files, and search the current Quickshell log for OpenRGB-specific QML errors.
