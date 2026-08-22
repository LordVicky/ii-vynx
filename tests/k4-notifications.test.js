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
