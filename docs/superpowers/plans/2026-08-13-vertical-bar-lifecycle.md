# Vertical Bar Lifecycle Optimization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Unload the full Illogical Impulse vertical bar after 20 seconds hidden in auto-hide mode while retaining a minimal, reliable edge activation surface.

**Architecture:** Keep `VerticalBar.qml` loaded as the stable IPC/shortcut boundary. Each monitor variant owns a lightweight controller, an edge-trigger window, and a `LazyLoader` containing the existing full bar. Put deterministic lifecycle decisions in a small JavaScript policy module so they can be tested without Wayland.

**Tech Stack:** Quickshell 0.3.0, QtQuick/QML, Wayland layer shell, Node.js test runner, Linux `/proc`, `nvtop`.

## Global Constraints

- Work only on local branch `dev` in `/home/lordvicky/.git/ii-vynx`; do not push.
- Do not change horizontal-bar or Waffle-family behavior.
- Do not modify `~/.config/illogical-impulse/config.json` during automated validation.
- Preserve IPC, shortcuts, monitor filtering, locking, placement, exclusive zones, focus grabs, pointer reveal, and Super reveal.
- Keep auto-hide-disabled vertical bars fully loaded.
- Review and verify each diff before committing it.
- Use one local commit per task so each change can be reverted independently.

---

### Task 1: Add and verify the lifecycle policy

**Files:**
- Create: `dots/.config/quickshell/ii/modules/ii/verticalBar/VerticalBarLifecycle.js`
- Create: `tests/vertical-bar-lifecycle.test.js`

**Interfaces:**
- Produces: `activationWidth(configuredWidth: number): number`
- Produces: `shouldKeepTrigger(autoHideEnabled: boolean, barOpen: boolean, screenLocked: boolean): boolean`
- Produces: `shouldLoadFullBar(autoHideEnabled: boolean, revealRequested: boolean, barOpen: boolean, screenLocked: boolean): boolean`

- [ ] **Step 1: Write the failing test**

Create `tests/vertical-bar-lifecycle.test.js`:

```javascript
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");
const vm = require("node:vm");

const sourcePath = path.join(__dirname,
    "../dots/.config/quickshell/ii/modules/ii/verticalBar/VerticalBarLifecycle.js");
const lifecycle = {};
vm.createContext(lifecycle);
vm.runInContext(fs.readFileSync(sourcePath, "utf8"), lifecycle, { filename: sourcePath });

test("activation surface is at least two logical pixels", () => {
    assert.equal(lifecycle.activationWidth(-5), 2);
    assert.equal(lifecycle.activationWidth(0), 2);
    assert.equal(lifecycle.activationWidth(1), 2);
    assert.equal(lifecycle.activationWidth(8), 8);
});

test("trigger exists only for an open unlocked auto-hidden bar", () => {
    assert.equal(lifecycle.shouldKeepTrigger(true, true, false), true);
    assert.equal(lifecycle.shouldKeepTrigger(false, true, false), false);
    assert.equal(lifecycle.shouldKeepTrigger(true, false, false), false);
    assert.equal(lifecycle.shouldKeepTrigger(true, true, true), false);
});

test("always-visible mode keeps the full bar loaded", () => {
    assert.equal(lifecycle.shouldLoadFullBar(false, false, true, false), true);
});

test("auto-hide mode loads only on demand", () => {
    assert.equal(lifecycle.shouldLoadFullBar(true, false, true, false), false);
    assert.equal(lifecycle.shouldLoadFullBar(true, true, true, false), true);
});

test("closed or locked bars never retain the full window", () => {
    assert.equal(lifecycle.shouldLoadFullBar(false, true, false, false), false);
    assert.equal(lifecycle.shouldLoadFullBar(false, true, true, true), false);
});
```

- [ ] **Step 2: Verify red**

Run: `node --test tests/vertical-bar-lifecycle.test.js`

Expected: FAIL with `ENOENT` for `VerticalBarLifecycle.js`.

- [ ] **Step 3: Add the minimal implementation**

Create `VerticalBarLifecycle.js`:

```javascript
function activationWidth(configuredWidth) {
    return Math.max(2, Number(configuredWidth) || 0);
}

function shouldKeepTrigger(autoHideEnabled, barOpen, screenLocked) {
    return autoHideEnabled && barOpen && !screenLocked;
}

function shouldLoadFullBar(autoHideEnabled, revealRequested, barOpen, screenLocked) {
    return barOpen && !screenLocked && (!autoHideEnabled || revealRequested);
}
```

