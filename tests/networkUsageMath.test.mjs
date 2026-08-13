import assert from "node:assert/strict";
import fs from "node:fs";
import vm from "node:vm";

const source = fs.readFileSync(new URL("../dots/.config/quickshell/ii/services/NetworkUsageMath.js", import.meta.url), "utf8")
    .replace(/^\.pragma library\s*$/m, "");
const context = {};
vm.createContext(context);
vm.runInContext(source, context);

assert.deepEqual(
    { ...context.calculateSpeeds(3000, 1800, { rx: 1000, tx: 800 }, 2, 10) },
    { download: 1000, upload: 500, total: 1500 }
);
assert.deepEqual(
    { ...context.calculateSpeeds(1005, 804, { rx: 1000, tx: 800 }, 1, 10) },
    { download: 0, upload: 0, total: 0 }
);

console.log("network usage math tests passed");
