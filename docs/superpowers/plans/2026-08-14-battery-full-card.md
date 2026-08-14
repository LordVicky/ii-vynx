# Battery Full Card Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Simplify the full battery card and provide a reusable battery progress ring for current and future layouts.

**Architecture:** Add one presentation-only `BatteryProgressRing` component that owns the circular progress track and mutually exclusive centered icon/text content. `BatteryWidget` continues to own device state, coloring, selection, and layout; both existing layouts consume the shared visual component without changing service behavior.

**Tech Stack:** Qt 6 QML, Quickshell, existing `CircularProgress`, `TransformSafeSymbol`, and `TransformSafeText` components.

## Global Constraints

- Preserve device discovery, polling, click-to-refresh, compact-device selection, animations, and settings.
- Keep device-state decisions in `BatteryWidget.qml`; the shared component remains presentation-only.
- Preserve the compact layout's current dimensions, colors, icon, and behavior.
- Make each implementation stage a separate reversible commit on `dev`.

---

## File Structure

- Create `dots/.config/quickshell/ii/modules/ii/background/widgets/battery/BatteryProgressRing.qml`: reusable ring and centered icon/text renderer.
- Modify `dots/.config/quickshell/ii/modules/ii/background/widgets/battery/BatteryWidget.qml`: adopt the shared ring in compact mode, simplify full mode, and correct full-card height.

### Task 1: Shared Battery Progress Ring

**Files:**
- Create: `dots/.config/quickshell/ii/modules/ii/background/widgets/battery/BatteryProgressRing.qml`
- Modify: `dots/.config/quickshell/ii/modules/ii/background/widgets/battery/BatteryWidget.qml:551-596`

**Interfaces:**
- Consumes: `CircularProgress`, `TransformSafeSymbol`, `TransformSafeText`, and `Appearance` from existing common widget imports.
- Produces: `BatteryProgressRing` with `percentage: real`, `ringColor: color`, `ringSize: real`, `lineWidth: real`, `centerIcon: string`, `centerText: string`, and `scaleFactor: real` properties.

- [ ] **Step 1: Record the current compact implementation boundary**

Run:

```bash
sed -n '545,610p' dots/.config/quickshell/ii/modules/ii/background/widgets/battery/BatteryWidget.qml
```

Expected: one 56px item containing `CircularProgress` and `TransformSafeSymbol`.

- [ ] **Step 2: Create the shared component**

Create `BatteryProgressRing.qml` with this structure:

```qml
import QtQuick
import qs.modules.common
import qs.modules.common.widgets

Item {
    id: root

    property real percentage: 0
    property color ringColor: Appearance.colors.colPrimary
    property real ringSize: 56
    property real lineWidth: 5
    property string centerIcon: ""
    property string centerText: ""
    property real scaleFactor: 1

    implicitWidth: ringSize
    implicitHeight: ringSize

    CircularProgress {
        anchors.fill: parent
        implicitSize: root.ringSize
        lineWidth: root.lineWidth
        value: root.percentage
        colPrimary: root.ringColor
        colSecondary: Appearance.colors.colSecondaryContainer
    }

    TransformSafeSymbol {
        anchors.fill: parent
        visible: root.centerIcon.length > 0
        text: root.centerIcon
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        baseIconSize: Appearance.font.pixelSize.normal
        scaleFactor: root.scaleFactor
        color: root.ringColor
    }

    TransformSafeText {
        anchors.fill: parent
        visible: root.centerIcon.length === 0 && root.centerText.length > 0
        text: root.centerText
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        basePixelSize: Appearance.font.pixelSize.smallest
        scaleFactor: root.scaleFactor
        requestedWeight: Font.DemiBold
        color: root.ringColor
        fontSizeMode: Text.Fit
        minimumPixelSize: Appearance.font.pixelSize.smallest * root.scaleFactor
    }
}
```

- [ ] **Step 3: Replace the compact layout's inline ring**

Replace its 56px wrapper containing `CircularProgress` and `TransformSafeSymbol` with:

```qml
BatteryProgressRing {
    Layout.alignment: Qt.AlignVCenter
    ringSize: card.scaled(56)
    lineWidth: card.scaled(5)
    percentage: compactContent.animatedPercentage
    ringColor: compactContent.levelColor
    centerIcon: root.compactIcon
    scaleFactor: root.widgetScale
}
```

- [ ] **Step 4: Validate the shared component and compact migration**

Run:

