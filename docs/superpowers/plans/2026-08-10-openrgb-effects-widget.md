# OpenRGB Effects Widget Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add refreshable OpenRGB Effects Plugin discovery and explicit, staged profile/effect activation to the desktop widget.

**Architecture:** Extend the existing `OpenRgb` QML singleton to discover the live OpenRGB StatusNotifierItem and parse its D-Bus menu JSON. Keep active and staged selections separate in the widget; only an explicit Apply action invokes OpenRGB or the plugin menu.

**Tech Stack:** QtQuick/QML, Quickshell `Process`/`StdioCollector`, shell utilities, `busctl`, Node.js tests.

## Global Constraints

- Every refresh must resolve the current OpenRGB D-Bus service and menu IDs again.
- Arrow browsing must never apply a profile or effect.
- Effect activation must use the plugin's D-Bus menu event and must not edit plugin settings files.
- Preserve unrelated dirty-worktree changes.

---

### Task 1: Effect-menu parser and discovery backend

**Files:**
- Create: `dots/.config/quickshell/ii/services/OpenRgbEffects.js`
- Create: `tests/openrgb-effects.test.js`
- Modify: `dots/.config/quickshell/ii/services/OpenRgb.qml`

**Interfaces:**
- Produces: `OpenRgbEffects.parseMenuLayout(text) -> [{ name, menuId }]`
- Produces: `OpenRgb.effects`, `effectAvailable`, `activeEffect`, `applyEffect(name)`, and `cycleEffect(delta)`

- [ ] **Step 1: Write failing parser tests** covering the nested `Effects` → `Profiles` path, malformed JSON, absent plugin menus, and rediscovery from a changed second payload.
- [ ] **Step 2: Run `node --test tests/openrgb-effects.test.js`** and confirm failure because `OpenRgbEffects.js` does not exist.
- [ ] **Step 3: Implement the pure parser** by walking busctl's `u(ia{sv}av)` JSON nodes and returning only profile children beneath the Effects submenu.
- [ ] **Step 4: Run `node --test tests/openrgb-effects.test.js`** and confirm all parser tests pass.
- [ ] **Step 5: Extend `OpenRgb.qml` discovery** with a refresh process that resolves OpenRGB through `org.kde.StatusNotifierWatcher`, calls `GetLayout --json=short`, parses it, replaces the entire effects collection, and preserves a valid active selection by name.
- [ ] **Step 6: Add explicit effect activation** that resolves the current effect menu ID and sends `com.canonical.dbusmenu.Event` with event name `clicked`; update active state only on exit code zero.

### Task 2: Mode Switch staged-selection frontend

**Files:**
- Modify: `dots/.config/quickshell/ii/modules/common/Config.qml`
- Modify: `dots/.config/quickshell/ii/modules/ii/background/widgets/openrgb/OpenRgbWidget.qml`

**Interfaces:**
- Consumes: `OpenRgb.profiles`, `effects`, `activeProfile`, `activeEffect`, `applyProfile(name)`, and `applyEffect(name)`
- Produces: local `selectedKind`, `stagedProfile`, and `stagedEffect` browsing state

- [ ] **Step 1: Add persisted `activeEffect` configuration** without persisting runtime D-Bus IDs or staged selections.
- [ ] **Step 2: Replace the profile-only controls** with the approved Profile/Effect mode switch, one selector, an explicit contextual Apply button, and currently-active text.
- [ ] **Step 3: Make chevrons stage names only** and reconcile staged values after every collection refresh, preserving a still-valid staged name.
- [ ] **Step 4: Run `git diff --check`** and inspect the focused diff for accidental changes.

### Task 3: Live verification and deployment

**Files:**
- Update live counterparts under `/home/lordvicky/.config/quickshell/ii/`

**Interfaces:**
- Consumes: completed branch files from Tasks 1 and 2
- Produces: reloaded live `ii` Quickshell instance

- [ ] **Step 1: Query the live tray menu** and compare discovered effect labels with the parser result.
- [ ] **Step 2: Validate refresh rediscovery** using two fixture payloads in tests and a fresh live menu query.
- [ ] **Step 3: Apply the already-active `Swap` effect** through D-Bus to verify the activation signature without introducing an unexpected visual choice.
- [ ] **Step 4: Back up and copy only the changed live files.**
- [ ] **Step 5: Restart `qs -c ii` and inspect fresh logs** for errors referencing `OpenRgb`, `OpenRgbEffects`, or `OpenRgbWidget`.
