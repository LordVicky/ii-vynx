const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");

const shellRoot = path.join(__dirname, "../dots/.config/quickshell/ii");
const read = relative => fs.readFileSync(path.join(shellRoot, relative), "utf8");

test("k4 notification adapter reuses ii notification ownership", () => {
    const source = read("modules/ii/k4bar/K4Notifications.qml");

    assert.match(source, /import qs\.services/);
    assert.doesNotMatch(source, /NotificationServer\s*\{/);
    assert.match(source, /readonly property var recent:\s*Notifications\.list\.slice\(\)\.reverse\(\)/);
    assert.match(source, /target:\s*Notifications/);
    assert.match(source, /function onNotify\(notification\)/);
    assert.match(source, /root\.latest = notification/);
    assert.match(source, /root\.toastOpen = true/);
    assert.match(source, /interval:\s*5000/);
});

test("k4 mode keeps one shared notification daemon and inhibits the legacy popup pipeline", () => {
    const adapter = read("modules/ii/k4bar/K4Notifications.qml");
    const service = read("services/Notifications.qml");
    const family = read("panelFamilies/IllogicalImpulseFamily.qml");

    assert.equal((service.match(/\bNotificationServer\s*\{/g) ?? []).length, 1);
    assert.doesNotMatch(adapter, /NotificationServer\s*\{/);
    assert.match(service, /readonly property bool k4PresentationActive:\s*Config\.options\.panelFamily === "ii"[\s\S]*?Config\.options\.bar\.variant === "k4"/);
    assert.match(service, /property bool popupInhibited:\s*k4PresentationActive[\s\S]*?GlobalStates\?\.sidebarRightOpen[\s\S]*?silent/);
    assert.match(service, /if \(!root\.popupInhibited\) \{[\s\S]*?newNotifObject\.popup = true[\s\S]*?root\.unread\+\+/);
    assert.match(service, /root\.notify\(newNotifObject\)/);
    assert.match(
        family,
        /PanelLoader\s*\{\s*extraCondition:\s*usingStandardBar;\s*component:\s*NotificationPopup\s*\{\s*\}\s*\}/
    );
});

test("k4 notification adapter delegates history and actions to ii Notifications", () => {
    const source = read("modules/ii/k4bar/K4Notifications.qml");

    assert.match(source, /function clear\(\)[\s\S]*?Notifications\.discardAllNotifications\(\)/);
    assert.match(source, /function markRead\(\)[\s\S]*?Notifications\.markAllRead\(\)/);
    assert.match(source, /function dismiss\(notification\)[\s\S]*?Notifications\.discardNotification\(notification\.notificationId\)/);
    assert.match(source, /function invokeAction\(notification, action\)[\s\S]*?Notifications\.attemptInvokeAction\(notification\.notificationId, action\.identifier\)/);
    assert.match(source, /function defaultAction\(notification\)[\s\S]*?actions\[i\]\.identifier === "default"[\s\S]*?return actions\[i\]/);
    assert.match(source, /function activate\(notification\)[\s\S]*?defaultAction\(notification\)/);
    assert.match(source, /function buttons\(notification\)[\s\S]*?action\.identifier !== "default"/);
    assert.match(source, /function stripHeight\(max\)[\s\S]*?18 \+ n \* 34 \+ \(n - 1\) \* 4/);
});

test("standard notification popup is disabled while k4 owns notification presentation", () => {
    const family = read("panelFamilies/IllogicalImpulseFamily.qml");

    assert.match(
        family,
        /PanelLoader\s*\{\s*extraCondition:\s*usingStandardBar;\s*component:\s*NotificationPopup\s*\{\s*\}\s*\}/
    );
});

test("k4 toast participates as the pinned priority-59 transient", () => {
    const builtins = read("modules/ii/k4bar/K4BuiltinPlugins.qml");

    assert.match(builtins, /toastPlugin/);
    assert.match(builtins, /name:\s*"toast"[\s\S]*?priority:\s*59[\s\S]*?transitorio:\s*true/);
    assert.match(builtins, /active:\s*enabled && K4Notifications\.toastOpen && !K4Notifications\.inBand/);
    assert.match(builtins, /islandWidth:\s*440/);
    assert.match(builtins, /islandHeight:\s*K4Notifications\.buttons\(K4Notifications\.latest\)\.length > 0 \? 112 : 96/);
    assert.match(builtins, /handlesBackgroundTap:\s*true/);
    assert.match(builtins, /onBackgroundTapped:[\s\S]*?K4Notifications\.activate\(K4Notifications\.latest\)[\s\S]*?K4Notifications\.dismissToast\(\)/);
    assert.match(builtins, /function close\(\)[\s\S]*?K4Notifications\.dismissToast\(\)/);
    assert.match(builtins, /view:\s*Component \{ K4ToastView \{\} \}/);
});

test("k4 toast view exposes notification content, actions and dismissal", () => {
    const source = read("modules/ii/k4bar/K4ToastView.qml");

    assert.match(source, /readonly property var notification:\s*K4Notifications\.latest/);
    assert.match(source, /readonly property var buttons:\s*K4Notifications\.buttons\(notification\)/);
    assert.match(source, /notification\?\.summary \?\? ""/);
    assert.match(source, /notification\?\.appName \?\? ""/);
    assert.match(source, /notification\?\.body \?\? ""/);
    assert.match(source, /model:\s*root\.buttons/);
    assert.match(source, /onClicked:[\s\S]*?K4Notifications\.invokeAction\(root\.notification, actionChip\.modelData\)/);
    assert.match(source, /K4Notifications\.dismissToast\(\)/);
});

test("explicit island owners route notifications to a non-reserving band window", () => {
    const adapter = read("modules/ii/k4bar/K4Notifications.qml");
    const host = read("modules/ii/k4bar/K4ToastBandHost.qml");
    const bar = read("modules/ii/k4bar/K4Bar.qml");

    assert.match(adapter, /readonly property var passiveToastOwners:[\s\S]*?"idle"[\s\S]*?"clock"[\s\S]*?"player"[\s\S]*?"volume"/);
    assert.match(adapter, /function routeToast\(\)[\s\S]*?inBand = passiveToastOwners\.indexOf\(owner\) < 0/);
    assert.match(adapter, /target:\s*IslandState[\s\S]*?function onHoveredChanged\(\)[\s\S]*?holdToast\(\)[\s\S]*?resumeToast\(\)/);

    assert.match(bar, /K4ToastBandHost\s*\{\s*\}/);
    assert.match(host, /Variants\s*\{[\s\S]*?model:\s*GlobalStates\.screenLocked \? \[\] : Quickshell\.screens/);
    assert.match(host, /PanelWindow\s*\{[\s\S]*?exclusionMode:\s*ExclusionMode\.Ignore/);
    assert.match(host, /implicitWidth:\s*420/);
    assert.match(host, /implicitHeight:\s*56/);
    assert.match(host, /K4Notifications\.toastOpen && K4Notifications\.inBand/);
    assert.match(host, /IslandState\.rects\[bandWindow\.screen\.name\]/);
    assert.match(host, /K4Notifications\.activate\(K4Notifications\.latest\)/);
    assert.match(host, /K4Notifications\.dismissToast\(\)/);
    assert.match(host, /K4Notifications\.holdToast\(\)/);
    assert.match(host, /K4Notifications\.resumeToast\(\)/);
});

test("notification presentation lifts to overlay only while it needs to beat fullscreen", () => {
    const bar = read("modules/ii/k4bar/K4Bar.qml");
    const band = read("modules/ii/k4bar/K4ToastBandHost.qml");

    assert.match(bar, /readonly property bool notificationOverlay:\s*pluginVisible\?\.name === "toast"/);
    assert.match(bar, /WlrLayershell\.layer:\s*notificationOverlay \? WlrLayer\.Overlay : WlrLayer\.Top/);
    assert.doesNotMatch(bar, /aboveWindows:\s*true/);

    assert.match(band, /import Quickshell\.Wayland/);
    assert.match(band, /WlrLayershell\.namespace:\s*"quickshell:k4bar-notification"/);
    assert.match(band, /WlrLayershell\.layer:\s*WlrLayer\.Overlay/);
    assert.match(band, /WlrLayershell\.keyboardFocus:\s*WlrKeyboardFocus\.None/);
    assert.match(band, /exclusionMode:\s*ExclusionMode\.Ignore/);
    assert.doesNotMatch(band, /aboveWindows:\s*true/);
});

test("recent notification strip matches pinned k4 max-three history behavior", () => {
    const strip = read("modules/ii/k4bar/K4NotifStrip.qml");
    const theme = read("modules/ii/k4bar/K4Theme.qml");

    assert.match(strip, /property int max:\s*3/);
    assert.match(strip, /readonly property int shown:\s*Math\.min\(K4Notifications\.recent\.length, max\)/);
    assert.match(strip, /readonly property int rowHeight:\s*34/);
    assert.match(strip, /readonly property int neededHeight:\s*K4Notifications\.stripHeight\(max\)/);
    assert.match(strip, /model:\s*K4Notifications\.recent\.slice\(0, strip\.shown\)/);
    assert.match(strip, /K4Notifications\.iconFor\(modelData\)/);
    assert.match(strip, /K4Notifications\.clear\(\)/);
    assert.match(strip, /K4Notifications\.dismiss\(row\.modelData\)/);
    assert.match(strip, /K4Notifications\.activate\(row\.modelData\)/);
    assert.match(strip, /"\+" \+ \(K4Notifications\.recent\.length - strip\.shown\) \+ " more"/);
    assert.match(theme, /bell:\s*String\.fromCodePoint\(0xF009A\)/);
    assert.match(theme, /close:\s*String\.fromCodePoint\(0xF0156\)/);
    assert.match(theme, /clearAll:\s*String\.fromCodePoint\(0xF039F\)/);
});

test("clock and player reserve exactly the notification strip space they render", () => {
    const builtins = read("modules/ii/k4bar/K4BuiltinPlugins.qml");
    const clock = read("modules/ii/k4bar/K4ClockView.qml");
    const player = read("modules/ii/k4bar/K4PlayerView.qml");

    assert.match(builtins, /name:\s*"clock"[\s\S]*?notificationStripHeight:\s*K4Notifications\.stripHeight\(3\)[\s\S]*?islandHeight:\s*68 \+ \(notificationStripHeight > 0 \? notificationStripHeight \+ 18 : 0\)/);
    assert.match(builtins, /name:\s*"player"[\s\S]*?notificationStripHeight:\s*K4Notifications\.stripHeight\(3\)[\s\S]*?islandHeight:\s*\(K4Media\.hasTimeline \? 140 : 115\)[\s\S]*?notificationStripHeight \+ 15/);
    assert.match(clock, /anchors\.bottomMargin:\s*K4Notifications\.recent\.length > 0 \? 12 : 0/);
    assert.match(clock, /K4NotifStrip\s*\{[\s\S]*?max:\s*3[\s\S]*?Layout\.fillWidth:\s*true/);
    assert.match(player, /K4NotifStrip\s*\{[\s\S]*?max:\s*3[\s\S]*?Layout\.fillWidth:\s*true[\s\S]*?Layout\.topMargin:\s*2/);
});
