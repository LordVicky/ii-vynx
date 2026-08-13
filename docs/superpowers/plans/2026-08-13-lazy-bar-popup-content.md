# Lazy Bar Popup Content Optimization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Prevent weather, vertical-clock, and system-tray overflow popup content from being instantiated while those popups are closed.

**Architecture:** Extend `StyledPopup` with an opt-in `Component lazyContent` while preserving its existing eager default property. Instantiate lazy content inside the already-lazy popup window and route sizing, hero discovery, animation, and placement through one `effectiveContentItem`. Adopt the capability in three independent consumer commits.

**Tech Stack:** Quickshell 0.3.0, QtQuick/QML, Wayland layer shell, Node.js built-in test runner, Linux `/proc`, `nvtop`.

## Global Constraints

- Work only on local branch `dev` in `/home/lordvicky/.git/ii-vynx`; do not push.
- Preserve default `StyledPopup` behavior for callers that do not opt in.
- Preserve popup geometry, animation, sticky-hover grace, tray focus behavior, visible controls, and compact-clock drag/drop.
- Do not modify persistent user configuration during automated validation.
- Do not include hidden-entry or `system_monitor_bar` cleanup.
- Review and verify each consumer separately and commit it independently.

---

### Task 1: Add the shared opt-in lazy-content seam

**Files:**
- Modify: `dots/.config/quickshell/ii/modules/ii/bar/StyledPopup.qml`
- Create: `tests/lazy-bar-popup-content.test.js`

**Interfaces:**
- Preserves: `default property Item contentItem`
- Produces: `property Component lazyContent: null`
- Produces: `readonly property Item effectiveContentItem`
- Produces: popup-window-local `Loader lazyContentLoader`, active only with a non-null lazy component

- [ ] **Step 1: Write the failing shared contract test**

Create `tests/lazy-bar-popup-content.test.js`:

```javascript
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");

const root = path.join(__dirname, "../dots/.config/quickshell/ii");
const read = relative => fs.readFileSync(path.join(root, relative), "utf8");

test("StyledPopup preserves eager content and offers opt-in lazy content", () => {
    const source = read("modules/ii/bar/StyledPopup.qml");
    assert.match(source, /default property Item contentItem/);
    assert.match(source, /property Component lazyContent:\s*null/);
    assert.match(source, /readonly property Item effectiveContentItem:/);
    assert.match(source, /id:\s*lazyContentLoader/);
    assert.match(source, /sourceComponent:\s*root\.lazyContent/);
});

test("lazy content is owned by the active popup window", () => {
    const source = read("modules/ii/bar/StyledPopup.qml");
    const componentBody = source.match(/component:\s*PanelWindow\s*\{([\s\S]*)\n\s*\}\s*$/)?.[1];
    assert.ok(componentBody, "popup PanelWindow body not found");
    assert.match(componentBody, /Loader\s*\{[\s\S]*?id:\s*lazyContentLoader/);
    assert.match(componentBody, /active:\s*root\.lazyContent\s*!==\s*null/);
});

test("popup sizing and placement use effective content", () => {
    const source = read("modules/ii/bar/StyledPopup.qml");
    assert.doesNotMatch(source, /root\.contentItem\?\.implicit/);
    assert.match(source, /root\.effectiveContentItem\?\.implicitWidth/);
    assert.match(source, /root\.effectiveContentItem\?\.implicitHeight/);
    assert.match(source, /root\.effectiveContentItem\.parent = contentContainer/);
});
```

- [ ] **Step 2: Verify red**

Run: `node --test tests/lazy-bar-popup-content.test.js`

Expected: FAIL because `lazyContent` and `effectiveContentItem` are absent.

- [ ] **Step 3: Implement the minimal shared seam**

In `StyledPopup.qml`, retain `default property Item contentItem` and add:

```qml
property Component lazyContent: null
readonly property Item effectiveContentItem: contentItem ?? item?.lazyContentItem ?? null
```

Inside the existing `component: PanelWindow`, add:

```qml
property alias lazyContentItem: lazyContentLoader.item

Loader {
    id: lazyContentLoader
    active: root.lazyContent !== null
    sourceComponent: root.lazyContent
}
```

Replace every sizing, hero-discovery, height-animation, and reparenting access to `root.contentItem` with `root.effectiveContentItem`. Do not alter `StyledPopup.active`, sticky timers, anchors, mask, or animation timing. The outer `LazyLoader` destroys the popup window and its inner loader when inactive.

- [ ] **Step 4: Verify shared behavior**

Run: `node --test tests/lazy-bar-popup-content.test.js`

Expected: 3 pass, 0 fail.

Run: `node --test tests/*.test.js`

Expected: all tests pass.

