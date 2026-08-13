# OpenRGB Icon Motion Polish Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Keep the OpenRGB Icon layout's lightbulb fixed while its trailing controls reveal and retract without overlap, clipping, or ghosting.

**Architecture:** Add a pure width-to-reveal-progress helper to `OpenRgbLayout.js`, then replace the Icon layout's two cross-fading full-layout loaders with one persistent Icon presenter. The presenter owns one leading `PowerControl`; its trailing selector and Apply regions derive opacity and translation from the live animated content width, making interrupted hover transitions naturally reversible.

**Tech Stack:** QML/QtQuick, Quickshell, JavaScript, Node.js built-in test runner, Python `unittest`

## Global Constraints

- The Icon lightbulb's position, size, glyph, opacity, styling, hover response, disabled state, and click behavior remain unchanged throughout expansion and collapse.
- The card expands and collapses with the existing `300 ms` `Appearance.animation.elementResize` animation.
- Trailing controls are hidden through `35%` expansion and reach full opacity and interaction only when the live viewport fits the complete selector, row spacing, and Apply footprint.
- Trailing translation is `-8 px` when hidden and `0 px` when revealed, multiplied by widget scale.
- The existing `180 ms` pointer-exit delay and interaction guards remain unchanged.
- No independent visual-staging timer is added.
- Card and Spindle presentation and behavior remain unchanged.
- Persisted layout, OpenRGB power, discovery, staging, Apply, scaling, placement, blur, adaptive color, and width-bound behavior remain unchanged.

---

### Task 1: Deterministic reveal-progress model

**Files:**
- Modify: `dots/.config/quickshell/ii/modules/ii/background/widgets/openrgb/OpenRgbLayout.js`
- Test: `tests/openrgb-layout.test.js`

**Interfaces:**
- Produces: `iconRevealProgress(currentWidth: number, collapsedWidth: number, expandedWidth: number, trailingFootprint: number, trailingMargin: number): number`.
- Contract: returns a clamped opacity progress in `[0, 1]`; maps width expansion `0.35` to `0`, maps to `1` only when the trailing viewport fits `trailingMargin + trailingFootprint`, and handles a zero-width range without division by zero.

- [ ] **Step 1: Add failing reveal-progress tests**

Append this test after the base-dimensions test in `tests/openrgb-layout.test.js`:

```js
test("stages icon controls after 35 percent until the trailing row fits", () => {
    const collapsed = 52;
    const expanded = 310;
    const trailingMargin = 8;
    const trailingFootprint = 246;
    const widthAt = progress => collapsed + (expanded - collapsed) * progress;
    const fullRevealWidth = collapsed + trailingMargin + trailingFootprint;
    const revealStartWidth = widthAt(0.35);

    assert.equal(layout.iconRevealProgress(widthAt(0), collapsed, expanded, trailingFootprint, trailingMargin), 0);
    assert.equal(layout.iconRevealProgress(widthAt(0.35), collapsed, expanded, trailingFootprint, trailingMargin), 0);
    assert.ok(Math.abs(
        layout.iconRevealProgress(widthAt(0.70), collapsed, expanded, trailingFootprint, trailingMargin)
        - (widthAt(0.70) - revealStartWidth) / (fullRevealWidth - revealStartWidth)
    ) < 1e-9);
    assert.ok(layout.iconRevealProgress(widthAt(0.70), collapsed, expanded, trailingFootprint, trailingMargin) < 1);
    assert.ok(layout.iconRevealProgress(fullRevealWidth - 0.001, collapsed, expanded, trailingFootprint, trailingMargin) < 1);
    assert.equal(layout.iconRevealProgress(fullRevealWidth, collapsed, expanded, trailingFootprint, trailingMargin), 1);
    assert.equal(layout.iconRevealProgress(widthAt(1), collapsed, expanded, trailingFootprint, trailingMargin), 1);
    assert.equal(layout.iconRevealProgress(52, 52, 52, trailingFootprint, trailingMargin), 0);
});
```

- [ ] **Step 2: Run the focused test and verify RED**

Run: `node --test tests/openrgb-layout.test.js`

Expected: FAIL with `TypeError: layout.iconRevealProgress is not a function`.

- [ ] **Step 3: Implement the width-derived reveal helper**

Add this function after `clamp()` in `OpenRgbLayout.js`:

