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

test('K4 weather uses the live ii GPS coordinate keys', () => {
  const source = read(`${base}/K4Weather.qml`);
  assert.match(source, /Weather\.location\.lat/);
  assert.match(source, /Weather\.location\.long/);
  assert.doesNotMatch(source, /Weather\.location\.lon\b/);
});

test('K4 weather uses the Material Design glyph range carried by the shell font', () => {
  const source = read(`${base}/K4Weather.qml`);
  for (const code of ['F0599', 'F0595', 'F0590', 'F0591', 'F0598', 'F067E', 'F0597'])
    assert.match(source, new RegExp(`0x${code}`));
  assert.doesNotMatch(source, /0xE3[0-9A-F]{2}/i);
});

test('K4 weather is directly registered as a compact utility surface', () => {
  const plugin = read(`${base}/K4WeatherPlugin.qml`);
  const builtins = read(`${base}/K4BuiltinPlugins.qml`);
  assert.match(plugin, /name:\s*"weather"/);
  assert.match(plugin, /priority:\s*62/);
  assert.match(plugin, /application:\s*true/);
  assert.match(plugin, /islandWidth:\s*760/);
  assert.match(plugin, /islandHeight:\s*440/);
  assert.match(plugin, /grabKeyboard:\s*open/);
  assert.match(plugin, /closeOnHoverExit:\s*true/);
  assert.match(plugin, /hoverExitDelay:\s*1000/);
  assert.match(plugin, /target:\s*"k4\.weather"/);
  assert.match(builtins, /property QtObject weatherPlugin:\s*K4WeatherPlugin\s*\{\}/);
});

test('K4 weather adapter exposes real hourly humidity and seven-day history data', () => {
  const source = read(`${base}/K4Weather.qml`);
  assert.match(source, /property var history:\s*\[\]/);
  assert.match(source, /humidity:\s*Number\(slot\.humidity/);
  assert.match(source, /archive-api\.open-meteo\.com\/v1\/archive/);
  assert.match(source, /relative_humidity_2m_mean/);
  assert.match(source, /precipitation_sum/);
  assert.match(source, /temperature_2m_max/);
  assert.match(source, /temperature_2m_min/);
});

test('K4 weather summary copy derives from live condition and forecast state', () => {
  const source = read(`${base}/K4Weather.qml`);
  assert.match(source, /readonly property string summary:\s*root\.summaryText\(\)/);
  assert.match(source, /function\s+summaryText\(\)/);
  assert.match(source, /peakRainChance\(\)/);
  assert.match(source, /current\.wCode/);
  assert.match(source, /Thunderstorms|Rainy|Fog|Cloudy|Clear/);
});

test('K4 weather view is a two-page vertical snap surface with analytical charts', () => {
  const source = read(`${base}/K4WeatherView.qml`);
  assert.match(source, /orientation:\s*ListView\.Vertical/);
  assert.match(source, /snapMode:\s*ListView\.SnapOneItem/);
  assert.match(source, /model:\s*2/);
  assert.match(source, /Precipitation chance/);
  assert.match(source, /Humidity/);
  assert.match(source, /7-day history/);
  assert.match(source, /K4Weather\.summary/);
  assert.match(source, /K4Weather\.history/);
  assert.match(source, /K4Weather\.hourly/);
});

test('K4 weather keeps content surfaces black instead of colored dashboard cards', () => {
  const source = read(`${base}/K4WeatherView.qml`);
  assert.doesNotMatch(source, /color:\s*K4Theme\.(?:surface|surfaceHi|panelSurface|panelSurfaceHi|panelSurfaceHot)/);
  assert.match(source, /K4Theme\.islandBg/);
});

test('K4 weather preserves search, refresh and keyboard behavior', () => {
  const source = read(`${base}/K4WeatherView.qml`);
  assert.match(source, /K4Weather\.search\(root\.plugin\.query\)/);
  assert.match(source, /K4Weather\.refresh\(\)/);
  assert.match(source, /Qt\.Key_Escape/);
});
