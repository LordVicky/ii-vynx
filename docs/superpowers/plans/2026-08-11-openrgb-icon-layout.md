# OpenRGB Icon Layout Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a persisted Icon layout that collapses to one circular lightbulb Power action and expands into Compact spindle controls on hover.

**Architecture:** Keep persisted layout selection separate from transient hover expansion. Pure functions in `OpenRgbLayout.js` normalize/cycle the three modes and calculate the active canvas; QML owns the `iconExpanded` state, delayed collapse timer, animation, and reusable Power component.

**Tech Stack:** QML/QtQuick, Quickshell, Node.js built-in test runner, Python `unittest`.

## Global Constraints

- Persisted cycle order is `card → spindle → icon → card`.
- Icon is `72 × 72` while collapsed and uses label-driven Compact width while expanded.
- The circular action uses `lightbulb`, retains Power styling, and calls `OpenRgb.toggleLights()`.
- Hovering never changes persisted layout, power, staging, or Apply state.
- Collapse delay is exactly `180ms` and re-entry cancels it.
- Card and Spindle behavior remain unchanged.

---

### Task 1: Three-layout geometry model

**Files:**
- Modify: `dots/.config/quickshell/ii/modules/ii/background/widgets/openrgb/OpenRgbLayout.js`
- Modify: `tests/openrgb-layout.test.js`

**Interfaces:**
- Produces: `normalizeLayout(value: string): string`.
- Produces: `nextLayout(value: string): string`.
- Produces: `widgetBaseWidth(mode: string, iconExpanded: boolean, spindleWidth: number): number`.
- Produces: `widgetBaseHeight(mode: string): number`.

- [ ] **Step 1: Write failing model tests**

Add assertions:

```js
assert.equal(layout.normalizeLayout("card"), "card");
assert.equal(layout.normalizeLayout("spindle"), "spindle");
assert.equal(layout.normalizeLayout("icon"), "icon");
assert.equal(layout.normalizeLayout("unknown"), "spindle");
assert.equal(layout.nextLayout("card"), "spindle");
assert.equal(layout.nextLayout("spindle"), "icon");
assert.equal(layout.nextLayout("icon"), "card");
assert.equal(layout.widgetBaseWidth("card", false, 360), 300);
assert.equal(layout.widgetBaseWidth("icon", false, 360), 72);
assert.equal(layout.widgetBaseWidth("icon", true, 360), 360);
assert.equal(layout.widgetBaseWidth("spindle", false, 360), 360);
assert.equal(layout.widgetBaseHeight("card"), 218);
assert.equal(layout.widgetBaseHeight("icon"), 72);
```

- [ ] **Step 2: Run the test and verify RED**

Run: `node --test tests/openrgb-layout.test.js`

Expected: FAIL because the four functions are absent.

- [ ] **Step 3: Implement the pure model**

Use a private `layoutOrder = ["card", "spindle", "icon"]`. Normalize unknown
values to `spindle`, cycle with modulo arithmetic, return `300` for Card, `72`
for collapsed Icon, and `spindleWidth` for Spindle/expanded Icon. Return `218`
for Card and `72` otherwise.

- [ ] **Step 4: Run the focused test and verify GREEN**

Run: `node --test tests/openrgb-layout.test.js`

Expected: PASS.

### Task 2: Hover-morphing Icon presentation

**Files:**
- Modify: `dots/.config/quickshell/ii/modules/ii/background/widgets/openrgb/OpenRgbWidget.qml`
- Modify: `tests/openrgb-layout.test.js`

**Interfaces:**
- Consumes: Task 1 layout functions.
- Produces: transient `iconExpanded` and `iconInteractionActive` properties.
- Produces: `scheduleIconCollapse()` and `cancelIconCollapse()`.
- Produces: reusable `PowerControl` component with required `glyph` property.

- [ ] **Step 1: Write failing QML source-contract tests**

Assert the widget contains:

```text
property bool iconExpanded: false
property bool iconInteractionActive: false
interval: 180
onContainsMouseChanged
OpenRgbLayout.normalizeLayout
OpenRgbLayout.nextLayout
OpenRgbLayout.widgetBaseWidth
OpenRgbLayout.widgetBaseHeight
component PowerControl
required property string glyph
glyph: "lightbulb"
onClicked: OpenRgb.toggleLights()
```

Also assert the Icon collapsed component does not contain selector or Apply
controls and the layout toggle is hidden until Icon is expanded.

- [ ] **Step 2: Run the source-contract test and verify RED**

Run: `node --test tests/openrgb-layout.test.js`

Expected: FAIL because Icon state and reusable Power control do not exist.

- [ ] **Step 3: Implement persisted mode and transient hover state**

Normalize `configEntry.layout` through `OpenRgbLayout.normalizeLayout()`. Change
`cycleLayout()` to write `OpenRgbLayout.nextLayout(root.layoutMode)`. Add a
`180ms` non-repeating timer. On pointer entry, stop the timer and set
`iconExpanded = true`; on exit, schedule collapse unless a control is pressed or
`dragScale >= 0`. Release/cancel handlers clear interaction state and schedule
collapse only when the pointer remains outside.

- [ ] **Step 4: Implement responsive canvas and loaders**

Bind card base width/height through `widgetBaseWidth()` and
`widgetBaseHeight()`. Use `72 / 2` corner radius outside Card. Load Card for
`card`, Compact spindle for `spindle` and expanded Icon, and a new icon-only
component for collapsed Icon. Fade Compact contents in with the existing fast
animation. Show the layout toggle for Icon only while expanded.

- [ ] **Step 5: Extract and reuse PowerControl**

Move the shared prominent circle, colors, pixel-snapped geometry, MouseArea,
and `OpenRgb.toggleLights()` call into `PowerControl`. Use
`glyph: "power_settings_new"` in Spindle and `glyph: "lightbulb"` in collapsed
and expanded Icon. Preserve Card's existing Power control.

- [ ] **Step 6: Run focused and full verification**

Run:

```bash
node --test tests/openrgb-layout.test.js
node --test tests/*.test.js
python -m unittest discover -s tests -p 'test_*.py'
git diff --check
```

Expected: all tests PASS and `git diff --check` prints nothing.

- [ ] **Step 7: Deploy and visually verify**

Back up the live QML, deploy `OpenRgbLayout.js` and `OpenRgbWidget.qml`, and
restart only the desktop `shell.qml` instance. Temporarily force Icon mode in
live QML without changing configuration. Verify collapsed circle, lightbulb
Power click target, smooth expansion, Compact controls, `180ms` delayed
collapse, and re-entry cancellation. Review twice across a reload, then restore
the production config-driven file and verify Card and Spindle.

- [ ] **Step 8: Commit implementation**

```bash
git add dots/.config/quickshell/ii/modules/ii/background/widgets/openrgb/OpenRgbLayout.js dots/.config/quickshell/ii/modules/ii/background/widgets/openrgb/OpenRgbWidget.qml tests/openrgb-layout.test.js
git commit -m "feat: add hover-expanding OpenRGB icon layout"
```
