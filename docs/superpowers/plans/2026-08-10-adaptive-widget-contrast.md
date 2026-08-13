# Adaptive Widget Contrast Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Automatically darken shared ported-widget glass over bright wallpaper regions with negligible idle CPU/GPU cost.

**Architecture:** Pure JavaScript owns cover-crop and luminance math. A singleton service coalesces sampling requests and distributes results, while exactly one 8×8 CPU Canvas attached to `Background.qml` loads and samples the wallpaper. Each `WidgetBlurBackground` maps its card crop, throttles requests, and changes only a black Rectangle's opacity.

**Tech Stack:** Quickshell, QtQuick/QML Canvas, JavaScript, Node.js test runner

## Global Constraints

- No `ShaderEffectSource`, `grabToImage`, or rendered-scene GPU readback.
- Exactly one CPU-backed 8×8 Canvas and one shared wallpaper load.
- No frame callback, continuous animation loop, or idle polling.
- Per-card requests are leading-and-trailing throttled to one per 150 ms during movement.
- Automatic black scrim opacity is zero below luminance 0.35 and capped at 0.32 by luminance 0.65.
- Existing manual brightness, tint, blur, and text colors remain unchanged; every `WidgetBlurBackground` consumer, including media, participates by default.

---

### Task 1: Pure contrast and crop math

**Files:**
- Create: `dots/.config/quickshell/ii/modules/ii/background/widgets/AdaptiveContrast.js`
- Create: `tests/adaptive-contrast.test.js`

**Interfaces:**
- Produces: `relativeLuminance(r, g, b) -> number`, `averageLuminance(data) -> number`, `automaticScrimOpacity(luminance) -> number`, and `coverSourceRect(displayRect, displayWidth, displayHeight, sourceWidth, sourceHeight) -> {x, y, width, height}`.

- [ ] **Step 1: Write failing Node tests**

Test black/white WCAG luminance, a 50/50 pixel average, scrim threshold/cap/monotonicity, landscape cover cropping, portrait cover cropping, and clamping a partially off-screen display rectangle.

- [ ] **Step 2: Run the tests and verify failure**

Run: `node --test tests/adaptive-contrast.test.js`

Expected: FAIL because `AdaptiveContrast.js` does not exist.

- [ ] **Step 3: Implement the pure functions**

Use WCAG sRGB linearization, average RGB pixel luminance while ignoring alpha, smoothstep from 0.35 to 0.65, a 0.32 opacity cap, and PreserveAspectCrop geometry converted into bounded source pixels.

- [ ] **Step 4: Run the tests and verify success**

Run: `node --test tests/adaptive-contrast.test.js`

Expected: all tests PASS.

### Task 2: Shared sampling broker and Canvas

**Files:**
- Create: `dots/.config/quickshell/ii/services/AdaptiveContrast.qml`
- Create: `dots/.config/quickshell/ii/modules/ii/background/WallpaperLuminanceCanvas.qml`
- Modify: `dots/.config/quickshell/ii/modules/ii/background/Background.qml`

**Interfaces:**
- Consumes: `AdaptiveContrast.js` crop and average functions.
- Produces service API: `registerClient() -> int`, `unregisterClient(clientId)`, `requestSample(clientId, wallpaperUrl, normalizedRect, displaySize)`, `takeNextRequest() -> object|null`, `completeRequest(clientId, luminance)`, signal `sampleReady(int clientId, real luminance)`, and signal `workAvailable()`.

- [ ] **Step 1: Add the singleton broker**

Create a nonvisual `pragma Singleton` service. Store pending requests by client ID, maintain insertion order, replace superseded requests for the same client, and emit `workAvailable` only when a Canvas should wake. Never create a timer.

- [ ] **Step 2: Add the one Canvas worker**

Create an 8×8 `Canvas` with `renderTarget: Canvas.Image` and `renderStrategy: Canvas.Cooperative`. It loads only the current URL, asks the broker for one request at a time, uses `coverSourceRect`, draws the source crop into 8×8, reads 64 pixels, completes the request, and schedules the next queued item with `Qt.callLater`.

- [ ] **Step 3: Attach the worker to the background scene**

Instantiate one `WallpaperLuminanceCanvas` in `Background.qml` with `width: 8`, `height: 8`, `opacity: 0`, and `visible: true`. Do not add one inside any widget.

- [ ] **Step 4: Validate configuration loading**

Run: `qs-probe`

Expected: config loads with no new fatal error or adaptive-contrast warning.

### Task 3: Card requests and automatic scrim

**Files:**
- Modify: `dots/.config/quickshell/ii/modules/ii/background/widgets/WidgetBlurBackground.qml`

**Interfaces:**
- Consumes: `AdaptiveContrast.registerClient`, `requestSample`, `sampleReady`, and `AdaptiveContrast.js::automaticScrimOpacity`.
- Produces: local `automaticScrimOpacity` bound to a new black Rectangle layered after manual brightness and before tint.

- [ ] **Step 1: Register each blur background as a client**

Register on completion, unregister on destruction, and accept only `sampleReady` events matching the local client ID.

- [ ] **Step 2: Map the card to normalized wallpaper geometry**

For a live `wallpaperSourceItem`, map all four card corners into wallpaper-local coordinates and bound them. For the numeric fallback, derive the rectangle from `offsetX`, `offsetY`, and `wallpaperRender*`. Reject zero, non-finite, or empty geometry.

- [ ] **Step 3: Add leading-and-trailing throttling**

On position, size, scale, parallax geometry, or wallpaper changes, request immediately if 150 ms elapsed; otherwise restart one single-shot Timer for the remaining interval. Request once when image/component state first becomes valid.

- [ ] **Step 4: Add the automatic black scrim**

Insert one black Rectangle after the existing manual brightness scrim. Bind opacity to the latest valid luminance through `automaticScrimOpacity`, keep it invisible at zero, and animate opacity with the existing fast element animation. Sampling failures retain the last valid sample for movement glitches; wallpaper changes reset it to zero until the new source is sampled.

- [ ] **Step 5: Verify logic and QML**

Run: `node --test tests/adaptive-contrast.test.js && qs-probe && git diff --check`

Expected: tests pass, config loads, and no whitespace errors appear.

### Task 4: Live performance and behavior verification

**Files:**
- Install only: `AdaptiveContrast.js`, `AdaptiveContrast.qml`, `WallpaperLuminanceCanvas.qml`, `Background.qml`, and `WidgetBlurBackground.qml`

**Interfaces:**
- Consumes the completed adaptive contrast implementation.
- Produces a verified live-shell installation.

- [ ] **Step 1: Install targeted files**

Use `install -D -m 644` into matching paths under `~/.config/quickshell/ii`. Do not run a full-tree sync.

- [ ] **Step 2: Confirm live reload health**

Check `qs log -c ii` after reload. Expected: `Configuration Loaded` with no adaptive contrast errors.

- [ ] **Step 3: Confirm branch/live parity**

Use `cmp -s` for each installed file. Expected: all match.

- [ ] **Step 4: Inspect the live desktop**

Capture and inspect a screenshot. Verify that bright wallpaper regions darken ported cards without changing their text color, dark regions remain materially unchanged, and the media widget remains unchanged.

- [ ] **Step 5: Check idle behavior**

After movement settles, confirm no timers or repeated adaptive-contrast log activity remain and the Canvas is not repainting without queued work.
