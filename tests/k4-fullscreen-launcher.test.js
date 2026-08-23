const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '..');
const read = rel => fs.readFileSync(path.join(root, rel), 'utf8');

test('default Super launcher binding bypasses application shortcut inhibition', () => {
  const source = read('dots/.config/hypr/hyprland/launcher.lua');
  assert.match(source, /hl\.unbind\("SUPER \+ SUPER_L"\)/);
  assert.match(source, /hl\.unbind\("SUPER \+ SUPER_R"\)/);
  assert.match(source, /hl\.bind\("SUPER \+ SUPER_L",\s*hl\.dsp\.global\("quickshell:searchToggleRelease"\),\s*\{\s*bypass = true/);
  assert.match(source, /hl\.bind\("SUPER \+ SUPER_R",\s*hl\.dsp\.global\("quickshell:searchToggleRelease"\),\s*\{\s*bypass = true/);
  assert.equal((source.match(/bypass = true/g) || []).length, 4);
});

test('launcher rewrite runs after defaults but before user custom keybinds', () => {
  const source = read('dots/.config/hypr/hyprland.lua');
  const defaults = source.indexOf('require("hyprland.keybinds")');
  const launcher = source.indexOf('require("hyprland.launcher")');
  const custom = source.indexOf('require("custom.keybinds")');
  assert.ok(defaults >= 0 && launcher > defaults && custom > launcher);
});

test('K4 keeps the same searchToggleRelease backend name as Standard', () => {
  const routing = read('dots/.config/quickshell/ii/modules/ii/k4bar/K4LauncherRouting.qml');
  const launcher = read('dots/.config/hypr/hyprland/launcher.lua');
  assert.match(routing, /name:\s*"searchToggleRelease"/);
  assert.match(launcher, /quickshell:searchToggleRelease/);
  assert.doesNotMatch(launcher, /k4\.launcher/);
});