```js
function iconRevealProgress(
    currentWidth,
    collapsedWidth,
    expandedWidth,
    trailingFootprint,
    trailingMargin
) {
    const widthRange = expandedWidth - collapsedWidth;
    if (widthRange <= 0)
        return 0;
    const revealStartWidth = collapsedWidth + widthRange * 0.35;
    const fullRevealWidth = collapsedWidth + trailingMargin + trailingFootprint;
    if (currentWidth - revealStartWidth <= 1e-12)
        return 0;
    if (fullRevealWidth - currentWidth <= 1e-12)
        return 1;
    return clamp(
        (currentWidth - revealStartWidth) / (fullRevealWidth - revealStartWidth),
        0,
        1
    );
}
```

- [ ] **Step 4: Run the focused test and verify GREEN**

Run: `node --test tests/openrgb-layout.test.js`

Expected: all OpenRGB layout tests PASS.

- [ ] **Step 5: Commit the model and its tests**

```bash
git add dots/.config/quickshell/ii/modules/ii/background/widgets/openrgb/OpenRgbLayout.js tests/openrgb-layout.test.js
git commit -m "test: model OpenRGB icon reveal progress"
```

---

### Task 2: Persistent anchored Icon presenter

**Files:**
- Modify: `dots/.config/quickshell/ii/modules/ii/background/widgets/BackgroundWidgetCard.qml`
- Modify: `dots/.config/quickshell/ii/modules/ii/background/widgets/openrgb/OpenRgbWidget.qml`
- Test: `tests/openrgb-layout.test.js`

**Interfaces:**
- Consumes: `OpenRgbLayout.iconRevealProgress(currentWidth, collapsedWidth, expandedWidth, trailingFootprint, trailingMargin): number` from Task 1.
- Preserves: `PowerControl.glyph: string`, `SelectionBlock`, `ApplyControl`, `iconExpanded`, `iconInteractionActive`, `scheduleIconCollapse()`, and `cancelIconCollapse()`.
- Produces: `iconPresentation.revealProgress: real`, a single persistent Icon power action, and a clipped trailing-controls region.
- Produces: `BackgroundWidgetCard.animatedWidth: real`, exposing the live visual width without changing card geometry.

- [ ] **Step 1: Replace the obsolete collapsed-icon source contract with failing anchored-motion contracts**

Replace the test named `collapsed icon contains only power and keeps the layout toggle hidden` with:

```js
test("icon mode uses one persistent power anchor and staged trailing controls", () => {
    const widget = fs.readFileSync(widgetPath, "utf8");
    const iconLayout = widget.match(/Component \{\n        id: iconLayout([\s\S]*?)\n    \}\n\n    Component \{/)?.[1];
    assert.ok(iconLayout, "iconLayout component not found");

    assert.equal((iconLayout.match(/PowerControl \{/g) ?? []).length, 1);
    assert.match(iconLayout, /id: iconPresentation/);
    assert.match(iconLayout, /readonly property real revealProgress:/);
    assert.match(iconLayout, /OpenRgbLayout\.iconRevealProgress/);
    assert.match(iconLayout, /readonly property real trailingRequiredWidth:/);
    assert.match(iconLayout, /iconPresentation\.trailingRequiredWidth,\n                iconPresentation\.trailingLeftMargin/);
    assert.match(iconLayout, /glyph: "lightbulb"/);
    assert.match(iconLayout, /id: trailingControls/);
    assert.match(iconLayout, /clip: true/);
    assert.match(iconLayout, /opacity: iconPresentation\.revealProgress/);
    assert.match(iconLayout, /Translate \{/);
    assert.match(iconLayout, /x: card\.scaled\(-8 \* \(1 - iconPresentation\.revealProgress\)\)/);
    assert.match(iconLayout, /SelectionBlock/);
    assert.match(iconLayout, /ApplyControl/);
});

test("icon and spindle presenters never overlap", () => {
    const widget = fs.readFileSync(widgetPath, "utf8");

    assert.match(widget, /active: root\.layoutMode === "icon"\n            sourceComponent: iconLayout/);
    assert.match(widget, /active: root\.layoutMode === "spindle"\n            sourceComponent: spindleLayout/);
    assert.doesNotMatch(widget, /opacity: root\.iconExpanded \? 0 : 1/);
    assert.doesNotMatch(widget, /root\.layoutMode === "spindle" \|\| root\.layoutMode === "icon"/);
});

test("icon layout toggle follows reveal progress and remains hidden when collapsed", () => {
    const widget = fs.readFileSync(widgetPath, "utf8");
    const cardPath = path.join(
        __dirname,
        "../dots/.config/quickshell/ii/modules/ii/background/widgets/BackgroundWidgetCard.qml"
    );
    const card = fs.readFileSync(cardPath, "utf8");

    assert.match(widget, /property real iconRevealProgress:/);
    assert.match(widget, /root\.layoutMode !== "icon" \? 1 : root\.iconRevealProgress/);
    assert.match(card, /readonly property real animatedWidth: scaleWrapper\.width/);
    assert.match(widget, /root\.layoutMode === "icon" \? card\.animatedWidth : root\.width/);
});
```

