const assert = require("node:assert/strict");
const { execFileSync } = require("node:child_process");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const test = require("node:test");

test("media cover downloader passes metadata as positional shell arguments", () => {
    const source = fs.readFileSync(
        path.join(__dirname, "../dots/.config/quickshell/ii/modules/ii/background/widgets/media/MediaWidget.qml"),
        "utf8"
    );

    assert.doesNotMatch(source, /curl[^\n]*\$\{targetFile\}/);
    assert.match(source, /command:\s*\[\s*"bash",\s*"-c",[\s\S]*?"download-cover",\s*artFilePath,\s*targetFile\s*\]/);

    const script = source.match(/`(\[ -f "\$1" \] \|\| curl[^`]+)`/)[1];
    const tempDir = fs.mkdtempSync(path.join(os.tmpdir(), "ii-vynx-cover-"));
    const sourceFile = path.join(tempDir, "source-cover.jpg");
    const destinationFile = path.join(tempDir, "cached cover");

    try {
        fs.writeFileSync(sourceFile, "cover-data");
        execFileSync("bash", ["-c", script, "download-cover", destinationFile, `file://${sourceFile}`]);
        assert.equal(fs.readFileSync(destinationFile, "utf8"), "cover-data");
    } finally {
        fs.rmSync(tempDir, { recursive: true, force: true });
    }
});
