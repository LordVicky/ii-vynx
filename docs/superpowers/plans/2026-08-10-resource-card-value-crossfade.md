# Resource Card Value Crossfade Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Crossfade changing Resource Monitor values with a snappy opacity-only transition.

**Architecture:** Add a focused `CrossfadeValueText.qml` component beside the Resource widget. It maintains outgoing and incoming text layers, swaps them with parallel opacity animations, and queues only the newest value when updates arrive mid-transition; `StatCard` consumes it without changing layout.

**Tech Stack:** QtQuick/QML, existing `StyledText` and `Appearance` animation tokens, Quickshell runtime validation.

## Global Constraints

- Duration is 130 ms.
- Animate opacity only; do not animate position, scale, blur, or individual digits.
- Initial values appear immediately.
- Labels, icons, card surfaces, and horizontal/vertical layout remain unchanged.

---

### Task 1: Crossfading resource values

**Files:**
- Create: `dots/.config/quickshell/ii/modules/ii/background/widgets/resources/CrossfadeValueText.qml`
- Modify: `dots/.config/quickshell/ii/modules/ii/background/widgets/resources/ResourcesWidget.qml`

**Interfaces:**
- Produces: `CrossfadeValueText.text: string`
- Produces: `CrossfadeValueText.pixelSize: real`
- Produces: `CrossfadeValueText.weight: int`
- Produces: `CrossfadeValueText.textColor: color`

- [ ] **Step 1: Establish the failing runtime check**

Run the live Resource widget before adding the component and confirm
`ResourcesWidget.qml` renders its value through plain `StyledText`, so value
changes replace text immediately with no transition.

- [ ] **Step 2: Implement the two-layer crossfade component**

Create two overlapping `StyledText` layers. On first assignment, show the value
immediately. On later changes, put the newest string on the hidden layer and run
parallel 130 ms opacity animations. If another update arrives while running,
retain it as the pending value and start one follow-up transition only when it
differs from the displayed value.

- [ ] **Step 3: Replace the Resource card value text**

Replace only the large value `StyledText` in `StatCard` with:

```qml
CrossfadeValueText {
    text: statCard.value
    pixelSize: Appearance.font.pixelSize.hugeass
    weight: Font.Bold
    textColor: Appearance.colors.colOnPrimaryContainer
}
```

- [ ] **Step 4: Verify syntax and runtime behavior**

Run `git diff --check`, launch the worktree shell with `qs -p .../shell.qml`,
and confirm it reaches `Configuration Loaded` without diagnostics from
`CrossfadeValueText.qml` or `ResourcesWidget.qml`.

- [ ] **Step 5: Commit and deploy**

Commit the two feature files, verify the live Resource widget file still
matches the prior branch revision, copy both files to the live Quickshell config,
and restart the live shell through its instance-specific Quickshell control.
