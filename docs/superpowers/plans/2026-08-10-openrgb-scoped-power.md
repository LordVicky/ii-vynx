# OpenRGB Scoped Power Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Scope OpenRGB power-off to devices assigned to the last applied profile/effect and restore that exact item on power-on.

**Architecture:** Add a small Python helper that parses live OpenRGB device output and resolves device identities from Effects Plugin JSON or `.orp` bytes. `OpenRgb.qml` persists the last applied kind, invokes the helper for targeted black output, and reapplies the last active item when turning on.

**Tech Stack:** Python 3 standard library, QtQuick/QML, Quickshell `Process`, OpenRGB CLI, `busctl`, Node.js and Python tests.

## Global Constraints

- Power scope follows the last successfully applied item, never staged browsing state.
- WLED/E1.31 devices must be matched by their exact live location when available.
- An empty device match must fail without issuing an all-device color command.
- Power-on must reapply the last active profile or effect.
- Preserve unrelated dirty-worktree changes.

---

### Task 1: Assigned-device resolver

**Files:**
- Create: `dots/.config/quickshell/ii/services/OpenRgbPower.py`
- Create: `tests/test_openrgb_power.py`

**Interfaces:**
- Produces: `parse_devices(text) -> list[dict]`
- Produces: `effect_assignments(path) -> list[dict]`
- Produces: `match_effect_devices(assignments, devices) -> list[int]`
- Produces: `match_orp_devices(profile_bytes, devices) -> list[int]`
- Produces CLI: `OpenRgbPower.py off --kind {profile,effect} --selection PATH --service NAME --menu-path PATH --stop-id INT`

- [ ] **Step 1: Write failing tests** for live device parsing, exact WLED location matching, HID serial fallback, duplicate-zone deduplication, `.orp` embedded-name matching, and empty-scope failure.
- [ ] **Step 2: Run `python3 -m unittest tests/test_openrgb_power.py -v`** and confirm failure because the helper is absent.
- [ ] **Step 3: Implement pure parsing and matching functions** with identity priority: exact location, then exact serial, then name plus description.
- [ ] **Step 4: Implement the off CLI** to resolve current indices, stop plugin effects when applicable, and invoke one targeted OpenRGB command containing `--device INDEX --color 000000` for each resolved index.
- [ ] **Step 5: Run the Python tests** and confirm all cases pass.

### Task 2: Applied-kind state and restore behavior

**Files:**
- Modify: `dots/.config/quickshell/ii/modules/common/Config.qml`
- Modify: `dots/.config/quickshell/ii/services/OpenRgb.qml`

**Interfaces:**
- Consumes: `OpenRgbPower.py off`
- Produces: persisted `activeKind`, targeted `setLightsEnabled(false)`, and exact-item `setLightsEnabled(true)`

- [ ] **Step 1: Add `activeKind` to the OpenRGB config** with an empty default for existing users.
- [ ] **Step 2: Set `activeKind` only after successful profile/effect application.**
- [ ] **Step 3: Route power-off through the helper** using the active profile path or Effects Plugin profile file plus current D-Bus stop-action details.
- [ ] **Step 4: Route power-on by `activeKind`** to `applyEffect(activeEffect)` or `applyProfile(activeProfile)` and expose an error when the saved item no longer exists.
- [ ] **Step 5: Run all automated tests and `git diff --check`.**

### Task 3: Live deployment and verification

**Files:**
- Update matching files under `/home/lordvicky/.config/quickshell/ii/`

**Interfaces:**
- Consumes: completed helper and QML service
- Produces: reloaded live `ii` shell

- [ ] **Step 1: Resolve the applied effect's live device indices** and confirm its assigned WLED location maps to one current OpenRGB device.
- [ ] **Step 2: Back up and deploy only `Config.qml`, `OpenRgb.qml`, and `OpenRgbPower.py`.**
- [ ] **Step 3: Reload Quickshell and inspect fresh OpenRGB logs.**
- [ ] **Step 4: Verify source/live file equality and rerun both Python and Node test suites.**