- [ ] **Step 4: Verify green and commit**

Run: `node --test tests/vertical-bar-lifecycle.test.js`

Expected: 5 pass, 0 fail.

Run: `git diff --check`

Review: `git diff -- VerticalBarLifecycle.js tests/vertical-bar-lifecycle.test.js`

```bash
git add dots/.config/quickshell/ii/modules/ii/verticalBar/VerticalBarLifecycle.js tests/vertical-bar-lifecycle.test.js
git commit -m "test: define vertical bar lifecycle policy"
```

---

### Task 2: Integrate the unloadable full bar

**Files:**
- Modify: `dots/.config/quickshell/ii/modules/ii/verticalBar/VerticalBar.qml`
- Modify: `tests/vertical-bar-lifecycle.test.js`

**Interfaces:**
- Consumes: the three Task 1 policy functions
- Preserves: IPC `toggle()`, `close()`, `open()` and shortcuts `barToggle`, `barOpen`, `barClose`
- Produces: per-monitor `triggerHovered`, `fullBarHovered`, `superShow`, and `revealRequested` state

- [ ] **Step 1: Add a failing static integration contract**

Append:

```javascript
test("QML separates the edge trigger from the full-window loader", () => {
    const qml = fs.readFileSync(path.join(__dirname,
        "../dots/.config/quickshell/ii/modules/ii/verticalBar/VerticalBar.qml"), "utf8");
    assert.match(qml, /import "VerticalBarLifecycle\.js" as Lifecycle/);
    assert.match(qml, /id:\s*edgeTriggerLoader/);
    assert.match(qml, /id:\s*fullBarLoader/);
    assert.match(qml, /Lifecycle\.shouldKeepTrigger\(/);
    assert.match(qml, /Lifecycle\.shouldLoadFullBar\(/);
    assert.match(qml, /id:\s*unloadTimer[\s\S]*?interval:\s*20000/);
});

test("bar public controls remain available", () => {
    const qml = fs.readFileSync(path.join(__dirname,
        "../dots/.config/quickshell/ii/modules/ii/verticalBar/VerticalBar.qml"), "utf8");
    assert.match(qml, /target:\s*"bar"/);
    for (const handler of ["toggle", "close", "open"])
        assert.match(qml, new RegExp(`function ${handler}\\(\\): void`));
    for (const shortcut of ["barToggle", "barOpen", "barClose"])
        assert.match(qml, new RegExp(`name: "${shortcut}"`));
});
```

- [ ] **Step 2: Verify red**

Run: `node --test tests/vertical-bar-lifecycle.test.js`

Expected: five policy tests pass; the QML integration contract fails.

- [ ] **Step 3: Add the per-monitor controller**

Import `VerticalBarLifecycle.js` as `Lifecycle`. Replace only the delegate surrounding the existing full-window body with an `Item` that keeps lifecycle state outside the unloadable window:

```qml
Item {
    id: controller
    required property ShellScreen modelData
    property int monitorIndex: barVariant.variantModel.indexOf(controller.modelData)
    property bool triggerHovered: false
    property bool fullBarHovered: false
    property bool superShow: false
    property bool revealRequested: triggerHovered || fullBarHovered
        || superShow || unloadTimer.running

    function cancelUnload() { unloadTimer.stop(); }
    function scheduleUnload() {
        if (!Config.options.bar.autoHide.enable || triggerHovered
                || fullBarHovered || superShow)
            return;
        unloadTimer.restart();
    }

    Timer { id: unloadTimer; interval: 20000; repeat: false }
    Component.onCompleted: scheduleUnload()
}
```

Move the existing Super delay timer and `GlobalStates.superDown` connection to the controller. Super activation sets `superShow` and cancels unloading; release clears it and schedules unloading.

- [ ] **Step 4: Add the minimal edge trigger**

Add `edgeTriggerLoader`, active through `Lifecycle.shouldKeepTrigger(...)`. Its `PanelWindow` binds the controller screen, anchors to the configured left/right edge plus top/bottom, uses `exclusiveZone: 0`, transparent color, and width `Lifecycle.activationWidth(Config.options.bar.autoHide.hoverRegionWidth)`. Its masked filling `MouseArea` updates `triggerHovered`, cancels unloading on entry, and schedules unloading on exit. It must contain no bar content, services, shadows, or decorators.

