const assert = require("node:assert/strict");
const crypto = require("node:crypto");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");

const repoRoot = path.resolve(__dirname, "..");
const shellRoot = path.join(repoRoot, "dots/.config/quickshell/ii");
const pickerRoot = path.join(shellRoot, "modules/ii/end4WallpaperSelector");

function read(file) {
    return fs.readFileSync(file, "utf8");
}

function sha256(file) {
    return crypto.createHash("sha256").update(fs.readFileSync(file)).digest("hex");
}

test("the current ii-vynx picker and wallpaper service remain unchanged", () => {
    const expected = {
        "modules/ii/wallpaperSelector/ColorFilterToolbar.qml": "c1caee5acfe398898a1eb565e1529f73edd2f20370b32e29d8fa905926adfb9c",
        "modules/ii/wallpaperSelector/ExtraOptionsToolbar.qml": "00e9e2245df341c675d6ae06b85bac2014432eb0ce64237e1c049ab9ba87d9b5",
        "modules/ii/wallpaperSelector/ImageOptionsToolbar.qml": "ab09c8e4a5bf2122c50bb7affb2553fbc50ef8ed4b537f6ce1b5abfd939f4acf",
        "modules/ii/wallpaperSelector/WallpaperDirectoryItem.qml": "7e714f59fdf312d59d306e392dac04547786edd4fb0dfe4d05753daa9a160b16",
        "modules/ii/wallpaperSelector/WallpaperSelector.qml": "ce8b73d368278b9fa35ed7e16a21c1440423f219b2b7afe053187682e56edaf1",
        "modules/ii/wallpaperSelector/WallpaperSelectorContent.qml": "df103d434acfe7267e4a5e09a0a8c58e9a3c74ba68e92e60de0e4acc650c7dc9",
        "services/Wallpapers.qml": "c0ea856a574b5318c6df615e121d9a3f1dc57e0be7c10f81a7a4e95ec2b6f1c5",
    };

    for (const [relative, digest] of Object.entries(expected)) {
        assert.equal(sha256(path.join(shellRoot, relative)), digest, relative);
    }
});
test("the End4 picker is loaded beside the current picker", () => {
    const family = read(path.join(shellRoot, "panelFamilies/IllogicalImpulseFamily.qml"));
    assert.match(family, /import qs\.modules\.ii\.end4WallpaperSelector as End4WallpaperSelector/);
    assert.match(family, /component:\s*WallpaperSelector\s*\{\}/);
    assert.match(family, /component:\s*End4WallpaperSelector\.WallpaperSelector\s*\{\}/);
});

test("the End4 picker has independent state, IPC, namespace, and shortcut", () => {
    const states = read(path.join(shellRoot, "GlobalStates.qml"));
    const selector = read(path.join(pickerRoot, "WallpaperSelector.qml"));

    assert.match(states, /property bool end4WallpaperSelectorOpen: false/);
    assert.match(selector, /GlobalStates\.end4WallpaperSelectorOpen/);
    assert.match(selector, /target:\s*"end4WallpaperSelector"/);
    assert.match(selector, /function open\(\): void/);
    assert.match(selector, /function close\(\): void/);
    assert.match(selector, /name:\s*"end4WallpaperSelectorToggle"/);
    assert.match(selector, /quickshell:end4WallpaperSelector/);
    assert.doesNotMatch(selector, /GlobalStates\.wallpaperSelectorOpen/);
    assert.doesNotMatch(selector, /sidebarSlide/);
});

test("the End4 picker exposes all four requested sources", () => {
    const content = read(path.join(pickerRoot, "WallpaperSelectorContent.qml"));
    const service = read(path.join(shellRoot, "services/OnlineWallpapers.qml"));

    for (const provider of ["local", "wallhaven", "unsplash", "pexels"]) {
        assert.match(content, new RegExp(`value:\\s*"${provider}"`));
    }
    for (const fetcher of ["_fetchWallhaven", "_fetchUnsplash", "_fetchPexels"]) {
        assert.match(service, new RegExp(`function ${fetcher}\\(`));
    }
});

test("online downloads use an atomic argument-safe helper", () => {
    const grid = read(path.join(pickerRoot, "OnlineWallpaperGrid.qml"));
    const helper = read(path.join(shellRoot, "scripts/end4/download-wallpaper.sh"));

    assert.doesNotMatch(grid, /\["bash",\s*"-c"/);
    assert.match(grid, /download-wallpaper\.sh/);
    assert.match(helper, /mkdir -p -- "\$target_dir"/);
    assert.match(helper, /curl .* --output "\$temp_path" -- "\$url"/s);
    assert.match(helper, /mv -f -- "\$temp_path" "\$target_path"/);
});

test("End4 configuration and provider-key actions are present", () => {
    const config = read(path.join(shellRoot, "modules/common/Config.qml"));
    const launcher = read(path.join(shellRoot, "services/LauncherSearch.qml"));
    const pickerFiles = [
        "WallpaperSelector.qml",
        "WallpaperSelectorContent.qml",
        "LocalWallpaperGrid.qml",
        "OnlineWallpaperGrid.qml",
        "WallpaperDirectoryItem.qml",
    ].map(name => read(path.join(pickerRoot, name))).join("\n");

    assert.match(config, /property JsonObject end4WallpaperSelector: JsonObject/);
    assert.doesNotMatch(pickerFiles, /Config\.options\.wallpaperSelector/);
    assert.match(pickerFiles, /Config\.options\.end4WallpaperSelector/);
    for (const action of ["unsplash", "wallhaven", "pexels"]) {
        assert.match(launcher, new RegExp(`action:\\s*"${action}"`));
    }
});
