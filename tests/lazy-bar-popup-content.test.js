const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");

const root = path.join(__dirname, "../dots/.config/quickshell/ii");
const read = relative => fs.readFileSync(path.join(root, relative), "utf8");

test("StyledPopup preserves eager content and offers opt-in lazy content", () => {
    const source = read("modules/ii/bar/StyledPopup.qml");
    assert.match(source, /default property Item contentItem/);
    assert.match(source, /property Component lazyContent:\s*null/);
    assert.match(source, /readonly property Item effectiveContentItem:/);
    assert.match(source, /id:\s*lazyContentLoader/);
    assert.match(source, /sourceComponent:\s*root\.lazyContent/);
});

test("lazy content is owned by the active popup window", () => {
    const source = read("modules/ii/bar/StyledPopup.qml");
    const componentBody = source.match(/component:\s*PanelWindow\s*\{([\s\S]*)\n\s*\}\s*$/)?.[1];
    assert.ok(componentBody, "popup PanelWindow body not found");
    assert.match(componentBody, /Loader\s*\{[\s\S]*?id:\s*lazyContentLoader/);
    assert.match(componentBody, /active:\s*root\.lazyContent\s*!==\s*null/);
});

test("popup sizing and placement use effective content", () => {
    const source = read("modules/ii/bar/StyledPopup.qml");
    assert.doesNotMatch(source, /root\.contentItem\?\.implicit/);
    assert.match(source, /root\.effectiveContentItem\?\.implicitWidth/);
    assert.match(source, /root\.effectiveContentItem\?\.implicitHeight/);
    assert.match(source, /root\.effectiveContentItem\.parent = contentContainer/);
});
