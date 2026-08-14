# Apple Device Glyphs Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Render dedicated monochrome iPhone, Apple Watch, and AirPods glyphs in both battery layouts.

**Architecture:** `BatteryDevices.qml` assigns an optional SVG filename from `deviceClass`. `BatteryWidget.qml` propagates that role and renders it in list rows, while `BatteryProgressRing.qml` accepts the same optional asset for compact mode.

**Tech Stack:** QML, SVG, Node.js test runner

## Global Constraints

- No Apple logo, model catalog, new service, or dependency.
- Preserve current Material-symbol fallbacks and charging behavior.

---

### Task 1: Add and render Apple device glyphs

**Files:**
- Create: `dots/.config/quickshell/ii/assets/icons/apple-iphone-symbolic.svg`
- Create: `dots/.config/quickshell/ii/assets/icons/apple-watch-symbolic.svg`
- Create: `dots/.config/quickshell/ii/assets/icons/apple-airpods-symbolic.svg`
- Modify: `dots/.config/quickshell/ii/modules/ii/background/widgets/battery/BatteryDevices.qml`
- Modify: `dots/.config/quickshell/ii/modules/ii/background/widgets/battery/BatteryWidget.qml`
- Modify: `dots/.config/quickshell/ii/modules/ii/background/widgets/battery/BatteryProgressRing.qml`
- Test: `tests/battery-device-config.test.js`

**Interfaces:**
- Produces: `customIcon: string` on each battery device model entry.
- Produces: `centerCustomIcon: string` on `BatteryProgressRing`.

- [x] **Step 1: Write the failing test**

Add a battery contract test that requires all three `deviceClass` mappings, propagation of `customIcon`, list rendering through `CustomIcon`, and compact rendering through `centerCustomIcon`.

- [x] **Step 2: Run test to verify it fails**

Run: `node --test tests/battery-device-config.test.js`

Expected: FAIL because `customIcon` and the three SVG mappings do not exist.

- [x] **Step 3: Write minimal implementation**

Add `appleCustomIcon(deviceClass)`, set `customIcon` on every device record, propagate it through `deviceModel`, and add colorized `CustomIcon` renderers. Create the three 24×24 monochrome SVGs.

- [x] **Step 4: Run focused and full tests**

Run: `node --test tests/battery-device-config.test.js`

Run: `node --test tests/*.test.js`

Expected: all tests PASS.

- [x] **Step 5: Install and commit**

Copy the six runtime files into `~/.config/quickshell/ii`, verify each with `cmp -s`, then commit the source, tests, assets, spec, and plan with `feat(battery): add Apple device glyphs`.
