const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");
const vm = require("node:vm");

const sourcePath = path.join(
    __dirname,
    "../dots/.config/quickshell/ii/modules/ii/background/widgets/openrgb/OpenRgbLayout.js"
);
const source = fs.readFileSync(sourcePath, "utf8");
const widgetPath = path.join(
    __dirname,
    "../dots/.config/quickshell/ii/modules/ii/background/widgets/openrgb/OpenRgbWidget.qml"
);
const layout = {};
vm.createContext(layout);
vm.runInContext(source, layout, { filename: sourcePath });

const metrics = {
    minimumWidth: 330,
    maximumWidth: 410,
    padding: 10,
    prominentFootprint: 56,
    applyFootprint: 52,
    outerSpacing: 8,
    minimumSelectorWidth: 186,
    labelOverhead: 212
};

test("normalizes and cycles the three supported layouts", () => {
    assert.equal(layout.normalizeLayout("card"), "card");
    assert.equal(layout.normalizeLayout("spindle"), "spindle");
    assert.equal(layout.normalizeLayout("icon"), "icon");
    assert.equal(layout.normalizeLayout("unknown"), "spindle");
    assert.equal(layout.nextLayout("card"), "spindle");
    assert.equal(layout.nextLayout("spindle"), "icon");
    assert.equal(layout.nextLayout("icon"), "card");
});

test("calculates base dimensions for each layout", () => {
    assert.equal(layout.widgetBaseWidth("card", false, 360), 300);
    assert.equal(layout.widgetBaseWidth("icon", false, 360), 72);
    assert.equal(layout.widgetBaseWidth("icon", true, 360), 360);
    assert.equal(layout.widgetBaseWidth("spindle", false, 360), 360);
    assert.equal(layout.widgetBaseHeight("card"), 218);
    assert.equal(layout.widgetBaseHeight("icon"), 72);
});

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

test("models a 300ms scaled icon width transition in both directions", () => {
    const collapsed = 72;
    const expanded = 360;
    const scale = 0.75;
    const midpoint = (collapsed + (expanded - collapsed) / 2) * scale;

    assert.equal(layout.iconWidthAnimationDuration, 300);
    assert.equal(layout.iconWidthAtTime(collapsed, expanded, scale, 0), collapsed * scale);
    assert.equal(layout.iconWidthAtTime(collapsed, expanded, scale, 150), midpoint);
    assert.equal(layout.iconWidthAtTime(collapsed, expanded, scale, 300), expanded * scale);
    assert.equal(layout.iconWidthAtTime(expanded, collapsed, scale, 150), midpoint);
    assert.equal(layout.iconWidthAtTime(expanded, collapsed, scale, 300), collapsed * scale);
});

test("enables icon interaction only at exact full reveal", () => {
    assert.equal(layout.iconInteractionEnabled(0.999999), false);
    assert.equal(layout.iconInteractionEnabled(1), true);
    assert.equal(layout.iconInteractionEnabled(1.000001), true);
});

