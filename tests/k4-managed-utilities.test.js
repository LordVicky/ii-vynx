const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");

const repoRoot = path.join(__dirname, "..");
const k4Root = path.join(repoRoot, "dots/.config/quickshell/ii/modules/ii/k4bar");
const read = name => fs.readFileSync(path.join(k4Root, name), "utf8");

test("K4 low-coupling utilities use the accepted stable proxy lifecycle", () => {
    const builtins = read("K4BuiltinPlugins.qml");
    const managed = read("K4ManagedPlugin.qml");

    assert.match(builtins, /property QtObject systemPlugin:\s*K4ManagedPlugin\s*\{[\s\S]*?name:\s*"system"[\s\S]*?title:\s*"System"[\s\S]*?application:\s*true[\s\S]*?source:\s*Qt\.resolvedUrl\("K4SystemPlugin\.qml"\)/);
    assert.match(builtins, /property QtObject windowsPlugin:\s*K4ManagedPlugin\s*\{[\s\S]*?name:\s*"windows"[\s\S]*?title:\s*"Windows"[\s\S]*?application:\s*true[\s\S]*?source:\s*Qt\.resolvedUrl\("K4WindowsPlugin\.qml"\)/);
    assert.match(builtins, /property QtObject sessionPlugin:\s*K4ManagedPlugin\s*\{[\s\S]*?name:\s*"session"[\s\S]*?title:\s*"Session"[\s\S]*?application:\s*true[\s\S]*?source:\s*Qt\.resolvedUrl\("K4SessionPlugin\.qml"\)/);

    assert.doesNotMatch(builtins, /property QtObject systemPlugin:\s*K4SystemPlugin\s*\{\}/);
    assert.doesNotMatch(builtins, /property QtObject windowsPlugin:\s*K4WindowsPlugin\s*\{\}/);
    assert.doesNotMatch(builtins, /property QtObject sessionPlugin:\s*K4SessionPlugin\s*\{\}/);

    assert.match(managed, /property var implementationLoader:\s*Loader\s*\{/);
    assert.doesNotMatch(managed, /Qt\.createComponent|createObject\s*\(|\.destroy\s*\(/);
});

test("managed utility implementations retain their existing service and IPC boundaries", () => {
    const system = read("K4SystemPlugin.qml");
    const windows = read("K4WindowsPlugin.qml");
    const session = read("K4SessionPlugin.qml");

    assert.match(system, /Component\.onDestruction:\s*if \(open\) K4System\.stop\(\)/);
    assert.match(system, /target:\s*"k4\.system"/);
    assert.match(windows, /target:\s*"k4\.windows"/);
    assert.match(session, /target:\s*"k4\.session"/);

    assert.doesNotMatch(system, /Qt\.createComponent|createObject\s*\(|\.destroy\s*\(/);
    assert.doesNotMatch(windows, /Qt\.createComponent|createObject\s*\(|\.destroy\s*\(/);
    assert.doesNotMatch(session, /Qt\.createComponent|createObject\s*\(|\.destroy\s*\(/);
});