- [ ] **Step 2: Run the source-contract tests and verify RED**

Run: `node --test tests/openrgb-layout.test.js`

Expected: the three new tests FAIL because the current Icon loader cross-fades against the complete spindle loader and `iconLayout` has no trailing region.

- [ ] **Step 3: Make the Icon and Spindle loaders mutually exclusive**

In `OpenRgbWidget.qml`, keep the Card loader unchanged. Replace the two current Icon/Spindle loaders with:

```qml
Loader {
    anchors.fill: parent
    active: root.layoutMode === "icon"
    sourceComponent: iconLayout
}

Loader {
    anchors.fill: parent
    active: root.layoutMode === "spindle"
    sourceComponent: spindleLayout
}
```

Remove both loader-level opacity behaviors. The persisted mode now selects one presenter, while `iconExpanded` changes only Icon geometry.

- [ ] **Step 4: Expose the Icon presenter's live reveal progress**

Add this root property beside `spindleBaseWidth`:

```qml
property real iconRevealProgress: 0
```

Inside the new Icon presenter in Step 5, bind it from the presenter's live width:

```qml
Binding {
    target: root
    property: "iconRevealProgress"
    value: iconPresentation.revealProgress
    when: root.layoutMode === "icon"
    restoreMode: Binding.RestoreBindingOrValue
}
```

This gives the external layout toggle the same geometry-derived progress without introducing another animation clock.

- [ ] **Step 5: Replace the icon-only component with the persistent anchored presenter**

Replace the current `iconLayout` component with:

```qml
Component {
    id: iconLayout

    Item {
        id: iconPresentation
        readonly property real collapsedContentWidth: card.scaled(
            72 - DesktopWidgetMetrics.padding.compact * 2
        )
        readonly property real expandedContentWidth: card.scaled(
            root.spindleBaseWidth - DesktopWidgetMetrics.padding.compact * 2
        )
        readonly property real trailingLeftMargin: card.scaled(
            DesktopWidgetMetrics.spacing.standard
        )
        readonly property real trailingRequiredWidth: card.scaled(
            root.spindleMetrics.minimumSelectorWidth
            + DesktopWidgetMetrics.spacing.standard
            + root.spindleMetrics.applyFootprint
        )
        readonly property real revealProgress: OpenRgbLayout.iconRevealProgress(
            iconPresentation.width,
            iconPresentation.collapsedContentWidth,
            iconPresentation.expandedContentWidth,
            iconPresentation.trailingRequiredWidth,
            iconPresentation.trailingLeftMargin
        )

        Binding {
            target: root
            property: "iconRevealProgress"
            value: iconPresentation.revealProgress
            when: root.layoutMode === "icon"
            restoreMode: Binding.RestoreBindingOrValue
        }

        Item {
            id: iconPowerAnchor
            width: card.scaled(72 - DesktopWidgetMetrics.padding.compact * 2)
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom

            PowerControl {
                anchors.fill: parent
                glyph: "lightbulb"
            }
        }

        Item {
            id: trailingControls
            anchors.left: iconPowerAnchor.right
            anchors.leftMargin: iconPresentation.trailingLeftMargin
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            clip: true
            opacity: iconPresentation.revealProgress
            enabled: opacity > 0.99

            RowLayout {
                anchors.fill: parent
                spacing: card.scaled(DesktopWidgetMetrics.spacing.standard)
                transform: Translate {
                    x: card.scaled(-8 * (1 - iconPresentation.revealProgress))
                }

                SelectionBlock {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.minimumWidth: card.scaled(root.spindleMetrics.minimumSelectorWidth)
                }

                ApplyControl {
                    Layout.preferredWidth: card.scaled(root.spindleMetrics.applyFootprint)
                    Layout.fillHeight: true
                }
            }
        }
    }
}
```

