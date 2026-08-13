# Resource and Network Widget Merge Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a configurable single-value Network card to the Resource Monitor and retire the standalone Network desktop widget.

**Architecture:** Extend the existing background `resources` configuration with a display mode and polling interval. The Resource widget activates the shared network sampler, selects download/upload/total throughput declaratively, and renders it through the existing `StatCard`; the shared network service accepts a widget-specific interval while that consumer is active.

**Tech Stack:** QtQuick/QML, Quickshell singletons, `JsonObject` configuration, shell-based static contract checks.

## Global Constraints

- The card label is always `Network`.
- `networkMode` is exactly `download`, `upload`, or `total`, defaulting to `total`.
- `total` is current download throughput plus current upload throughput.
- Horizontal mode is one row of four cards; vertical mode is one column of four cards.
- Preserve unrelated dirty-worktree changes, especially current visual tuning.

---

### Task 1: Configuration and settings contract

**Files:**
- Create: `tests/resource-network-merge-contract.sh`
- Modify: `dots/.config/quickshell/ii/modules/common/Config.qml`
- Modify: `dots/.config/quickshell/ii/modules/settings/BackgroundConfig.qml`

**Interfaces:**
- Produces: `Config.options.background.widgets.resources.networkMode: string`
- Produces: `Config.options.background.widgets.resources.pollingInterval: int`

- [ ] **Step 1: Write a failing static contract test**

Create an executable shell test that asserts the resources JSON object contains
`networkMode: "total"` and `pollingInterval: 3000`, Background settings bind a
three-choice control to `networkMode`, and a spin box binds to
`pollingInterval`.

- [ ] **Step 2: Verify the contract test fails**

Run: `bash tests/resource-network-merge-contract.sh`

Expected: FAIL because the two resource-widget properties and controls do not exist.

- [ ] **Step 3: Add config defaults and Resource widget controls**

Add these exact properties to the background resource widget object:

```qml
property string networkMode: "total"
property int pollingInterval: 3000
```

Extend `DesktopWidgetToggle` with an optional custom-content slot or add a
resource-specific subsection immediately after its toggle, following existing
`ConfigSelectionArray` and `ConfigSpinBox` patterns. Choices are Download,
Upload, and Total; polling bounds are 100–10000 ms in 100 ms steps.

- [ ] **Step 4: Verify the config/settings contract passes**

Run: `bash tests/resource-network-merge-contract.sh`

Expected: PASS for config defaults and settings bindings.

- [ ] **Step 5: Commit the configuration slice**

```bash
git add tests/resource-network-merge-contract.sh dots/.config/quickshell/ii/modules/common/Config.qml dots/.config/quickshell/ii/modules/settings/BackgroundConfig.qml
git commit -m "feat(resources): add network display settings"
```

### Task 2: Resource widget network card

**Files:**
- Modify: `tests/resource-network-merge-contract.sh`
- Modify: `dots/.config/quickshell/ii/modules/ii/background/widgets/resources/ResourcesWidget.qml`
- Modify: `dots/.config/quickshell/ii/services/NetworkUsage.qml`

**Interfaces:**
- Consumes: `networkMode` and `pollingInterval` from Task 1.
- Produces: `NetworkUsage.resourceWidgetInstances: int`
- Produces: `NetworkUsage.resourceWidgetPollingInterval: int`

- [ ] **Step 1: Extend the test with failing runtime-structure assertions**

Assert that ResourcesWidget activates/deactivates the network consumer, formats
B/s, KB/s, and MB/s, chooses download/upload/sum according to `networkMode`,
renders a fourth `StatCard` labeled `Network`, and uses four grid rows/columns.
Assert NetworkUsage switches its timer interval to the widget polling interval
while `resourceWidgetInstances > 0`.

- [ ] **Step 2: Verify the new assertions fail**

Run: `bash tests/resource-network-merge-contract.sh`

Expected: FAIL at the first missing Resource widget network assertion.

- [ ] **Step 3: Implement shared sampling and the fourth card**

In NetworkUsage add widget-consumer properties and use this interval binding:

```qml
interval: root.resourceWidgetInstances > 0
    ? root.resourceWidgetPollingInterval
    : Config.options.bar.networkSpeed.updateInterval
```

In ResourcesWidget increment/decrement both the general active count and widget
consumer count over component lifetime, set the widget polling interval from
config, implement `formatSpeed(bytesPerSecond)`, derive the selected speed, make
the Grid 4×1 or 1×4, and append a normal `StatCard` with label `Network`.

- [ ] **Step 4: Verify the resource-card contract passes**

Run: `bash tests/resource-network-merge-contract.sh`

Expected: PASS.

- [ ] **Step 5: Commit the widget slice**

```bash
git add tests/resource-network-merge-contract.sh dots/.config/quickshell/ii/modules/ii/background/widgets/resources/ResourcesWidget.qml dots/.config/quickshell/ii/services/NetworkUsage.qml
git commit -m "feat(resources): integrate network throughput card"
```

### Task 3: Remove the standalone Network widget

**Files:**
- Modify: `tests/resource-network-merge-contract.sh`
- Modify: `dots/.config/quickshell/ii/modules/ii/background/Background.qml`
- Modify: `dots/.config/quickshell/ii/modules/settings/BackgroundConfig.qml`

**Interfaces:**
- Consumes: integrated Resource Monitor from Task 2.
- Produces: no standalone Network widget loader or settings toggle.

- [ ] **Step 1: Add failing absence assertions**

Assert Background.qml does not instantiate `NetworkWidget`, and BackgroundConfig
does not contain `widgetKey: "network"`.

- [ ] **Step 2: Verify the absence assertions fail**

Run: `bash tests/resource-network-merge-contract.sh`

Expected: FAIL because the old loader and toggle remain.

- [ ] **Step 3: Remove only the old loader and toggle**

Delete the Network `FadeLoader` block from Background.qml and the Network
`DesktopWidgetToggle` block from BackgroundConfig.qml. Keep the legacy config
object and QML component file for backward compatibility and to avoid deleting
a user-modified file.

- [ ] **Step 4: Run focused and formatting checks**

Run:

```bash
bash tests/resource-network-merge-contract.sh
git diff --check
```

Expected: contract PASS and no whitespace errors.

- [ ] **Step 5: Commit removal**

```bash
git add tests/resource-network-merge-contract.sh dots/.config/quickshell/ii/modules/ii/background/Background.qml dots/.config/quickshell/ii/modules/settings/BackgroundConfig.qml
git commit -m "refactor(background): retire standalone network widget"
```

### Task 4: End-to-end verification

**Files:**
- Verify: all files changed by Tasks 1–3

**Interfaces:**
- Consumes: completed merged Resource Monitor.
- Produces: verification evidence only.

- [ ] **Step 1: Run the complete contract and focused diff checks**

```bash
bash tests/resource-network-merge-contract.sh
git diff --check HEAD~3..HEAD
git status --short
```

Expected: contract PASS; no whitespace errors; unrelated pre-existing changes remain untouched.

- [ ] **Step 2: Run available QML validation**

Run `command -v qmllint` and, when present, run qmllint against Config.qml,
BackgroundConfig.qml, ResourcesWidget.qml, NetworkUsage.qml, and Background.qml.
If imports prevent isolated validation, record the exact diagnostics and rely on
the contract check plus runtime validation.

- [ ] **Step 3: Attempt runtime visual validation**

Launch `qs -c ii settings.qml` and inspect the Resource widget controls. When a
Quickshell/Hyprland graphical session is unavailable, report that limitation
instead of claiming visual validation.