```bash
git diff --check
rg -n "BatteryProgressRing|CircularProgress" dots/.config/quickshell/ii/modules/ii/background/widgets/battery
```

Expected: `CircularProgress` exists only inside `BatteryProgressRing.qml`; `BatteryWidget.qml` contains the compact `BatteryProgressRing` use.

- [ ] **Step 5: Commit the reusable component**

```bash
git add dots/.config/quickshell/ii/modules/ii/background/widgets/battery/BatteryProgressRing.qml dots/.config/quickshell/ii/modules/ii/background/widgets/battery/BatteryWidget.qml
git commit -m "refactor(battery): share progress ring component"
```

### Task 2: Minimal Full-Card Layout

**Files:**
- Modify: `dots/.config/quickshell/ii/modules/ii/background/widgets/battery/BatteryWidget.qml:38-39,315-545`

**Interfaces:**
- Consumes: Task 1's `BatteryProgressRing` interface.
- Produces: full-card rows with numeric progress rings and no header or aggregate charging footer.

- [ ] **Step 1: Update the authored full-card height**

Change:

```qml
readonly property real listAuthoredHeight: 88 + layoutRowCount * 44
```

to:

```qml
readonly property real listAuthoredHeight: 24 + layoutRowCount * 44
```

The formula is 32px total card padding plus `36 × rows` plus `8 × (rows - 1)` row spacing.

- [ ] **Step 2: Remove the redundant header**

Delete the first 36px `Item` inside the full-mode `ColumnLayout`, including the header battery symbol and `${deviceModel.count}` text.

- [ ] **Step 3: Replace each row's percentage text with the shared ring**

Replace the right-aligned `TransformSafeText` percentage with:

```qml
BatteryProgressRing {
    Layout.preferredWidth: card.scaled(root.rowHeight)
    Layout.preferredHeight: card.scaled(root.rowHeight)
    ringSize: card.scaled(root.rowHeight)
    lineWidth: card.scaled(3)
    percentage: deviceRow.animatedPercentage
    ringColor: deviceRow.percentageColor
    centerText: `${Math.round(deviceRow.animatedPercentage * 100)}`
    scaleFactor: root.widgetScale
}
```

Expected: the center reads `83`, not `83%`; charging, low, and normal state colors still come from `deviceRow.percentageColor`.

- [ ] **Step 4: Remove the aggregate charging footer**

Delete the `TransformSafeText` after `ListView` whose text is `1 charging` or `%1 charging`. Keep `chargingCount`, because it still controls state used elsewhere until a final dead-code check confirms otherwise.

- [ ] **Step 5: Remove dead header-only state if unused**

Run:

```bash
rg -n "chargingCount" dots/.config/quickshell/ii/modules/ii/background/widgets/battery/BatteryWidget.qml
```

If no visual or behavioral consumer remains, delete the `chargingCount` property. Do not remove any per-device charging properties.

- [ ] **Step 6: Run static and service checks**

```bash
git diff --check
pytest -q tests/test_apple_battery_status.py
rg -n '1 charging|%1 charging|text: `\\$\{deviceModel.count\}`' dots/.config/quickshell/ii/modules/ii/background/widgets/battery/BatteryWidget.qml
```

Expected: diff check and tests pass; the final search returns no matches.

- [ ] **Step 7: Deploy and inspect the live QML reload**

```bash
install -m 0644 dots/.config/quickshell/ii/modules/ii/background/widgets/battery/BatteryProgressRing.qml /home/lordvicky/.config/quickshell/ii/modules/ii/background/widgets/battery/BatteryProgressRing.qml
install -m 0644 dots/.config/quickshell/ii/modules/ii/background/widgets/battery/BatteryWidget.qml /home/lordvicky/.config/quickshell/ii/modules/ii/background/widgets/battery/BatteryWidget.qml
qs -c ii log | tail -120
```

Expected: Quickshell logs `Reloading configuration` and `Configuration Loaded`, with no error naming `BatteryProgressRing.qml` or `BatteryWidget.qml`. Visually confirm full rows are unclipped and compact mode is unchanged.

- [ ] **Step 8: Commit the full-card redesign**

```bash
git add dots/.config/quickshell/ii/modules/ii/background/widgets/battery/BatteryWidget.qml
git commit -m "feat(battery): simplify full card layout"
```

- [ ] **Step 9: Verify repository state**

```bash
git status -sb
git log -4 --oneline
```

Expected: clean `dev` worktree with two new implementation commits after the design commits.
