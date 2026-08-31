const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");

const k4Dir = path.join(__dirname, "../dots/.config/quickshell/ii/modules/ii/k4bar");

test("every k4 Quickshell Singleton imports the parent Quickshell module", () => {
    const files = fs.readdirSync(k4Dir).filter(file => file.endsWith(".qml"));

    for (const file of files) {
        const source = fs.readFileSync(path.join(k4Dir, file), "utf8");
        if (!/^\s*pragma Singleton\s*$/m.test(source) || !/^\s*Singleton\s*\{/m.test(source))
            continue;

        assert.match(
            source,
            /^\s*import Quickshell\s*$/m,
            `${file} uses Quickshell.Singleton but does not import Quickshell`
        );
    }
});
