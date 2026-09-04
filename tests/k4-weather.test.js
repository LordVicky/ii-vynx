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

test('K4 weather adapter exposes hourly wind and UV from the existing forecast response', () => {
  const source = read(`${base}/K4Weather.qml`);
  assert.match(source, /readonly property string windUnit:\s*Weather\.useUSCS\s*\?\s*"mph"\s*:\s*"km\/h"/);
  assert.match(source, /windValue:\s*Number\(Weather\.useUSCS\s*\?\s*\(slot\.windspeedMiles/);
  assert.match(source, /slot\.windspeedKmph/);
  assert.match(source, /uv:\s*Number\(slot\.uvIndex/);
});

test('K4 weather summary copy derives from live condition and forecast state', () => {
  const source = read(`${base}/K4Weather.qml`);
  assert.match(source, /readonly property string summary:\s*root\.summaryText\(\)/);
  assert.match(source, /function\s+summaryText\(\)/);
  assert.match(source, /peakRainChance\(\)/);
  assert.match(source, /current\.wCode/);
  assert.match(source, /Thunderstorms|Rainy|Fog|Cloudy|Clear/);
});

test('K4 weather narrative combines live atmospheric context and event-driven air quality', () => {
  const source = read(`${base}/K4Weather.qml`);
  assert.match(source, /property var airQuality:\s*\(\{\}\)/);
  assert.match(source, /function\s+windDescription\(\)/);
  assert.match(source, /Humidity \$\{Math\.round\(humidity\)\}%/);
  assert.match(source, /Rain risk low · \$\{peak\}% peak/);
  assert.match(source, /AQI \$\{Math\.round\(aqi\)\} \$\{root\.airQualityStatus\(aqi\)\.toLowerCase\(\)\}/);
  assert.match(source, /dust \$\{dustState\}/);
  assert.match(source, /visibility \$\{root\.visibilityStatus/);
  assert.match(source, /UV \$\{root\.uvStatus/);
  assert.match(source, /environment\.slice\(0,\s*2\)/);
  assert.match(source, /return parts\.join\(" "\)/);
  assert.match(source, /function\s+refreshAirQuality\(latitude, longitude\)/);
  assert.match(source, /air-quality-api\.open-meteo\.com\/v1\/air-quality/);
  assert.match(source, /current=us_aqi,pm2_5,pm10,dust/);
  assert.match(source, /root\.refreshAirQuality\(latitude, longitude\)/);
});

test('K4 weather uses three isolated exact pages for forecast, hourly charts and history', () => {
  const source = read(`${base}/K4WeatherView.qml`);
  assert.match(source, /id:\s*pageViewport[\s\S]*?clip:\s*true/);
  assert.match(source, /id:\s*pageStack[\s\S]*?height:\s*pageViewport\.height\s*\*\s*3/);
  assert.match(source, /y:\s*-root\.pageIndex\s*\*\s*pageViewport\.height/);
  assert.match(source, /sourceComponent:\s*overviewPage[\s\S]*?clip:\s*true/);
  assert.match(source, /sourceComponent:\s*detailsPage[\s\S]*?clip:\s*true/);
  assert.match(source, /sourceComponent:\s*historyPage[\s\S]*?clip:\s*true/);
  assert.match(source, /model:\s*3/);
  assert.match(source, /Math\.min\(2,[\s\S]*?root\.pageIndex\s*\+\s*direction/);
  assert.match(source, /id:\s*pageWheelGuard[\s\S]*?interval:\s*240/);
  assert.doesNotMatch(source, /snapMode:\s*ListView\.SnapOneItem/);
});

test('K4 weather keeps all explicit UI text at an eleven-pixel readability floor', () => {
  const source = read(`${base}/K4WeatherView.qml`);
  assert.doesNotMatch(source, /renderType:\s*Text\.NativeRendering/);
  assert.doesNotMatch(source, /font\.pixelSize:\s*(?:[0-9]|10)\b/);
  assert.match(source, /component MetaText:[\s\S]*?font\.pixelSize:\s*11/);
  assert.match(source, /component LabelText:[\s\S]*?font\.pixelSize:\s*11/);
  assert.match(source, /component ValueText:[\s\S]*?font\.pixelSize:\s*12/);
});

test('K4 weather secondary text uses readable ink contrast instead of muted gray', () => {
  const source = read(`${base}/K4WeatherView.qml`);
  assert.match(source, /component MetaText:[\s\S]*?color:\s*K4Theme\.ink[\s\S]*?opacity:\s*0\.68/);
  assert.match(source, /component LabelText:[\s\S]*?color:\s*K4Theme\.ink[\s\S]*?opacity:\s*0\.78/);
});

test('K4 weather line charts use high-contrast strokes with a color-to-transparent gradient fill', () => {
  const source = read(`${base}/K4WeatherView.qml`);
  assert.match(source, /ctx\.strokeStyle\s*=\s*String\(K4Theme\.panelLineStrong\)/);
  assert.match(source, /ctx\.lineWidth\s*=\s*2\.4/);
  assert.match(source, /ctx\.arc\(p\.x,\s*p\.y,\s*3/);
  assert.match(source, /createLinearGradient\(0,\s*0,\s*0,\s*height\)/);
  assert.match(source, /addColorStop\(0,\s*String\(lineChart\.lineColor\)\)/);
  assert.match(source, /addColorStop\(1,\s*"transparent"\)/);
});

test('K4 weather removes colliding helper labels and page-two chrome', () => {
  const source = read(`${base}/K4WeatherView.qml`);
  assert.doesNotMatch(source, /Scroll for hourly details|Scroll for 7-day history/);
  assert.doesNotMatch(source, /rain · high \/ low/);
  assert.doesNotMatch(source, /text:\s*"Hourly details"/);
  assert.doesNotMatch(source, /Precipitation probability and humidity through today/);
  assert.doesNotMatch(source, /LabelText\s*\{\s*text:\s*"local time"\s*\}/);
});

test('K4 weather overview uses six readable metrics in a three-by-two card grid', () => {
  const source = read(`${base}/K4WeatherView.qml`);
  assert.match(source, /id:\s*overviewMetricGrid[\s\S]*?columns:\s*3[\s\S]*?rows:\s*2/);
  assert.match(source, /id:\s*overviewMetricCard/);
  assert.match(source, /text:\s*root\.factLabel\(index\)/);
  assert.match(source, /text:\s*root\.factNote\(index\)/);
  assert.match(source, /text:\s*root\.factValue\(index\)[\s\S]*?font\.pixelSize:\s*17/);
  assert.doesNotMatch(source, /root\.factLabel\(index\)\.toUpperCase\(\)/);
});

test('K4 weather page one ends with the hourly temperature chart instead of a three-day list', () => {
  const source = read(`${base}/K4WeatherView.qml`);
  assert.doesNotMatch(source, /Next 3 days/);
  assert.doesNotMatch(source, /Math\.min\(3,\s*K4Weather\.daily\.length\)/);
});

test('K4 weather page two is a compact four-metric grid', () => {
  const source = read(`${base}/K4WeatherView.qml`);
  assert.match(source, /id:\s*detailsPage[\s\S]*?GridLayout\s*\{[\s\S]*?columns:\s*2/);
  assert.match(source, /text:\s*"Precipitation chance"/);
  assert.match(source, /text:\s*"Humidity"/);
  assert.match(source, /text:\s*"Wind"/);
  assert.match(source, /text:\s*"UV index"/);
  assert.match(source, /values:\s*root\.hourlyValues\("windValue"\)/);
  assert.match(source, /values:\s*root\.hourlyValues\("uv"\)/);
  assert.match(source, /lineColor:\s*"#c0b4ff"/);
  assert.match(source, /lineColor:\s*"#72e0c4"/);
  assert.match(source, /lineColor:\s*"#ffbd6a"/);
});

test('K4 precipitation bars scale to a local probability ceiling instead of fixed 100 percent', () => {
  const source = read(`${base}/K4WeatherView.qml`);
  assert.match(source, /function\s+precipitationScaleMaximum\(\)/);
  assert.match(source, /const ceilings\s*=\s*\[10,\s*25,\s*50,\s*75,\s*100\]/);
  assert.match(source, /readonly property real scaleMaximum:\s*root\.precipitationScaleMaximum\(\)/);
  assert.match(source, /readonly property real scaledFraction:[\s\S]*?chance\s*\/\s*Math\.max\(1,\s*precipPanel\.scaleMaximum\)/);
  assert.match(source, /parent\.height\s*\*\s*scaledFraction/);
  assert.doesNotMatch(source, /parent\.height\s*\*\s*chance\s*\/\s*100/);
});

test('K4 weather today chart is temperature-only with a smooth curve and readable bottom axis', () => {
  const source = read(`${base}/K4WeatherView.qml`);
  const overview = source.match(/id:\s*overviewPage[\s\S]*?\n\s*Component\s*\{\n\s*id:\s*detailsPage/)?.[0] || '';
  assert.match(source, /property bool smoothCurve:\s*false/);
  assert.match(source, /ctx\.bezierCurveTo\(/);
  assert.match(overview, /ValueText\s*\{\s*text:\s*"Temperature"/);
  assert.match(overview, /id:\s*todayTempChart[\s\S]*?smoothCurve:\s*true[\s\S]*?gridOpacity:\s*0\.55/);
  assert.match(overview, /text:\s*K4Weather\.hourly\[index\]\.temp\s*\|\|\s*"--"[\s\S]*?font\.pixelSize:\s*12/);
  assert.match(overview, /text:\s*K4Weather\.hourly\[index\]\.hour\s*\|\|\s*""[\s\S]*?font\.pixelSize:\s*12/);
  assert.doesNotMatch(overview, /Rain chance|hourly\[index\]\.rain|todayTemperatureLabels/);
});

test('K4 weather history temperature span is an emphasized right-aligned header value', () => {
  const source = read(`${base}/K4WeatherView.qml`);
  assert.match(source, /Layout\.alignment:\s*Qt\.AlignRight\s*\|\s*Qt\.AlignVCenter/);
  assert.match(source, /text:\s*`\$\{root\.tempValueText\(root\.historyMinimum\(\)\)\} – \$\{root\.tempValueText\(root\.historyMaximum\(\)\)\}`/);
  assert.match(source, /font\.pixelSize:\s*14[\s\S]*?horizontalAlignment:\s*Text\.AlignRight/);
});

test('K4 weather history headers mirror the row geometry and use title case', () => {
  const source = read(`${base}/K4WeatherView.qml`);
  assert.match(source, /Layout\.preferredHeight:\s*32[\s\S]*?spacing:\s*0/);
  assert.match(source, /text:\s*"Temperature range"/);
  assert.match(source, /text:\s*"Rain"/);
  assert.match(source, /text:\s*"Humidity"/);
  assert.match(source, /Item\s*\{\s*Layout\.preferredWidth:\s*10\s*\}/);
  assert.match(source, /Item\s*\{\s*Layout\.preferredWidth:\s*16\s*\}/);
});

test('K4 weather lets the host own the rounded OLED background', () => {
  const source = read(`${base}/K4WeatherView.qml`);
  assert.doesNotMatch(source, /Rectangle\s*\{\s*anchors\.fill:\s*parent\s*color:\s*K4Theme\.islandBg\s*z:\s*-1/);
  assert.doesNotMatch(source, /color:\s*K4Theme\.(?:surface|surfaceHi|panelSurface|panelSurfaceHi|panelSurfaceHot)/);
});

test('K4 weather preserves search, refresh and keyboard behavior', () => {
  const source = read(`${base}/K4WeatherView.qml`);
  assert.match(source, /K4Weather\.search\(root\.plugin\.query\)/);
  assert.match(source, /K4Weather\.refresh\(\)/);
  assert.match(source, /Qt\.Key_Escape/);
  assert.match(source, /root\.plugin\.choose\(cityRow\.modelData\)/);
});
