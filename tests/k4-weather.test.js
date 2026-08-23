const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '..');
const read = rel => fs.readFileSync(path.join(root, rel), 'utf8');
const base = 'dots/.config/quickshell/ii/modules/ii/k4bar';

test('K4 weather bridges the ii-owned weather service without a second periodic owner', () => {
  const source = read(`${base}/K4Weather.qml`);
  assert.match(source, /readonly property var current:\s*Weather\.data/);
  assert.match(source, /Weather\.getData\(\)/);
  assert.match(source, /Config\.options\.bar\.weather\.city/);
  assert.match(source, /function\s+refresh\(\)/);
  assert.match(source, /function\s+search\(query\)/);
  assert.doesNotMatch(source, /Timer\s*\{[\s\S]*?repeat:\s*true/);
  assert.doesNotMatch(source, /PositionSource\s*\{/);
});

test('K4 weather is a registered utility with upstream dimensions and policies', () => {
  const plugin = read(`${base}/K4WeatherPlugin.qml`);
  const builtins = read(`${base}/K4BuiltinPlugins.qml`);
  assert.match(plugin, /name:\s*"weather"/);
  assert.match(plugin, /priority:\s*62/);
  assert.match(plugin, /application:\s*true/);
  assert.match(plugin, /islandWidth:\s*820/);
  assert.match(plugin, /islandHeight:\s*420/);
  assert.match(plugin, /grabKeyboard:\s*open/);
  assert.match(plugin, /closeOnHoverExit:\s*true/);
  assert.match(plugin, /hoverExitDelay:\s*1000/);
  assert.match(plugin, /target:\s*"k4\.weather"/);
  assert.match(builtins, /property QtObject weatherPlugin:\s*K4WeatherPlugin\s*\{\}/);
});

test('K4 weather view exposes current, hourly, daily, search and refresh surfaces', () => {
  const source = read(`${base}/K4WeatherView.qml`);
  assert.match(source, /K4Weather\.current/);
  assert.match(source, /model:\s*K4Weather\.hourly/);
  assert.match(source, /model:\s*K4Weather\.daily/);
  assert.match(source, /K4Weather\.search\(root\.plugin\.query\)/);
  assert.match(source, /K4Weather\.refresh\(\)/);
  assert.match(source, /Qt\.Key_Escape/);
});
