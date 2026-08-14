const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");

const sourcePath = path.join(
    __dirname,
    "../dots/.config/quickshell/ii/modules/ii/background/widgets/DesktopWidgetMetrics.qml"
);

function source() {
    return fs.readFileSync(sourcePath, "utf8");
}

function groupSource(qml, group) {
    const match = qml.match(new RegExp(`readonly property QtObject ${group}: QtObject \\{([\\s\\S]*?)\\n    \\}`));
    assert.ok(match, `missing metric group ${group}`);
    return match[1];
}

function numericProperty(qml, group, name) {
    const match = groupSource(qml, group).match(new RegExp(`readonly property int ${name}: (\\d+)`));
    assert.ok(match, `missing numeric property ${name}`);
    return Number(match[1]);
}

test("declares the desktop widget presentation tiers", () => {
    const qml = source();

    assert.match(qml, /pragma Singleton/);
    for (const tier of ["condensed", "compact", "standard", "showcase"])
        assert.match(qml, new RegExp(`readonly property string ${tier}: "${tier}"`));
});

test("exposes the semantic metric groups used by desktop widgets", () => {
    const qml = source();

    for (const group of ["typography", "glyph", "control", "spacing", "padding", "height", "canvas"])
        assert.match(qml, new RegExp(`${group}: QtObject`));

    for (const property of ["caption", "supporting", "body", "actionLabel", "primaryLabel", "heading"])
        assert.match(qml, new RegExp(`readonly property int ${property}:`));
});

test("provides shared standard and compact card widths", () => {
    const qml = source();

    assert.equal(numericProperty(qml, "canvas", "standard"), 276);
    assert.equal(numericProperty(qml, "canvas", "compact"), 220);
    assert.ok(numericProperty(qml, "canvas", "compact") < numericProperty(qml, "canvas", "standard"));
});

test("keeps geometry tokens positive and ordered by prominence", () => {
    const qml = source();

    assert.ok(numericProperty(qml, "glyph", "compactAction") < numericProperty(qml, "glyph", "standardAction"));
    assert.ok(numericProperty(qml, "glyph", "standardAction") < numericProperty(qml, "glyph", "prominentAction"));
    assert.ok(numericProperty(qml, "control", "compact") < numericProperty(qml, "control", "standard"));
    assert.ok(numericProperty(qml, "control", "standard") < numericProperty(qml, "control", "prominent"));
    assert.ok(numericProperty(qml, "spacing", "tight") < numericProperty(qml, "spacing", "compact"));
    assert.ok(numericProperty(qml, "spacing", "compact") < numericProperty(qml, "spacing", "standard"));
    assert.ok(numericProperty(qml, "spacing", "standard") < numericProperty(qml, "spacing", "roomy"));

    const positive = [
        ["glyph", "caption"], ["glyph", "compactAction"], ["glyph", "standardAction"],
        ["glyph", "prominentAction"], ["control", "compact"], ["control", "standard"],
        ["control", "prominent"], ["spacing", "tight"], ["spacing", "roomy"],
        ["padding", "condensed"], ["height", "compactBar"]
    ];
    for (const [group, property] of positive)
        assert.ok(numericProperty(qml, group, property) > 0, `${group}.${property} must be positive`);
});