The leading region is exactly the collapsed content width (`52 px` at scale `1`), so the button center remains at card-local `36 px`, including the existing `10 px` card padding, for the entire transition.

- [ ] **Step 6: Expose the card's current animated width**

In `BackgroundWidgetCard.qml`, add this read-only property after
`showResizeHandle`:

```qml
readonly property real animatedWidth: scaleWrapper.width
```

This exposes existing visual geometry only. It does not alter the shared card's
size, animation, or behavior.

- [ ] **Step 7: Couple the layout toggle to the same reveal progress and visual edge**

Replace the toggle's opacity binding with:

```qml
opacity: {
    const presentationOpacity = root.layoutMode !== "icon" ? 1 : root.iconRevealProgress;
    return presentationOpacity
        * ((root.containsMouse || layoutToggleArea.containsMouse) ? 0.5 : 0);
}
```

Replace its `x` binding with:

```qml
x: (root.layoutMode === "icon" ? card.animatedWidth : root.width)
    - width - card.scaled(8)
```

Keep its existing `visible` and lock-state checks. This prevents the toggle from
flashing while Icon is collapsed and keeps its hover target inside the current
animated panel boundary. Card and Spindle retain their existing `root.width`
positioning.

- [ ] **Step 8: Run focused tests and inspect the QML diff**

Run:

```bash
node --test tests/openrgb-layout.test.js
git diff --check -- dots/.config/quickshell/ii/modules/ii/background/widgets/BackgroundWidgetCard.qml dots/.config/quickshell/ii/modules/ii/background/widgets/openrgb/OpenRgbWidget.qml tests/openrgb-layout.test.js
git diff -- dots/.config/quickshell/ii/modules/ii/background/widgets/BackgroundWidgetCard.qml dots/.config/quickshell/ii/modules/ii/background/widgets/openrgb/OpenRgbWidget.qml tests/openrgb-layout.test.js
```

Expected: focused tests PASS; `git diff --check` prints nothing; the QML diff contains one Icon `PowerControl`, mutually exclusive loaders, and no loader crossfade.

- [ ] **Step 9: Commit the anchored presenter**

```bash
git add dots/.config/quickshell/ii/modules/ii/background/widgets/BackgroundWidgetCard.qml dots/.config/quickshell/ii/modules/ii/background/widgets/openrgb/OpenRgbWidget.qml tests/openrgb-layout.test.js
git commit -m "fix: polish OpenRGB icon hover motion"
```

---

### Task 3: Regression and live-motion verification

**Files:**
- Verify: `dots/.config/quickshell/ii/modules/ii/background/widgets/openrgb/OpenRgbLayout.js`
- Verify: `dots/.config/quickshell/ii/modules/ii/background/widgets/BackgroundWidgetCard.qml`
- Verify: `dots/.config/quickshell/ii/modules/ii/background/widgets/openrgb/OpenRgbWidget.qml`
- Verify: `tests/openrgb-layout.test.js`

**Interfaces:**
- Consumes: the reveal model and persistent Icon presenter from Tasks 1–2.
- Produces: evidence that automated contracts, live hover motion, and unchanged Card/Spindle modes meet the approved specification.

- [ ] **Step 1: Run the complete automated test suite**

Run:

```bash
node --test tests/*.test.js
python -m unittest discover -s tests -p 'test_*.py'
git diff --check
```

Expected: all Node tests PASS, all Python tests PASS, and `git diff --check` prints nothing.

- [ ] **Step 2: Verify source/live-file parity before deployment**

Run:

```bash
cmp <(git show 4b51ef5b:dots/.config/quickshell/ii/modules/ii/background/widgets/BackgroundWidgetCard.qml) ~/.config/quickshell/ii/modules/ii/background/widgets/BackgroundWidgetCard.qml
cmp <(git show 4b51ef5b:dots/.config/quickshell/ii/modules/ii/background/widgets/openrgb/OpenRgbLayout.js) ~/.config/quickshell/ii/modules/ii/background/widgets/openrgb/OpenRgbLayout.js
cmp <(git show 4b51ef5b:dots/.config/quickshell/ii/modules/ii/background/widgets/openrgb/OpenRgbWidget.qml) ~/.config/quickshell/ii/modules/ii/background/widgets/openrgb/OpenRgbWidget.qml
```

