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

test("lazy content is attached after the loader creates its item", () => {
    const source = read("modules/ii/bar/StyledPopup.qml");
    assert.match(source, /function attachContentItem\(content\)/);
    assert.match(source, /if \(!content \|\| !contentContainer\)\s*return/);
    assert.match(source, /id:\s*lazyContentLoader[\s\S]*?onItemChanged:\s*popupWindow\.attachContentItem\(item\)/);
    assert.match(source, /Component\.onCompleted:\s*popupWindow\.attachContentItem\(root\.effectiveContentItem\)/);
});

test("popup sizing and placement use effective content", () => {
    const source = read("modules/ii/bar/StyledPopup.qml");
    assert.doesNotMatch(source, /root\.contentItem\?\.implicit/);
    assert.match(source, /root\.effectiveContentItem\?\.implicitWidth/);
    assert.match(source, /root\.effectiveContentItem\?\.implicitHeight/);
    assert.match(source, /content\.parent = contentContainer/);
});

test("weather forecast work exists only inside lazy popup content", () => {
    const source = read("modules/ii/bar/weather/WeatherPopup.qml");
    assert.match(source, /lazyContent:\s*Component\s*\{/);
    const lazyStart = source.indexOf("lazyContent:");
    assert.ok(lazyStart >= 0, "weather lazy content not found");
    const lazyBody = source.slice(lazyStart);
    assert.match(lazyBody, /Component\.onCompleted:\s*fetchForecast\(\)/);
    assert.match(lazyBody, /Process\s*\{/);
    assert.match(lazyBody, /HeroCard\s*\{/);
    assert.doesNotMatch(source.slice(0, lazyStart), /Component\.onCompleted:\s*fetchForecast/);
});

test("clock popup-only work exists inside lazy content", () => {
    const source = read("modules/ii/bar/ClockWidgetPopup.qml");
    assert.match(source, /stickyHover:\s*true[\s\S]*lazyContent:\s*Component\s*\{/);
    const lazyStart = source.indexOf("lazyContent:");
    assert.ok(lazyStart >= 0, "clock lazy content not found");
    const lazyBody = source.slice(lazyStart);
    assert.match(lazyBody, /ColumnLayout\s*\{/);
    assert.match(lazyBody, /HeroCard\s*\{/);
    assert.match(lazyBody, /function getUpcomingTodos\(/);
    assert.doesNotMatch(source.slice(0, lazyStart), /property string todosSection/);
});

test("only the system tray overflow grid is lazy", () => {
    const source = read("modules/ii/bar/SysTray.qml");
    const itemSource = read("modules/ii/bar/SysTrayItem.qml");
    const lazyStart = source.indexOf("lazyContent:");
    const unpinnedModel = source.indexOf("model: root.unpinnedItems");
    const pinnedModel = source.indexOf("model: ScriptModel");
    assert.ok(lazyStart >= 0, "tray lazy content not found");
    assert.ok(lazyStart < unpinnedModel && unpinnedModel < pinnedModel, "only unpinned items should be inside lazy overflow content");
    assert.match(source.slice(lazyStart, pinnedModel), /GridLayout\s*\{[\s\S]*Repeater\s*\{/);
    assert.match(itemSource, /Loader\s*\{\s*id:\s*menu[\s\S]*?active:\s*false/);
});
