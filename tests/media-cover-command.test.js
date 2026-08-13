const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");

test("media cover downloader passes metadata as positional shell arguments", () => {
    const source = fs.readFileSync(
        path.join(__dirname, "../dots/.config/quickshell/ii/modules/ii/background/widgets/media/MediaWidget.qml"),
        "utf8"
    );

    assert.doesNotMatch(source, /curl[^\n]*\$\{targetFile\}/);
    assert.match(source, /command:\s*\[\s*"bash",\s*"-c",[\s\S]*?"download-cover",\s*artFilePath,\s*targetFile\s*\]/);
    assert.match(source, /curl -sSL -- "\$2" -o "\$1"/);
});
