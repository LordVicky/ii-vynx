# Fake Screen Corners Toggle Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a persistent settings switch that fully withdraws fake monitor-edge rounding while preserving Hyprland window rounding and the selected fake-corner mode.

**Architecture:** Store one master boolean beside the existing fake-corner mode. Gate every surface and layout path that implements fake screen corners on that boolean, while leaving `sharpMode` and Hyprland settings untouched.

**Tech Stack:** QML, Quickshell JSON configuration, Node.js built-in test runner, Hyprland IPC.

## Global Constraints

- Preserve `appearance.fakeScreenRounding` while the master switch is disabled.
- Do not modify `appearance.sharpMode`, `appearance.defaultBorderRadius`, `appearance.toggleWindowRounding`, or `decoration:rounding`.
- Completely unmap `quickshell:screenCorners` and disable wrapped-frame layout while disabled.

---

### Task 1: Persist and expose the master switch

**Files:**
- Create: `tests/k4-fake-screen-corners-toggle.test.js`
- Modify: `dots/.config/quickshell/ii/modules/common/Config.qml`
- Modify: `dots/.config/quickshell/ii/modules/settings/QuickConfig.qml`

**Interfaces:**
- Produces: `Config.options.appearance.fakeScreenRoundingEnabled: bool`
- Consumes: existing `ConfigSwitch`, `fakeScreenRounding`, and `sharpMode` settings patterns

- [ ] **Step 1: Write the failing test**

Create a Node test that asserts `fakeScreenRoundingEnabled` defaults to `true`, the settings switch reads and writes only that property, and it does not call `HyprlandSettings.setRounding` or assign `sharpMode`.

- [ ] **Step 2: Run test to verify it fails**

Run: `node --test tests/k4-fake-screen-corners-toggle.test.js`

Expected: FAIL because `fakeScreenRoundingEnabled` and the switch do not exist.

- [ ] **Step 3: Write minimal implementation**

Add `property bool fakeScreenRoundingEnabled: true` beside `fakeScreenRounding`. Add an **Enable fake screen corners** `ConfigSwitch` whose checked handler assigns only `Config.options.appearance.fakeScreenRoundingEnabled`.

- [ ] **Step 4: Run test to verify it passes**

Run: `node --test tests/k4-fake-screen-corners-toggle.test.js`

Expected: PASS for persistence and settings wiring.

### Task 2: Gate every fake-edge implementation

**Files:**
- Modify: `tests/k4-fake-screen-corners-toggle.test.js`
- Modify: `dots/.config/quickshell/ii/modules/ii/screenCorners/ScreenCorners.qml`
- Modify: `dots/.config/quickshell/ii/modules/ii/wrappedFrame/WrappedFrame.qml`
- Modify: `dots/.config/quickshell/ii/panelFamilies/IllogicalImpulseFamily.qml`
- Modify: `dots/.config/quickshell/ii/modules/settings/QuickConfig.qml`

**Interfaces:**
- Consumes: `Config.options.appearance.fakeScreenRoundingEnabled`
- Produces: no fake corner surface, wrapped-frame loader, wrapped layout inset, or wrapped-only setting while disabled

- [ ] **Step 1: Extend the failing test**

Assert that `ScreenCorners.qml` includes the master boolean in `roundingWindowEnabled`, both wrapped-frame activation sites require the boolean, and the wrapped thickness control requires the boolean. Assert that the existing `fakeScreenRounding` mode value is never overwritten by the switch.

- [ ] **Step 2: Run test to verify it fails**

Run: `node --test tests/k4-fake-screen-corners-toggle.test.js`

Expected: FAIL because the rendering paths ignore the master boolean.

- [ ] **Step 3: Write minimal implementation**

Gate screen-corner mapping, wrapped-frame loading, wrapped layout selection, and wrapped-only settings visibility with `Config.options.appearance.fakeScreenRoundingEnabled`.

- [ ] **Step 4: Run focused and related tests**

Run: `node --test tests/k4-fake-screen-corners-toggle.test.js tests/k4-space-mode.test.js tests/k4-settings.test.js`

Expected: all tests PASS.

- [ ] **Step 5: Commit the implementation**

Commit the test and five QML changes with `feat(settings): add fake screen corners toggle`.

### Task 3: Deploy and verify live behavior

**Files:**
- Sync the five changed QML files from `dots/.config/quickshell/ii/` to `/home/lordvicky/.config/quickshell/ii/`

**Interfaces:**
- Consumes: the settings app and running shell's existing config-file watcher
- Produces: live corner withdrawal without changing Hyprland window rounding

- [ ] **Step 1: Record the current rounding value and corner layers**

Run `hyprctl getoption decoration:rounding` and inspect `hyprctl layers -j` for `quickshell:screenCorners`.

- [ ] **Step 2: Sync source files and reload Quickshell**

Copy only the five changed QML files to their matching live paths, then reload the shell through its existing Quickshell command.

- [ ] **Step 3: Exercise the toggle**

Set the new boolean to `false` through the persisted config path and confirm all `quickshell:screenCorners` surfaces disappear and wrapped-frame behavior is disabled. Restore the switch to the user's selected state only if the verification used a temporary value.

- [ ] **Step 4: Confirm window rounding is unchanged**

Run `hyprctl getoption decoration:rounding` again and require the value to match Step 1.