Expected for the current setup: all three `cmp` commands produce no output,
proving the live files still match the pre-implementation baseline commit. If
any `cmp` reports a difference, stop and
inspect the unexpected live edits before replacing files.

- [ ] **Step 3: Back up and deploy only the three changed runtime files**

Create a recoverable temporary backup, then install the verified source files:

```bash
review_backup_dir=$(mktemp -d /tmp/openrgb-motion-polish.XXXXXX)
cp --archive /home/lordvicky/.config/quickshell/ii/modules/ii/background/widgets/BackgroundWidgetCard.qml "$review_backup_dir/BackgroundWidgetCard.qml"
cp --archive /home/lordvicky/.config/quickshell/ii/modules/ii/background/widgets/openrgb/OpenRgbLayout.js "$review_backup_dir/OpenRgbLayout.js"
cp --archive /home/lordvicky/.config/quickshell/ii/modules/ii/background/widgets/openrgb/OpenRgbWidget.qml "$review_backup_dir/OpenRgbWidget.qml"
install -m 644 dots/.config/quickshell/ii/modules/ii/background/widgets/BackgroundWidgetCard.qml /home/lordvicky/.config/quickshell/ii/modules/ii/background/widgets/BackgroundWidgetCard.qml
install -m 644 dots/.config/quickshell/ii/modules/ii/background/widgets/openrgb/OpenRgbLayout.js /home/lordvicky/.config/quickshell/ii/modules/ii/background/widgets/openrgb/OpenRgbLayout.js
install -m 644 dots/.config/quickshell/ii/modules/ii/background/widgets/openrgb/OpenRgbWidget.qml /home/lordvicky/.config/quickshell/ii/modules/ii/background/widgets/openrgb/OpenRgbWidget.qml
```

Keep the printed temporary directory path in the handoff until live verification
passes. Do not copy configuration JSON or any unrelated QML file.

- [ ] **Step 4: Reload only the running `ii` shell and inspect fresh logs**

Confirm the target instance, trigger Quickshell's file-watcher reload, and read
its latest log:

```bash
qs list -c ii
touch /home/lordvicky/.config/quickshell/ii/shell.qml
qs log -c ii -n -t 200
```

Expected: `qs list -c ii` identifies the instance whose config path is
`/home/lordvicky/.config/quickshell/ii/shell.qml`; the touch reloads that config
without killing unrelated instances; the fresh log has no OpenRGB QML error.

- [ ] **Step 5: Perform the live visual acceptance pass**

Verify these cases twice, including once after a shell reload:

1. Hover collapsed Icon: the left edge and lightbulb center remain fixed while the card grows rightward.
2. Observe reveal: trailing controls stay hidden initially, then fade/translate in without clipping through the card edge.
3. Leave Icon: after `180 ms`, controls disappear before the final retraction; no duplicate or ghost lightbulb appears.
4. Leave and re-enter mid-collapse: motion reverses from the current frame without a flash or remount.
5. Press and release Power, Previous, Next, Profiles, Effects, and Apply: active interaction prevents premature collapse and each existing action still works.
6. Resize while expanded: the Icon remains expanded until the resize ends.
7. Cycle through Card and Spindle: their geometry, glyphs, controls, and transitions remain unchanged.

- [ ] **Step 6: Inspect the shell log for OpenRGB/QML regressions**

Run:

```bash
qs log -c ii -n -t 300 | rg "OpenRgbWidget|OpenRgbLayout|Binding loop|ReferenceError|TypeError"
```

Inspect any matching lines for:

```text
OpenRgbWidget
OpenRgbLayout
Binding loop
ReferenceError
TypeError
```

Expected: no new OpenRGB QML errors, JavaScript errors, or binding loops from the verification session.

- [ ] **Step 7: Record verification evidence in the handoff**

Report the exact Node/Python pass counts, `git diff --check` result, the backup
directory, the `touch` reload command, and the outcome of all seven visual
checks. No additional commit is needed unless verification reveals a defect
that requires a tested fix.
