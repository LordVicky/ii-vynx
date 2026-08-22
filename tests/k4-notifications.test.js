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

test("k4 notification adapter delegates history and actions to ii Notifications", () => {
    const source = read("modules/ii/k4bar/K4Notifications.qml");

    assert.match(source, /function clear\(\)[\s\S]*?Notifications\.discardAllNotifications\(\)/);
    assert.match(source, /function markRead\(\)[\s\S]*?Notifications\.markAllRead\(\)/);
    assert.match(source, /function dismiss\(notification\)[\s\S]*?Notifications\.discardNotification\(notification\.notificationId\)/);
    assert.match(source, /function invokeAction\(notification, action\)[\s\S]*?Notifications\.attemptInvokeAction\(notification\.notificationId, action\.identifier\)/);
    assert.match(source, /function defaultAction\(notification\)/);
    assert.match(source, /action\.identifier === "default"/);
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
    assert.match(source, /K4Notifications\.invokeAction\(root\.notification, modelData\)/);
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
