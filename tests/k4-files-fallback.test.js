import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { mkdtempSync, mkdirSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";
import test from "node:test";

const helper = fileURLToPath(new URL(
    "../dots/.config/quickshell/ii/modules/ii/k4bar/tools/k4-file-search.py",
    import.meta.url,
));

test("K4 file search falls back when fd is unavailable", () => {
    const sandbox = mkdtempSync(path.join(tmpdir(), "k4-files-"));
    const home = path.join(sandbox, "home");
    const emptyBin = path.join(sandbox, "bin");
    const configDir = path.join(home, ".config");
    mkdirSync(configDir, { recursive: true });
    mkdirSync(emptyBin, { recursive: true });
    writeFileSync(path.join(configDir, "demo.conf"), "k4\n");

    try {
        const python = execFileSync("sh", ["-c", "command -v python3"], {
            encoding: "utf8",
        }).trim();
        assert.ok(python, "python3 is required by the K4 file-search helper");

        const output = execFileSync(python, [
            helper, "conf", "--scope", "home", "--limit", "5",
        ], {
            encoding: "utf8",
            env: { ...process.env, HOME: home, PATH: emptyBin },
        });
        const data = JSON.parse(output);
        assert.equal(data.query, "conf");
        assert.ok(data.results.some(row => row.path === path.join(configDir, "demo.conf")));
    } finally {
        rmSync(sandbox, { recursive: true, force: true });
    }
});
