# Final-Size Desktop Widget Rendering Implementation Plan

**Goal:** Remove the parent scale transform from the nine ported desktop widgets so text and symbols are rasterized at their final on-screen size.

**Architecture:** `BackgroundWidgetCard` will own final scaled dimensions instead of scaling an unscaled subtree. Each ported widget will multiply authored design metrics by its existing `widgetScale`; text and symbol wrappers will expose base-size properties and perform the font-size multiplication consistently. The custom media widget is outside this shared card and remains unchanged.

**Tech Stack:** Quickshell, QML/QtQuick, QtQuick.Layouts

---

### Task 1: Make the shared card transform-free

**Files:**
- Modify: `dots/.config/quickshell/ii/modules/ii/background/widgets/BackgroundWidgetCard.qml`

1. Add a `scaled()` metric helper for authored dimensions.
2. Size the wrapper at `baseWidth * scaleFactor` and `baseHeight * scaleFactor`.
3. Remove `transformOrigin` and `scale` from the wrapper.
4. Scale card padding, corner radius, and shadow radius explicitly.
5. Preserve resize-handle behavior and animate final width/height during live resizing.

### Task 2: Give text and symbols explicit base-size APIs

**Files:**
- Modify: `dots/.config/quickshell/ii/modules/ii/background/widgets/TransformSafeText.qml`
- Modify: `dots/.config/quickshell/ii/modules/ii/background/widgets/TransformSafeSymbol.qml`

1. Add `basePixelSize` and `scaleFactor` properties to text.
2. Bind `font.pixelSize` to `basePixelSize * scaleFactor` while retaining the shell font family and variable axes.
3. Add `baseIconSize` and `scaleFactor` to symbols and bind their final `iconSize`.
4. Keep Qt text rendering and avoid text effects that blur glyph edges.

### Task 3: Convert all nine ported widgets to final-size metrics

**Files:**
- Modify: `battery/BatteryWidget.qml`
- Modify: `clipboard/ClipboardWidget.qml`
- Modify: `lyrics/LyricsWidget.qml`
- Modify: `network/NetworkWidget.qml`
- Modify: `pomodoro/PomodoroWidget.qml`
- Modify: `privacy/PrivacyWidget.qml`
- Modify: `songrec/SongRecWidget.qml`
- Modify: `todo/TodoWidget.qml`
- Modify: `updates/UpdatesWidget.qml`

1. Replace fixed layout dimensions, spacing, margins, radii, and stroke widths with `card.scaled(...)` values.
2. Replace text `font.pixelSize` assignments with `basePixelSize` and pass `root.widgetScale`.
3. Replace symbol `iconSize` assignments with `baseIconSize` and pass `root.widgetScale`.
4. Scale lyric row and font metrics explicitly.
5. Leave service logic and the custom media widget unchanged.

### Task 4: Verify and install using the repository workflow

**Files:**
- Verify the QML files above
- Install only the changed widget files into `~/.config/quickshell/ii`

1. Search the nine widgets for remaining unscaled fixed visual metrics and old text/symbol APIs.
2. Run the repository's QML probe/check command documented in `AGENTS.md`.
3. Install only the affected files with `install -m 644`; do not run a full-tree sync.
4. Confirm the installed files match the branch and the live shell reloads successfully.
