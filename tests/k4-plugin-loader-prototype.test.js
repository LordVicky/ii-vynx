const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");

const repoRoot = path.join(__dirname, "..");
const shellRoot = path.join(repoRoot, "dots/.config/quickshell/ii");
const readShell = relative => fs.readFileSync(path.join(shellRoot, relative), "utf8");

test("K4 lifecycle probe uses Qt-owned Loader lifetime only", () => {
    const probe = readShell("modules/ii/k4bar/K4PluginLifecycleProbe.qml");
    const host = readShell("modules/ii/k4bar/K4PluginLifecycleProbeHost.qml");
    const bar = readShell("modules/ii/k4bar/K4Bar.qml");

    assert.match(probe, /K4Plugin\s*\{/);
    assert.match(probe, /name:\s*"lifecycle-probe"/);
    assert.match(probe, /configurable:\s*false/);
    assert.match(probe, /Component\.onCompleted/);
    assert.match(probe, /Component\.onDestruction/);

    assert.match(host, /Loader\s*\{/);
    assert.match(host, /active:\s*root\.probeEnabled/);
    assert.match(host, /sourceComponent:\s*Component\s*\{\s*K4PluginLifecycleProbe\s*\{\s*\}\s*\}/);
    assert.match(host, /target:\s*"k4\.pluginLifecycleProbe"/);
    assert.match(host, /function enable\(\)/);
    assert.match(host, /function disable\(\)/);
    assert.match(host, /function status\(\):\s*string/);
    assert.doesNotMatch(host, /Qt\.createComponent|createObject\s*\(|\.destroy\s*\(/);

    assert.match(bar, /K4PluginLifecycleProbeHost\s*\{\}/);
});
