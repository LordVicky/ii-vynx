import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

const root = new URL("../dots/.config/quickshell/ii/", import.meta.url);
const read = async path => readFile(new URL(path, root), "utf8");

test("fake screen corners have an independent persisted master toggle", async () => {
    const config = await read("modules/common/Config.qml");
    const settings = await read("modules/settings/QuickConfig.qml");

    assert.match(config, /property bool fakeScreenRoundingEnabled:\s*true/);
    assert.match(settings, /text:\s*Translation\.tr\("Enable fake screen corners"\)/);
    assert.match(settings, /checked:\s*Config\.options\.appearance\.fakeScreenRoundingEnabled/);
    assert.match(settings, /Config\.options\.appearance\.fakeScreenRoundingEnabled\s*=\s*checked/);

    const toggleStart = settings.indexOf('text: Translation.tr("Enable fake screen corners")');
    const nextSection = settings.indexOf("ContentSubsection", toggleStart);
    const toggleBlock = settings.slice(toggleStart, nextSection);
    assert.doesNotMatch(toggleBlock, /sharpMode|setRounding|decoration:rounding|fakeScreenRounding\s*=/);
});

test("disabling fake screen corners withdraws every monitor-edge implementation", async () => {
    const corners = await read("modules/ii/screenCorners/ScreenCorners.qml");
    const wrapped = await read("modules/ii/wrappedFrame/WrappedFrame.qml");
    const family = await read("panelFamilies/IllogicalImpulseFamily.qml");
    const settings = await read("modules/settings/QuickConfig.qml");

    assert.match(corners, /roundingWindowEnabled:\s*Config\.options\.appearance\.fakeScreenRoundingEnabled\s*&&/);
    assert.match(wrapped, /active:\s*Config\.options\.appearance\.fakeScreenRoundingEnabled\s*&&\s*Config\.options\.appearance\.fakeScreenRounding\s*==\s*3/);
    assert.match(family, /usingWrappedFrame:\s*Config\.options\.appearance\.fakeScreenRoundingEnabled\s*&&\s*Config\.options\.appearance\.fakeScreenRounding\s*===\s*3/);
    assert.match(settings, /visible:\s*Config\.options\.appearance\.fakeScreenRoundingEnabled\s*&&\s*Config\.options\.appearance\.fakeScreenRounding\s*===\s*3/);
});
