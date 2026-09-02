const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");

const shellRoot = path.resolve(__dirname, "../dots/.config/quickshell/ii");

function read(relativePath) {
    return fs.readFileSync(path.join(shellRoot, relativePath), "utf8");
}

test("centered wallpaper is a persisted opt-in setting", () => {
    const config = read("modules/common/Config.qml");
    const settings = read("modules/settings/BackgroundConfig.qml");

    assert.match(config, /property bool centered:\s*false/);
    assert.match(settings, /text:\s*Translation\.tr\("Centered"\)/);
    assert.match(settings, /checked:\s*Config\.options\.background\.centered/);
    assert.match(settings, /Config\.options\.background\.centered = checked/);
});

test("centered wallpaper contains the image and keeps it centered", () => {
    const background = read("modules/ii/background/Background.qml");

    assert.match(background, /readonly property bool centered:\s*Config\.options\.background\.centered \?\? false/);
    assert.match(background, /property real wallpaperContainRatio:\s*Math\.max\(wallpaperWidth \/ screen\.width, wallpaperHeight \/ screen\.height\)/);
    assert.match(background, /property real effectiveWallpaperRatio:\s*centered \? wallpaperContainRatio : wallpaperToScreenRatio/);
    assert.match(background, /property real effectiveScale:\s*centered \? preferredWallpaperScale : effectiveWallpaperScale/);
    assert.match(background, /property real effectiveValueX:\s*bgRoot\.centered \? \(0\.5 \+ sidebarOffsetX\)/);
    assert.match(background, /property real effectiveValueY:\s*bgRoot\.centered \? 0\.5/);
    assert.match(background, /fillMode:\s*bgRoot\.centered \? Image\.PreserveAspectFit : Image\.PreserveAspectCrop/);
});

test("centered wallpaper uses themed letterboxing", () => {
    const background = read("modules/ii/background/Background.qml");

    assert.match(background, /if \(bgRoot\.centered\)\s*return Appearance\.colors\.colLayer0/);
});