Run: `qmlformat-qt6 -i dots/.config/quickshell/ii/modules/ii/bar/StyledPopup.qml` and `git diff --check`.

Run a 10-second separate shell smoke test. Compare warnings to commit `3b8a978b`; require no new popup/type/reference/destroyed-object warning.

- [ ] **Step 5: Review and commit**

Confirm no production caller contains `lazyContent:` yet and the default eager API remains unchanged.

```bash
git add dots/.config/quickshell/ii/modules/ii/bar/StyledPopup.qml tests/lazy-bar-popup-content.test.js
git commit -m "feat: add opt-in lazy popup content"
```

---

### Task 2: Lazily instantiate weather forecast content

**Files:**
- Modify: `dots/.config/quickshell/ii/modules/ii/bar/weather/WeatherPopup.qml`
- Modify: `tests/lazy-bar-popup-content.test.js`

**Interfaces:**
- Consumes: `StyledPopup.lazyContent`
- Preserves: `WeatherPopup.compact`, popup hover target, current-weather bar display, and manual right-click refresh
- Produces: popup-lifetime forecast state and fetch process

- [ ] **Step 1: Add a failing weather contract**

Append a test that extracts `WeatherPopup.qml` and asserts:

```javascript
test("weather forecast work exists only inside lazy popup content", () => {
    const source = read("modules/ii/bar/weather/WeatherPopup.qml");
    assert.match(source, /lazyContent:\s*Component\s*\{/);
    const lazyBody = source.match(/lazyContent:\s*Component\s*\{([\s\S]*)\n\s*\}\s*\n\s*\}\s*$/)?.[1];
    assert.ok(lazyBody, "weather lazy content not found");
    assert.match(lazyBody, /Component\.onCompleted:\s*fetchForecast\(\)/);
    assert.match(lazyBody, /Process\s*\{/);
    assert.match(lazyBody, /HeroCard\s*\{/);
    assert.doesNotMatch(source.slice(0, source.indexOf("lazyContent:")), /Component\.onCompleted:\s*fetchForecast/);
});
```

- [ ] **Step 2: Verify red**

Run the focused test; expect the weather case to fail while Task 1 cases pass.

- [ ] **Step 3: Move weather-only work into lazy content**

Give the lazy component a root `ColumnLayout` that owns `forecastData`, `hourlyData`, loading state, computed models, formatting helpers, `fetchForecast()`, and `Process`. Move the existing hero/hourly/metrics/in-day cards into it without visual changes. Bind compact mode through the popup ID. Put `Component.onCompleted: fetchForecast()` on the lazy content root.

Do not move the compact weather icon/temperature in `WeatherBar.qml`, and do not change its right-click `Weather.getData()` behavior.

- [ ] **Step 4: Verify and smoke-test**

Run focused and full tests, format only `WeatherPopup.qml`, and run a separate shell for 10 seconds with the popup closed. Confirm no `wttr.in`/forecast child process starts while closed and no new QML warning appears.

Open the weather popup once by moving the pointer to its bar hitbox; confirm content renders and exactly one forecast process starts for that content lifetime. Close and reopen once.

- [ ] **Step 5: Review and commit**

```bash
git add dots/.config/quickshell/ii/modules/ii/bar/weather/WeatherPopup.qml tests/lazy-bar-popup-content.test.js
git commit -m "perf: lazy-load weather popup content"
```

---

### Task 3: Lazily instantiate clock popup content

**Files:**
- Modify: `dots/.config/quickshell/ii/modules/ii/bar/ClockWidgetPopup.qml`
- Modify: `tests/lazy-bar-popup-content.test.js`

**Interfaces:**
- Consumes: `StyledPopup.lazyContent`
- Preserves: `compact`, `stickyHover`, compact clock, `LocalSend` highlight connections, drag/drop, and hover target
- Produces: popup-lifetime derived todo/timer/date presentation

- [ ] **Step 1: Add a failing clock contract**

Assert that `ClockWidgetPopup.qml` supplies `lazyContent: Component`, keeps `stickyHover: true` on the outer popup, and places `HeroCard`, todo computation, and popup `ColumnLayout` inside lazy content.

- [ ] **Step 2: Verify red**

Run the focused test; expect only the clock case to fail.

- [ ] **Step 3: Move popup-only clock state and layout**

Move formatted date/time/uptime, todo derivation, timer-display helpers, day progress, stopwatch state, components, and the existing `ColumnLayout` into the lazy component root. Bind `compact` through the outer popup ID. Keep `stickyHover: true` on `ClockWidgetPopup` so the existing 100 ms crossing grace controls the whole lazy lifetime.

Do not modify `VerticalClockWidget.qml`; its `LocalSend` connections, `DropArea`, and `MouseArea` stay alive with the popup closed.

