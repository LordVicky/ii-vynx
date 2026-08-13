import assert from "node:assert/strict";
import fs from "node:fs";
import vm from "node:vm";

const source = fs.readFileSync(new URL("../dots/.config/quickshell/ii/modules/ii/background/widgets/resources/NetworkMetric.js", import.meta.url), "utf8")
    .replace(/^\.pragma library\s*$/m, "");
const context = {};
vm.createContext(context);
vm.runInContext(source, context);

assert.equal(context.speedForMode("download", 2048, 512), 2048);
assert.equal(context.speedForMode("upload", 2048, 512), 512);
assert.equal(context.speedForMode("total", 2048, 512), 2560);
assert.equal(context.speedForMode("unexpected", 2048, 512), 2560);

assert.equal(context.formatSpeed(-5), "0 B/s");
assert.equal(context.formatSpeed(512), "512 B/s");
assert.equal(context.formatSpeed(1536), "1.5 KB/s");
assert.equal(context.formatSpeed(1572864), "1.5 MB/s");

console.log("network metric tests passed");
