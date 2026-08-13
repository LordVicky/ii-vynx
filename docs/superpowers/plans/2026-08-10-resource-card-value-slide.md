# Resource Card Value Slide Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the Resource Monitor fade-through with a clipped 4 px vertical slide-and-fade transition.

**Architecture:** Rename the animation component to `AnimatedValueText.qml` and restore two text layers, but keep them vertically separated throughout the transition. A clipped container prevents either layer from entering adjacent content; pending updates retain only the newest string.

**Tech Stack:** QtQuick/QML, existing `StyledText`, Quickshell runtime validation.

## Global Constraints

- Travel distance is exactly 4 px at the component's unscaled coordinate space.
- Duration is 140 ms.
- The value area clips animated text.
- Initial values appear immediately.
- No icon, label, card, or layout motion.

---

### Task 1: Vertical value transition

**Files:**
- Create: `dots/.config/quickshell/ii/modules/ii/background/widgets/resources/AnimatedValueText.qml`
- Delete: `dots/.config/quickshell/ii/modules/ii/background/widgets/resources/CrossfadeValueText.qml`
- Modify: `dots/.config/quickshell/ii/modules/ii/background/widgets/resources/ResourcesWidget.qml`

**Interfaces:**
- Produces: `AnimatedValueText.text: string`
- Produces: `AnimatedValueText.pixelSize: real`
- Produces: `AnimatedValueText.weight: int`
- Produces: `AnimatedValueText.textColor: color`

- [ ] **Step 1: Reproduce and establish the behavioral boundary**

Use the supplied recording and current component to confirm the fade-through
fully removes and then restores text, while the requested behavior keeps motion
continuous with two spatially separated strings.

- [ ] **Step 2: Implement the clipped two-layer transition**

Create a clipping root item with two `StyledText` layers. Set the outgoing layer
from `y: 0` to `y: -4` and opacity 1 to 0; set the incoming layer from `y: 4`
to `y: 0` and opacity 0 to 1. Run all four properties in one 140 ms parallel
animation using `Easing.OutCubic`. Retain the existing newest-pending-value
follow-up behavior.

- [ ] **Step 3: Rename the Resource widget usage**

Replace `CrossfadeValueText` with `AnimatedValueText`, preserving all typography
and color bindings.

- [ ] **Step 4: Validate and commit**

Run `git diff --check`, the existing network metric test, and a brief worktree
Quickshell launch. Require `Configuration Loaded` and no diagnostics naming the
two changed QML components. Commit only the renamed component and Resource widget.

- [ ] **Step 5: Deploy live**

Confirm the live files match the prior branch revision, copy the new component
and Resource widget, remove the obsolete live component, restart only the live
shell instance, and verify exactly one live shell remains.
