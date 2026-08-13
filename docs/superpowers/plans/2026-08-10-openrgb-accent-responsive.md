# OpenRGB Accent and Responsive Spindle Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Align OpenRGB controls with the wallpaper-derived primary accent and make the spindle width respond to its staged label without wasted space.

**Architecture:** Keep all behavior in `OpenRgbWidget.qml`. Add a root `TextMetrics` measurement and clamped geometry properties, bind spindle dimensions/spacing to those values, and replace container-tone action colors with the same primary/secondary token hierarchy used by other widgets.

**Tech Stack:** Qt Quick/QML, ii-vynx Appearance tokens, Quickshell live configuration, Node.js/Python regressions, `grim` screenshots.

## Global Constraints

- Modify only `OpenRgbWidget.qml` for production behavior.
- Spindle width stays within `330–410` unscaled pixels.
- Spindle Apply is icon-only; card Apply retains its text.
- Primary actions use `colPrimary`/`colOnPrimary`; navigation uses secondary-container tokens.
- Keep the shared blur and OpenRGB behavior unchanged.

---

### Task 1: Responsive Spindle Geometry

**Files:**
- Modify: `dots/.config/quickshell/ii/modules/ii/background/widgets/openrgb/OpenRgbWidget.qml`

**Interfaces:**
- Produces: `stagedLabelMetrics`, `spindleBaseWidth`, `spindleOuterSpacing`, and `spindleSelectorSpacing`.
- Consumes: `root.currentLabel`, `root.layoutMode`, and `root.widgetScale`.

- [ ] **Step 1: Measure the unscaled staged label**

Add a root `TextMetrics` using pixel size `21`, `Font.DemiBold`, and `root.currentLabel`.

- [ ] **Step 2: Derive bounded geometry**

Add:

```qml
readonly property real spindleBaseWidth: Math.max(330, Math.min(410, 234 + stagedLabelMetrics.advanceWidth))
readonly property real spindleOuterSpacing: Math.max(3, Math.min(7, 3 + (spindleBaseWidth - 330) / 20))
readonly property real spindleSelectorSpacing: Math.max(4, Math.min(8, 4 + (spindleBaseWidth - 330) / 20))
```

Bind spindle card width to `spindleBaseWidth`, reduce spindle height to `88`, use the outer spacing in the top row, and use selector spacing around the name.

- [ ] **Step 3: Remove the spindle Apply caption**

Change `ApplyControl` to contain only its 50-pixel circular check control, reduce its layout footprint to 52 pixels, and leave the card's `Apply effect`/`Apply profile` text unchanged.

### Task 2: Theme Token Alignment

**Files:**
- Modify: `dots/.config/quickshell/ii/modules/ii/background/widgets/openrgb/OpenRgbWidget.qml`

**Interfaces:**
- Consumes: `Appearance.colors` primary and secondary token families.
- Produces: primary power/Apply/selected-tab styling and secondary navigation styling in both layouts.

- [ ] **Step 1: Correct primary actions**

Use `colPrimary`, `colPrimaryHover`, and `colOnPrimary` for enabled power buttons, Apply controls, card Apply bar, and selected mode tabs.

- [ ] **Step 2: Correct secondary controls**

Use `colSecondaryContainer`, `colSecondaryContainerHover`, and `colOnSecondaryContainer` in `ControlButton`, covering navigation and refresh without competing with Apply.

- [ ] **Step 3: Verify static regressions**

Run:

```bash
node --test tests/*.test.js
python -m unittest discover -s tests -p 'test_*.py'
git diff --check
```

Expected: two Node suites and seven Python tests pass; diff check is silent.

### Task 3: Live Visual Verification

**Files:**
- Deploy: `/home/lordvicky/.config/quickshell/ii/modules/ii/background/widgets/openrgb/OpenRgbWidget.qml`

**Interfaces:**
- Consumes: completed source QML.
- Produces: a live responsive spindle and verified card styling.

- [ ] **Step 1: Back up, deploy, and reload**

Preserve the current live QML, deploy the source file, reload `ii`, and confirm configuration loading.

- [ ] **Step 2: Review pass one**

Capture spindle and card views. Compare primary controls against Calendar, verify secondary arrow hierarchy, confirm Apply has no spindle caption, and measure visible dead space.

- [ ] **Step 3: Exercise responsive width and correct discrepancies**

Stage a short and long installed item without applying it. Capture both widths, confirm they remain within `330–410`, and correct only concrete geometry/token mismatches.

- [ ] **Step 4: Review pass two and final verification**

Capture both layouts again, rerun all tests and `git diff --check`, compare source/live QML, and search the current Quickshell log for OpenRGB-specific errors.
