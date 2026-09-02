const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");

const shellRoot = path.join(__dirname, "../dots/.config/quickshell/ii");
const read = relative => fs.readFileSync(path.join(shellRoot, relative), "utf8");

test("k4 notification presentation separates application identity from media", () => {
    const adapter = read("modules/ii/k4bar/K4Notifications.qml");
    const appIconHelper = adapter.match(/function appIconFor\(notification\) \{[\s\S]*?\n    \}/)?.[0] ?? "";

    assert.match(adapter, /function appIconFor\(notification\)[\s\S]*?notification\.appIcon[\s\S]*?Quickshell\.iconPath/);
    assert.match(adapter, /function imageFor\(notification\)[\s\S]*?notification\?\.image/);
    assert.match(adapter, /function hasImage\(notification\)[\s\S]*?imageFor\(notification\)/);
    assert.match(adapter, /function isCritical\(notification\)[\s\S]*?notification\?\.urgency/);
    assert.doesNotMatch(appIconHelper, /notification\?*\.image/);
});

test("adaptive notification card provides compact and expanded disclosure", () => {
    const cardPath = path.join(shellRoot, "modules/ii/k4bar/K4NotificationCard.qml");
    assert.equal(fs.existsSync(cardPath), true);

    const card = fs.readFileSync(cardPath, "utf8");
    assert.match(card, /property var notification/);
    assert.match(card, /property bool expanded/);
    assert.match(card, /property bool bandMode/);
    assert.match(card, /K4Notifications\.appIconFor\(notification\)/);
    assert.match(card, /K4Notifications\.imageFor\(notification\)/);
    assert.match(card, /K4Notifications\.isCritical\(notification\)/);
    assert.match(card, /if \(!bandMode\)[\s\S]*?return summary\.length > 0 \? summary : "New notification"/);
    assert.match(card, /visible:\s*root\.expanded && root\.hasImage/);
    assert.match(card, /fillMode:\s*Image\.PreserveAspectCrop/);
    assert.match(card, /asynchronous:\s*true/);
    assert.match(card, /cache:\s*true/);
    assert.match(card, /id:\s*messageColumn[\s\S]*?font\.pixelSize:\s*16[\s\S]*?maximumLineCount:\s*2/);
    assert.match(card, /id:\s*messageColumn[\s\S]*?font\.pixelSize:\s*13[\s\S]*?maximumLineCount:\s*3/);
    assert.match(card, /id:\s*messageRow[\s\S]*?Layout\.preferredHeight:\s*Math\.max\(messageColumn\.implicitHeight,[\s\S]*?notificationImage\.visible \? 76 : 0\)/);
    assert.doesNotMatch(card, /id:\s*messageRow[\s\S]*?Layout\.fillHeight:\s*true/);
    assert.match(card, /model:\s*root\.buttons/);
    assert.match(card, /signal dismissRequested\(\)/);
    assert.match(card, /signal actionRequested\(var action\)/);
    assert.match(card, /component CloseButton:[\s\S]*?mouse\.accepted = true[\s\S]*?closeButton\.clicked\(\)/);
    assert.equal((card.match(/onClicked:\s*root\.dismissRequested\(\)/g) ?? []).length, 2);
    assert.match(card, /id:\s*actionMouse[\s\S]*?mouse\.accepted = true[\s\S]*?root\.actionRequested\(/);
});

test("main toast morphs between compact and content-dense expanded geometry", () => {
    const builtins = read("modules/ii/k4bar/K4BuiltinPlugins.qml");
    const view = read("modules/ii/k4bar/K4ToastView.qml");

    assert.match(builtins, /name:\s*"toast"[\s\S]*?priority:\s*59[\s\S]*?transitorio:\s*true/);
    assert.match(builtins, /readonly property bool expanded:\s*IslandState\.hovered/);
    assert.match(builtins, /islandWidth:\s*expanded[\s\S]*?hasImage \? 520 : 500[\s\S]*?: 382/);
    assert.match(builtins, /islandHeight:\s*!expanded \? 54/);
    assert.match(builtins, /hasImage && buttons\.length > 0 \? 180/);
    assert.match(builtins, /hasImage \? 136/);
    assert.match(builtins, /buttons\.length > 0 \? 148 : 120/);
    assert.doesNotMatch(builtins, /hasImage && buttons\.length > 0 \? 214|hasImage \? 168|buttons\.length > 0 \? 170 : 142/);
    assert.match(builtins, /handlesBackgroundTap:\s*true/);
    assert.match(builtins, /K4Notifications\.activate\(K4Notifications\.latest\)/);

    assert.match(view, /K4NotificationCard\s*\{/);
    assert.match(view, /expanded:\s*IslandState\.hovered/);
    assert.match(view, /onDismissRequested:\s*K4Notifications\.dismissToast\(\)/);
    assert.match(view, /K4Notifications\.invokeAction\(root\.notification, action\)/);
    assert.doesNotMatch(view, /ClippingRectangle\s*\{/);
});

test("control center notification history favors readable content over tiny metadata", () => {
    const view = read("modules/ii/k4bar/K4PanelNotificationsView.qml");

    assert.match(view, /readonly property string bodyText:/);
    assert.match(view, /height:\s*78 \+ \(actions\.length > 0 \? 32 : 0\)/);
    assert.match(view, /font\.pixelSize:\s*14[\s\S]*?maximumLineCount:\s*1/);
    assert.match(view, /font\.pixelSize:\s*12[\s\S]*?wrapMode:\s*Text\.WordWrap[\s\S]*?maximumLineCount:\s*2/);
    assert.match(view, /Layout\.preferredHeight:\s*24/);
    assert.doesNotMatch(view, /font\.pixelSize:\s*10[\s\S]*?maximumLineCount:\s*1/);
});

test("compact band reuses the adaptive card without reserving compositor space", () => {
    const host = read("modules/ii/k4bar/K4ToastBandHost.qml");

    assert.match(host, /implicitWidth:\s*420/);
    assert.match(host, /implicitHeight:\s*54/);
    assert.match(host, /exclusionMode:\s*ExclusionMode\.Ignore/);
    assert.match(host, /WlrLayershell\.layer:\s*WlrLayer\.Overlay/);
    assert.match(host, /K4NotificationCard\s*\{[\s\S]*?expanded:\s*false[\s\S]*?bandMode:\s*true/);
    assert.match(host, /onEntered:\s*K4Notifications\.holdToast\(\)/);
    assert.match(host, /onExited:\s*K4Notifications\.resumeToast\(\)/);
    assert.match(host, /K4Notifications\.activate\(K4Notifications\.latest\)/);
    assert.match(host, /onDismissRequested:\s*K4Notifications\.dismissToast\(\)/);
    assert.match(host, /K4Notifications\.invokeAction\(K4Notifications\.latest, action\)/);
});

test("notification controls stay above and isolated from default-click hosts", () => {
    const bar = read("modules/ii/k4bar/K4Bar.qml");
    const card = read("modules/ii/k4bar/K4NotificationCard.qml");
    const host = read("modules/ii/k4bar/K4ToastBandHost.qml");
    const view = read("modules/ii/k4bar/K4ToastView.qml");

    assert.match(bar, /MouseArea\s*\{[\s\S]*?onClicked:\s*controller\.backgroundTap\(panelWindow\.screen\.name\)[\s\S]*?Repeater\s*\{[\s\S]*?delegate:\s*Loader/);
    assert.ok(host.indexOf("MouseArea {") < host.indexOf("K4NotificationCard {"));
    assert.doesNotMatch(card, /K4Notifications\.activate/);
    assert.doesNotMatch(view, /onDismissRequested:[^\n]*activate/);
    assert.doesNotMatch(view, /onActionRequested:[\s\S]*?K4Notifications\.activate/);
});