- [ ] **Step 4: Verify and smoke-test**

Run focused/full tests, format only `ClockWidgetPopup.qml`, and run a separate shell. Open the clock popup, cross the pointer into it, wait longer than 100 ms while hovering it, and confirm it remains. Exit both regions and confirm it closes; reopen once. Check no new destroyed-object or binding warning.

- [ ] **Step 5: Review and commit**

```bash
git add dots/.config/quickshell/ii/modules/ii/bar/ClockWidgetPopup.qml tests/lazy-bar-popup-content.test.js
git commit -m "perf: lazy-load clock popup content"
```

---

### Task 4: Lazily instantiate system-tray overflow content

**Files:**
- Modify: `dots/.config/quickshell/ii/modules/ii/bar/SysTray.qml`
- Modify: `tests/lazy-bar-popup-content.test.js`

**Interfaces:**
- Consumes: `StyledPopup.lazyContent`
- Preserves: pinned icons, item activation, `SysTrayItem` right-click loader, pinning, `trayOverflowOpen`, and `HyprlandFocusGrab`
- Produces: popup-lifetime unpinned-item grid

- [ ] **Step 1: Add a failing tray contract**

Assert that the overflow `StyledPopup` uses `lazyContent: Component`, the unpinned-item `Repeater` is inside it, pinned-items `Repeater` remains outside it, and `SysTrayItem.qml` retains `Loader { id: menu; active: false }`.

- [ ] **Step 2: Verify red**

Run the focused test; expect only the tray case to fail.

- [ ] **Step 3: Move only overflow grid to lazy content**

Replace the eager child `GridLayout` with:

```qml
lazyContent: Component {
    GridLayout {
        id: trayOverflowLayout
        columns: Math.ceil(Math.sqrt(root.unpinnedItems.length))
        columnSpacing: 10
        rowSpacing: 10
        Repeater {
            model: root.unpinnedItems
            delegate: SysTrayItem { /* preserve current bindings and handlers */ }
        }
    }
}
```

Expose the lazy content window to `HyprlandFocusGrab` through the existing popup loader/window reference, using a null-safe binding. Do not modify the pinned repeater or `SysTrayItem.qml` menu loader.

- [ ] **Step 4: Verify and smoke-test**

Run focused/full tests, format `SysTray.qml`, and launch a separate shell. Verify pinned item activation and right-click menu, open overflow, open one unpinned item menu if available, close by focus loss, and reopen. Require no new focus-grab, null-reference, or destroyed-object warning.

- [ ] **Step 5: Review and commit**

```bash
git add dots/.config/quickshell/ii/modules/ii/bar/SysTray.qml tests/lazy-bar-popup-content.test.js
git commit -m "perf: lazy-load tray overflow content"
```

---

### Task 5: Run live A/B validation and decide

**Files:**
- Create: `docs/performance/2026-08-13-lazy-bar-popup-content-results.md`

**Interfaces:**
- Consumes: baseline `3b8a978b` and the Task 4 candidate commit
- Produces: raw samples, medians, per-popup lifecycle evidence, warnings, and accept/reject decision

- [ ] **Step 1: Protect state and request interruption approval**

Record the production PID/command, config SHA-256, monitor geometry, and clean git status. Ask before stopping production `qs -c ii`.

- [ ] **Step 2: Collect alternating closed-popup samples**

Use fresh exact-commit checkouts and run A, B, B, A, A, B with equal warm-up. For each exact PID record `smaps_rollup`, `ps`, `nvtop --snapshot`, relevant child processes, and logs. Confirm all three target popups remain closed.

- [ ] **Step 3: Exercise popup lifecycles**

On candidate, capture PSS/RSS/VRAM before open, while open, and after close for weather, clock, and tray overflow separately. Exercise the runtime seams in the specification and record every pass/fail.

- [ ] **Step 4: Restore and analyze**

Restore the exact production command even on failure. Verify config hash and no temporary process. Report median candidate changes without summing overlapping popup deltas. Accept only with all behavior checks passing and a repeatable closed-popup improvement; missing the 8–15 MiB PSS target requires user review.

- [ ] **Step 5: Commit reviewed evidence**

After the user accepts or rejects the candidate, commit the evidence document with the explicit decision. Revert only failed consumer commits if a subset is retained.

---

## Final verification gate

Run fresh:

```bash
node --test tests/*.test.js
git diff --check
git status --short --branch
git log -10 --oneline --decorate
sha256sum ~/.config/illogical-impulse/config.json
pgrep -a -f '(^|/)qs -c ii($| )'
```

Require zero failures, clean local `dev`, no push, unchanged persistent configuration, restored production shell, and an evidence-backed decision for each consumer.
