# OpenRGB Card Footer Removal Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove all persistent metadata beneath the OpenRGB card controls and delete its layout code.

**Architecture:** Keep backend status properties intact because header/error behavior and other layouts may consume them. Remove only the card-layout text components and footer row, then let the existing `ColumnLayout` allocate the freed space to its control region.

**Tech Stack:** QML/QtQuick, Node.js built-in test runner, Python `unittest`.

## Global Constraints

- Remove “Currently active,” collection/plugin status, and “Lights on/off” from card mode.
- Preserve the `300 × 218` canvas, header status/error text, controls, behavior, colors, and blur.
- Do not alter spindle mode.

---

### Task 1: Remove card footer metadata

**Files:**
- Modify: `tests/openrgb-layout.test.js`
- Modify: `dots/.config/quickshell/ii/modules/ii/background/widgets/openrgb/OpenRgbWidget.qml`

**Interfaces:**
- Consumes: existing `cardLayout` source-contract extraction.
- Produces: card layout with no `Currently active`, `collectionStatus`, or lights-state text bindings.

- [ ] Add failing assertions that `cardLayout` does not contain `Currently active`, `Nothing applied yet`, `root.collectionStatus`, or the lights-state ternary.
- [ ] Run `node --test tests/openrgb-layout.test.js`; expect failure on the current footer code.
- [ ] Delete the active-state `TransformSafeText` and the complete bottom `RowLayout`; leave header status handling intact.
- [ ] Run focused and full tests, then `git diff --check`.
- [ ] Back up and deploy `OpenRgbWidget.qml`, reload Quickshell, and inspect the card layout and logs.
- [ ] Confirm spindle mode remains unchanged, then commit the QML and test.
