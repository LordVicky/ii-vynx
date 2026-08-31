const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '..');
const read = rel => fs.readFileSync(path.join(root, rel), 'utf8');
const base = 'dots/.config/quickshell/ii/modules/ii/k4bar';

test('K4 tray consumes ii TrayService rather than creating a second tray owner', () => {
  const source = read(`${base}/K4Tray.qml`);
  assert.match(source, /TrayService\.pinnedItems/);
  assert.match(source, /TrayService\.unpinnedItems/);
  assert.match(source, /TrayService\.togglePin/);
  assert.doesNotMatch(source, /SystemTray\.items/);
  assert.doesNotMatch(source, /Process\s*\{/);
  assert.match(source, /if \(!item \|\| item\.onlyMenu\) return false/);
  assert.match(source, /return true/);
});

test('K4 tray plugin preserves upstream dimensions and hover policy without joining Apps', () => {
  const plugin = read(`${base}/K4TrayPlugin.qml`);
  const builtins = read(`${base}/K4BuiltinPlugins.qml`);
  assert.match(plugin, /name:\s*"tray"/);
  assert.match(plugin, /priority:\s*63/);
  assert.doesNotMatch(plugin, /application:\s*true/);
  assert.match(plugin, /islandWidth:\s*640/);
  assert.match(plugin, /islandHeight:\s*360/);
  assert.match(plugin, /closeOnHoverExit:\s*true/);
  assert.match(plugin, /hoverExitDelay:\s*900/);
  assert.match(plugin, /function\s+openFor\(item\)/);
  assert.match(plugin, /target:\s*"k4\.tray"/);
  assert.match(builtins, /property QtObject trayPlugin:\s*K4TrayPlugin\s*\{\}/);
});

test('K4 tray is visible and interactive from the hover clock', () => {
  const row = read(`${base}/K4TrayRow.qml`);
  const clock = read(`${base}/K4ClockView.qml`);
  const builtins = read(`${base}/K4BuiltinPlugins.qml`);
  assert.match(row, /model:\s*K4Tray\.sorted\.slice\(0, root\.shown\)/);
  assert.match(row, /K4Tray\.primary\(cell\.modelData\)/);
  assert.match(row, /root\.trayPlugin\.openFor\(cell\.modelData\)/);
  assert.match(row, /K4Tray\.secondary\(cell\.modelData\)/);
  assert.match(row, /K4Tray\.scroll\(cell\.modelData/);
  assert.match(clock, /K4TrayRow\s*\{/);
  assert.match(clock, /trayPlugin:\s*root\.trayPlugin/);
  assert.match(builtins, /K4ClockView\s*\{[\s\S]*?trayPlugin:\s*root\.trayPlugin/);
  assert.match(builtins, /readonly property int trayEstimate:[\s\S]*?Math\.min\(K4Tray\.count, 5\) \* 28/);
});

test('K4 tray view uses the selected live item DBus menu and upstream interactions', () => {
  const view = read(`${base}/K4TrayView.qml`);
  assert.match(view, /QsMenuOpener\s*\{/);
  assert.match(view, /menu:\s*root\.selected && root\.selected\.hasMenu \? root\.selected\.menu : null/);
  assert.match(view, /model:\s*K4Tray\.sorted/);
  assert.match(view, /model:\s*opener\.children/);
  assert.match(view, /K4Tray\.secondary/);
  assert.match(view, /K4Tray\.scroll/);
  assert.match(view, /entryRow\.modelData\.triggered\(\)/);
});