test("commits scale-aware animated width and exact icon interaction wiring", () => {
    const widget = fs.readFileSync(widgetPath, "utf8");
    const cardPath = path.join(
        __dirname,
        "../dots/.config/quickshell/ii/modules/ii/background/widgets/BackgroundWidgetCard.qml"
    );
    const card = fs.readFileSync(cardPath, "utf8");

    assert.match(card, /Behavior on width\s*\{\s*animation: Appearance\.animation\.elementResize\.numberAnimation/);
    assert.match(card, /readonly property real animatedWidth: scaleWrapper\.width \* scaleWrapper\.scale/);
    assert.match(widget, /readonly property real currentContentWidth: card\.animatedWidth/);
    assert.match(widget, /iconPresentation\.currentContentWidth,\n\s+iconPresentation\.collapsedContentWidth/);
    assert.match(widget, /enabled: OpenRgbLayout\.iconInteractionEnabled\(iconPresentation\.revealProgress\)/);
});

test("reserves enough spindle width for both actions and the selector", () => {
    assert.equal(layout.spindleMinimumWidth(metrics), 330);
});

test("grows with the label between the minimum and maximum width", () => {
    assert.equal(layout.spindleBaseWidth(40, metrics), 330);
    assert.equal(layout.spindleBaseWidth(140, metrics), 352);
    assert.equal(layout.spindleBaseWidth(260, metrics), 410);
});

test("never returns less than the complete minimum footprint", () => {
    assert.ok(layout.spindleBaseWidth(140, metrics) >= layout.spindleMinimumWidth(metrics));
});

test("pixel-snaps a prominent action to equal integer top and bottom gaps", () => {
    const scale = 0.8183710084081723;
    const containerHeight = 72 * scale;
    const padding = 10 * scale;
    const itemHeight = layout.pixelScaled(52, scale);
    const localY = layout.centeredContentY(containerHeight, itemHeight, padding);
    const screenY = padding + localY;
    const renderedContainerHeight = Math.round(containerHeight);

    assert.equal(itemHeight, 43);
    assert.equal(screenY, 8);
    assert.equal(renderedContainerHeight - screenY - itemHeight, 8);
});

test("card mode consumes the Standard presentation metrics", () => {
    const widget = fs.readFileSync(widgetPath, "utf8");
    const cardLayout = widget.match(/Component \{\n        id: cardLayout([\s\S]*?)\n    component SelectionBlock:/)?.[1];
    assert.ok(cardLayout, "cardLayout component not found");

    assert.match(widget, /contentPadding: root\.layoutMode === "card" \? DesktopWidgetMetrics\.padding\.standard/);
    for (const token of [
        "spacing.standard",
        "spacing.roomy",
        "typography.body",
        "typography.actionLabel",
        "typography.primaryLabel",
        "glyph.standardAction",
        "control.compact",
        "control.standard",
        "control.prominent"
    ])
        assert.match(cardLayout, new RegExp(`DesktopWidgetMetrics\\.${token.replace(".", "\\.")}`));

    assert.doesNotMatch(cardLayout, /Appearance\.font\.pixelSize/);
});

test("card mode omits persistent footer metadata", () => {
    const widget = fs.readFileSync(widgetPath, "utf8");
    const cardLayout = widget.match(/Component \{\n        id: cardLayout([\s\S]*?)\n    component SelectionBlock:/)?.[1];
    assert.ok(cardLayout, "cardLayout component not found");

    assert.doesNotMatch(cardLayout, /Currently active:/);
    assert.doesNotMatch(cardLayout, /Nothing applied yet/);
    assert.doesNotMatch(cardLayout, /root\.collectionStatus/);
    assert.doesNotMatch(cardLayout, /OpenRgb\.lightsEnabled \? Translation\.tr\("Lights on"\)/);
});

test("icon mode declares transient hover expansion and shared power contracts", () => {
    const widget = fs.readFileSync(widgetPath, "utf8");

    for (const contract of [
        /property bool iconExpanded: false/,
        /property bool iconInteractionActive: false/,
        /interval: 180/,
        /onContainsMouseChanged/,
        /OpenRgbLayout\.normalizeLayout/,
        /OpenRgbLayout\.nextLayout/,
        /OpenRgbLayout\.widgetBaseWidth/,
        /OpenRgbLayout\.widgetBaseHeight/,
        /component PowerControl/,
        /required property string glyph/,
        /glyph: "lightbulb"/,
        /onClicked: OpenRgb\.toggleLights\(\)/
    ])
        assert.match(widget, contract);
});

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

test("icon trailing viewport preserves horizontal clipping while exposing vertical SelectionBlock overflow", () => {
    const widget = fs.readFileSync(widgetPath, "utf8");
    const iconLayout = widget.match(/Component \{\n        id: iconLayout([\s\S]*?)\n    \}\n\n    Component \{/)?.[1];
    assert.ok(iconLayout, "iconLayout component not found");

    const trailingControls = iconLayout.match(/Item \{\n                id: trailingControls([\s\S]*?)\n            \}\n        \}/)?.[1];
    assert.ok(trailingControls, "trailingControls viewport not found");
    assert.match(trailingControls, /anchors\.left: iconPowerAnchor\.right/);
    assert.match(trailingControls, /anchors\.right: parent\.right/);
    assert.match(trailingControls, /clip: true/);
    assert.match(trailingControls, /height: Math\.max\(iconPresentation\.height, trailingContent\.implicitHeight\)/);

    const trailingContent = trailingControls.match(/Item \{\n\s+id: trailingContent([\s\S]*?)\n\s+RowLayout \{/)?.[1];
    assert.ok(trailingContent, "trailingContent inset not found");
    assert.match(trailingContent, /anchors\.top: parent\.top/);
    assert.match(trailingContent, /height: iconPresentation\.height/);
    assert.match(trailingContent, /implicitHeight: trailingRow\.implicitHeight/);
});
