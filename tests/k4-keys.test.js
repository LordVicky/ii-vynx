const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '..');
const read = rel => fs.readFileSync(path.join(root, rel), 'utf8');
const base = 'dots/.config/quickshell/ii/modules/ii/k4bar';

test('K4 keys adapter reuses HyprlandKeybinds without a second bind reader', () => {
  const source = read(`${base}/K4Keys.qml`);
  assert.match(source, /HyprlandKeybinds\.keybinds/);
  assert.match(source, /function\s+filter\(query\)/);
  assert.match(source, /function\s+keys\(combo\)/);
  assert.doesNotMatch(source, /Process\s*\{/);
  assert.doesNotMatch(source, /hyprctl/);
});

test('K4 keys preserves Hyprland wheel direction names', () => {
  const source = read(`${base}/K4Keys.qml`);
  assert.match(source, /"mouse_up":\s*"Scroll Up"/);
  assert.match(source, /"mouse_down":\s*"Scroll Down"/);
});

test('K4 keys plugin is a registered utility with pinned dimensions and IPC', () => {
  const plugin = read(`${base}/K4KeysPlugin.qml`);
  const builtins = read(`${base}/K4BuiltinPlugins.qml`);
  assert.match(plugin, /name:\s*"keys"/);
  assert.match(plugin, /priority:\s*65/);
  assert.match(plugin, /application:\s*true/);
  assert.match(plugin, /islandWidth:\s*760/);
  assert.match(plugin, /islandHeight:\s*440/);
  assert.match(plugin, /target:\s*"k4\.keys"/);
  assert.match(plugin, /function\s+openApplication\(\)/);
  assert.match(builtins, /property QtObject keysPlugin:\s*K4ManagedPlugin\s*\{/);
  assert.match(builtins, /name:\s*"keys"/);
  assert.match(builtins, /source:\s*Qt\.resolvedUrl\("K4KeysPlugin\.qml"\)/);
  assert.match(builtins, /sessionPlugin,\s*keysPlugin/);
});

test('K4 keys view keeps upstream searchable grouped keycaps', () => {
  const view = read(`${base}/K4KeysView.qml`);
  assert.match(view, /Search shortcuts, keys, or actions/);
  assert.match(view, /root\.plugin\.entries/);
  assert.match(view, /root\.plugin\.keys\(row\.modelData\.combo\)/);
  assert.match(view, /sectionStart/);
  assert.match(view, /Qt\.Key_Escape/);
});
