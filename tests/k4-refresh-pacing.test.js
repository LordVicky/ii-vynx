const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");

const repoRoot = path.join(__dirname, "..");
const execsPath = path.join(
    repoRoot,
    "dots/.config/hypr/hyprland/execs.lua"
);

const readExecs = () => fs.readFileSync(execsPath, "utf8")
    .replace(/^\s*--.*$/gm, "");

test("Quickshell startup uses refresh-synced Qt Quick pacing", () => {
    const source = readExecs();

    assert.match(
        source,
        /env\s+QSG_RENDER_LOOP=threaded\s+QSG_USE_SIMPLE_ANIMATION_DRIVER=1\s+qs\s+-c\s+\$qsConfig/
    );

    assert.doesNotMatch(source, /QSG_NO_VSYNC/);
    assert.doesNotMatch(source, /QSG_FIXED_ANIMATION_STEP/);
});

test("refresh pacing variables are scoped to shell startup, not IPC clients", () => {
    const source = readExecs();
    const pacedStartups = source.match(/QSG_RENDER_LOOP=threaded/g) ?? [];

    assert.equal(pacedStartups.length, 1);
    assert.match(source, /qs\s+-c\s+\$qsConfig\s+ipc\s+call\s+cliphistService\s+update/);
});
