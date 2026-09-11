# Fullscreen Direct Scanout Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let fullscreen games enter direct scanout while the K4 shell is idle, without destroying and recreating Quickshell layer windows.

**Architecture:** Keep the existing `PanelWindow` lifetimes. Route fake corners and an idle Away-when-fullscreen K4 bar to the top layer, which fullscreen clients suppress; promote K4 back to overlay whenever an explicit plugin is active.

**Tech Stack:** Quickshell QML, Hyprland layer-shell integration, Node.js built-in test runner.

## Global Constraints

- Preserve the user's `bar.k4.spaceMode` and `appearance.fakeScreenRounding` values.
- Keep the K4 bar and fake screen-corner `PanelWindow` objects alive across fullscreen transitions.
- Preserve event-driven K4 notifications, volume HUD, launcher, and other plugin views over fullscreen clients.
- Do not add a service, process supervisor, game-specific rule, dependency, or persistent option.
- Validate the deployed shell through Hyprland's live layer and direct-scanout state.

---

### Task 1: Route idle fullscreen surfaces below the game

**Files:**
- Modify: `dots/.config/quickshell/ii/modules/ii/screenCorners/ScreenCorners.qml:27-42`
- Modify: `dots/.config/quickshell/ii/modules/ii/k4bar/K4Bar.qml:45-80`

**Interfaces:**
- Consumes: `cornerPanelWindow.fullscreen`, `cornerPanelWindow.cornerContentVisible`, `HyprlandData.monitorHasFullscreen(screenName)`, `K4Settings.spaceMode`, `panelWindow.effectiveSpaceMode`, and `panelWindow.shouldShow`.
- Produces: `panelWindow.idleFullscreen: bool` and per-surface `WlrLayershell.layer` bindings.

- [x] **Step 1: Run the failing live behavior check**

```python
monitor = hyprctl_json("monitors")[0]
overlay_namespaces = layer_namespaces(monitor["name"], level="3")
assert "quickshell:k4bar" not in overlay_namespaces
assert "quickshell:screenCorners" not in overlay_namespaces
assert monitor["solitaryBlockedBy"] is None
assert monitor["directScanoutBlockedBy"] is None
assert monitor["directScanoutTo"] == bodycam_address_without_prefix
```

- [x] **Step 2: Verify RED against the unchanged live shell**

Focus Bodycam in borderless fullscreen, sample `hyprctl monitors -j` and `hyprctl layers -j`, and evaluate the assertions above.

Expected: FAIL because the active overlay level contains `quickshell:k4bar` and `quickshell:screenCorners`, `solitaryBlockedBy` contains `OVERLAYS`, and `directScanoutTo` is `0`.

- [x] **Step 3: Implement the minimal QML layer routing**

In `ScreenCorners.qml`, replace the fixed layer with:

```qml
WlrLayershell.layer: cornerPanelWindow.cornerContentVisible
    ? WlrLayer.Overlay : WlrLayer.Top
```

In `K4Bar.qml`, reuse one fullscreen query and distinguish an idle fullscreen surface:

```qml
readonly property string effectiveSpaceMode: K4Settings.spaceMode === "fullscreen"
    ? (HyprlandData.monitorHasFullscreen(panelWindow.screen.name)
        ? "hidden" : "reserve")
    : K4Settings.spaceMode
readonly property bool idleFullscreen:
    K4Settings.spaceMode === "fullscreen"
        && effectiveSpaceMode === "hidden" && !shouldShow
```

Keep explicit K4 UI above fullscreen clients while allowing the idle surface to fall back to top:

```qml
readonly property bool notificationOverlay:
    pluginVisible?.name === "toast"
    || pluginVisible?.name === "launcher"
    || pluginVisible?.name === "volume"
    || (effectiveSpaceMode === "hidden" && !idleFullscreen)
```

- [x] **Step 4: Run focused regression tests**

Run: `node --test tests/k4-space-mode.test.js tests/k4-volume-fullscreen.test.js tests/k4-notifications.test.js tests/k4-surface-lifecycle.test.js`

Expected: all selected tests pass.

- [x] **Step 5: Check QML syntax**

Run: `/usr/bin/qmllint-qt6 -I dots/.config/quickshell/ii dots/.config/quickshell/ii/modules/ii/screenCorners/ScreenCorners.qml dots/.config/quickshell/ii/modules/ii/k4bar/K4Bar.qml`

Expected: exit 0. Existing unresolved-import warnings may remain, but there must be no syntax error in either changed file.

- [x] **Step 6: Commit the source change**

```bash
git add dots/.config/quickshell/ii/modules/ii/screenCorners/ScreenCorners.qml \
    dots/.config/quickshell/ii/modules/ii/k4bar/K4Bar.qml
git commit -m "fix(fullscreen): preserve direct scanout with K4 shell"
```

### Task 2: Deploy and validate the live shell

**Files:**
- Copy source to: `/home/lordvicky/.config/quickshell/ii/modules/ii/screenCorners/ScreenCorners.qml`
- Copy source to: `/home/lordvicky/.config/quickshell/ii/modules/ii/k4bar/K4Bar.qml`

**Interfaces:**
- Consumes: the committed QML files from Task 1 and the existing `qs -c ii` process.
- Produces: a live shell whose idle fullscreen layer state permits Hyprland direct scanout.

- [x] **Step 1: Compare source and live files before deployment**

Run: `diff -u /home/lordvicky/.config/quickshell/ii/modules/ii/screenCorners/ScreenCorners.qml dots/.config/quickshell/ii/modules/ii/screenCorners/ScreenCorners.qml` and the equivalent command for `K4Bar.qml`.

Expected: differences are limited to the Task 1 layer-routing changes.

- [x] **Step 2: Deploy the two changed QML files**

Copy the two committed source files to their matching live paths without touching any other live configuration.

- [x] **Step 3: Restart the live shell**

Run `qs -c ii kill`, then start `qs -c ii` with the same command line. Confirm one live shell process and inspect `qs log --no-color` for QML load errors.

- [x] **Step 4: Verify desktop presentation**

Run: `hyprctl layers -j`

Expected: outside fullscreen, `quickshell:screenCorners` return to overlay, `quickshell:k4bar` returns to top, and the configured K4 bar is visible.

- [x] **Step 5: Verify Bodycam direct scanout**

Focus Bodycam in its unchanged borderless mode and sample `hyprctl monitors -j` plus `hyprctl layers -j` for at least five frames.

Expected: the active overlay level does not contain idle `quickshell:screenCorners` or `quickshell:k4bar`; `solitaryBlockedBy` is null; `directScanoutTo` equals the Bodycam window address; `directScanoutBlockedBy` is null; observed FPS is in the established 90-100 range.

- [x] **Step 6: Verify restoration after leaving fullscreen**

Leave Bodycam's workspace and run `hyprctl layers -j` again.

Expected: the normal K4 bar and corner layer behavior is restored without restarting Quickshell.
