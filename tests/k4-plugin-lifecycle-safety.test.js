const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");

const repoRoot = path.join(__dirname, "..");
const k4Root = path.join(repoRoot, "dots/.config/quickshell/ii/modules/ii/k4bar");

function qmlFiles(dir) {
    const result = [];
    for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
        const full = path.join(dir, entry.name);
        if (entry.isDirectory())
            result.push(...qmlFiles(full));
        else if (entry.isFile() && entry.name.endsWith(".qml"))
            result.push(full);
    }
    return result;
}

test("K4 plugin lifetime stays declarative after the QtQmlModels crash", () => {
    for (const file of qmlFiles(k4Root)) {
        const source = fs.readFileSync(file, "utf8");
        const relative = path.relative(repoRoot, file);

        assert.doesNotMatch(source, /Qt\.createComponent\s*\(/,
            `${relative} must not manually create plugin components`);
        assert.doesNotMatch(source, /\.createObject\s*\(/,
            `${relative} must not manually create plugin QObjects`);
        assert.doesNotMatch(source, /\.destroy\s*\(/,
            `${relative} must not manually destroy plugin QObjects`);
    }
});