- [ ] **Step 5: Lazy-load the preserved full window**

Put the existing full `PanelWindow` body inside `fullBarLoader`, active through:

```qml
Lifecycle.shouldLoadFullBar(Config.options.bar.autoHide.enable,
    controller.revealRequested, GlobalStates.barOpen, GlobalStates.screenLocked)
```

Change only ownership references: screen and monitor index come from `controller`; Super state comes from `controller.superShow`; full-bar hover updates `controller.fullBarHovered` and controls the unload timer. The completion hook starts the initial 20-second grace period, so a newly started auto-hidden shell follows the existing visible-to-hidden transition before its first unload. Preserve exclusive-zone, mask, animation, `VerticalBarContent`, decorators, and `GlobalFocusGrab` logic unchanged. When auto-hide turns off, cancel unloading. Do not add a config property.

- [ ] **Step 6: Verify integration**

Run: `node --test tests/vertical-bar-lifecycle.test.js`

Expected: 7 pass, 0 fail.

Run: `node --test tests/*.test.js`

Expected: all JavaScript tests pass.

Run: `timeout 15s qs -p dots/.config/quickshell/ii/shell.qml 2>&1 | tee /tmp/ii-vynx-vertical-bar-smoke.log`

Expected: no new vertical-bar, binding-loop, type, reference, or component-creation errors. Timeout is acceptable for a long-running shell.

- [ ] **Step 7: Review and commit**

Run `git diff --check`, `git diff --stat`, and inspect the full QML/test diff. Confirm no unrelated file or persistent config changed.

```bash
git add dots/.config/quickshell/ii/modules/ii/verticalBar/VerticalBar.qml tests/vertical-bar-lifecycle.test.js
git commit -m "perf: unload auto-hidden vertical bar"
```

---

### Task 3: Validate live behavior and A/B resources

**Files:**
- Create: `docs/performance/2026-08-13-vertical-bar-lifecycle-results.md`

**Interfaces:**
- Consumes: baseline `c1282552` and the Task 2 candidate commit
- Produces: raw alternating samples, medians, behavior results, and accept/reject decision

- [ ] **Step 1: Protect state**

Record `sha256sum ~/.config/illogical-impulse/config.json`, the exact production `qs` PID/command, and clean git status.

- [ ] **Step 2: Obtain live-test approval**

Before restarting/replacing production `qs -c ii`, ask the user because the visible shell may briefly disappear. Record its command for restoration.

- [ ] **Step 3: Exercise behavior**

On every configured monitor test edge reveal, normal hiding, reveal after the 20-second unload, configured Super reveal, IPC open/close/toggle, lock/unlock, runtime auto-hide off/on, and configured left/right placement. Capture logs and record each outcome.

- [ ] **Step 4: Collect alternating A/B samples**

Use temporary exact-commit checkouts without changing `dev`. Run at least A, B, B, A, A, B with identical warm-up and five reveal/hide cycles. For the exact launched PID record `/proc/<pid>/smaps_rollup`, `ps -p <pid> -o pid=,%cpu=,rss=,etimes=,args=`, and `nvtop --snapshot`. Never sum thread rows.

- [ ] **Step 5: Analyze acceptance**

Record every raw sample; median unloaded PSS/RSS/VRAM; candidate revealed PSS/VRAM; average and peak GPU/CPU; whether allocations fall after 20 seconds; behavior results; and QML warnings. Accept only if behavior passes and unloaded PSS improves repeatedly beyond variance. Otherwise recommend reverting Task 2.

- [ ] **Step 6: Review results and commit**

Verify the persistent-config hash is unchanged and production shell restored. Review results with the user before deciding. If accepted:

```bash
git add docs/performance/2026-08-13-vertical-bar-lifecycle-results.md
git commit -m "docs: record vertical bar resource results"
```

If rejected, preserve the measurements, request review, and revert only the Task 2 commit.

---

## Final verification gate

Run fresh:

```bash
node --test tests/*.test.js
git diff --check
git status --short --branch
git log -4 --oneline --decorate
```

Confirm zero test failures, clean worktree, separate local commits on `dev`, no push, unchanged live config, restored production shell, and evidence-backed resource results.
