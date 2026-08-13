const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");
const vm = require("node:vm");

const sourcePath = path.join(__dirname,
    "../dots/.config/quickshell/ii/modules/ii/verticalBar/VerticalBarLifecycle.js");
const lifecycle = {};
vm.createContext(lifecycle);
vm.runInContext(fs.readFileSync(sourcePath, "utf8"), lifecycle, { filename: sourcePath });

test("activation surface is at least two logical pixels", () => {
    assert.equal(lifecycle.activationWidth(-5), 2);
    assert.equal(lifecycle.activationWidth(0), 2);
    assert.equal(lifecycle.activationWidth(1), 2);
    assert.equal(lifecycle.activationWidth(8), 8);
});

test("trigger exists only for an open unlocked auto-hidden bar", () => {
    assert.equal(lifecycle.shouldKeepTrigger(true, true, false), true);
    assert.equal(lifecycle.shouldKeepTrigger(false, true, false), false);
    assert.equal(lifecycle.shouldKeepTrigger(true, false, false), false);
    assert.equal(lifecycle.shouldKeepTrigger(true, true, true), false);
});

test("always-visible mode keeps the full bar loaded", () => {
    assert.equal(lifecycle.shouldLoadFullBar(false, false, true, false), true);
});

test("auto-hide mode loads only on demand", () => {
    assert.equal(lifecycle.shouldLoadFullBar(true, false, true, false), false);
    assert.equal(lifecycle.shouldLoadFullBar(true, true, true, false), true);
});

test("closed or locked bars never retain the full window", () => {
    assert.equal(lifecycle.shouldLoadFullBar(false, true, false, false), false);
    assert.equal(lifecycle.shouldLoadFullBar(false, true, true, true), false);
});

test("QML separates the edge trigger from the full-window loader", () => {
    const qml = fs.readFileSync(path.join(__dirname,
        "../dots/.config/quickshell/ii/modules/ii/verticalBar/VerticalBar.qml"), "utf8");
    assert.match(qml, /import "VerticalBarLifecycle\.js" as Lifecycle/);
    assert.match(qml, /id:\s*edgeTriggerLoader/);
    assert.match(qml, /id:\s*fullBarLoader/);
    assert.match(qml, /property var barLoader:\s*fullBarLoader/);
    assert.match(qml, /property int monitorIndex:\s*controller\.monitorIndex/);
    assert.match(qml, /Lifecycle\.shouldKeepTrigger\(/);
    assert.match(qml, /Lifecycle\.shouldLoadFullBar\(/);
    assert.match(qml, /id:\s*unloadTimer[\s\S]*?interval:\s*20000/);
});

test("bar public controls remain available", () => {
    const qml = fs.readFileSync(path.join(__dirname,
        "../dots/.config/quickshell/ii/modules/ii/verticalBar/VerticalBar.qml"), "utf8");
    assert.match(qml, /target:\s*"bar"/);
    for (const handler of ["toggle", "close", "open"])
        assert.match(qml, new RegExp(`function ${handler}\\(\\): void`));
    for (const shortcut of ["barToggle", "barOpen", "barClose"])
        assert.match(qml, new RegExp(`name: "${shortcut}"`));
});
