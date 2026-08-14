import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.ii.background.widgets

AbstractBackgroundWidget {
    id: root
    configEntryName: "battery"
    hoverEnabled: true

    property real dragScale: -1
    readonly property real widgetScale: dragScale >= 0 ? dragScale : (Config.options.background.widgets.battery.scale ?? 1)
    readonly property var layoutOrder: ["list", "compact"]
    readonly property string layoutMode: {
        const mode = Config.options.background.widgets.battery.layout ?? "list";
        return root.layoutOrder.indexOf(mode) >= 0 ? mode : "list";
    }
    readonly property bool compactMode: layoutMode === "compact"

    function cycleLayout() {
        const index = root.layoutOrder.indexOf(root.layoutMode);
        Config.options.background.widgets.battery.layout = root.layoutOrder[(index + 1) % root.layoutOrder.length];
    }

    BatteryDevices { id: batteryDevices }

    // AbstractWidget is already a draggable MouseArea. A small pointer movement
    // can cancel `clicked`, so start the refresh from the left-button press.
    Connections {
        target: root
        function onPressed(mouse) {
            if (mouse.button === Qt.LeftButton)
                AppleBatteryStatus.refresh();
        }
    }

    readonly property int rowHeight: 36
    readonly property int rowSpacing: 8
    property int layoutRowCount: 1
    readonly property real listAuthoredHeight: 88 + layoutRowCount * 44

    readonly property int compactSwitchThreshold: 5
    readonly property int compactTieThreshold: 2
    property string compactDeviceId: ""
    property string pendingCompactDeviceId: ""
    property bool initialDeviceSyncDone: false
    property int recencySerial: 0
    property var deviceRecency: ({})

    property string compactSource: ""
    property string compactName: ""
    property string compactIcon: "battery_full"
    property real compactPercentage: 0
    property bool compactCharging: false
    property bool compactChargingKnown: false
    property bool compactStale: false

    readonly property int chargingCount: {
        let count = 0;
        for (let i = 0; i < deviceModel.count; ++i) {
            const device = deviceModel.get(i);
            if (!device.stale && device.chargingKnown && device.charging)
                count++;
        }
        return count;
    }

    implicitWidth: card.implicitWidth
    implicitHeight: card.implicitHeight

    function indexOfDevice(id) {
        for (let i = 0; i < deviceModel.count; ++i) {
            if (deviceModel.get(i).deviceId === id)
                return i;
        }
        return -1;
    }

    function touchDevice(id) {
        root.recencySerial += 1;
        const copy = Object.assign({}, root.deviceRecency);
        copy[id] = root.recencySerial;
        root.deviceRecency = copy;
    }

    function recencyOf(id) {
        return root.deviceRecency[id] ?? 0;
    }

    function copyCompactDevice(id) {
        const index = root.indexOfDevice(id);
        if (index < 0) {
            root.compactSource = "";
            root.compactName = "";
            root.compactIcon = "battery_full";
            root.compactPercentage = 0;
            root.compactCharging = false;
            root.compactChargingKnown = false;
            root.compactStale = false;
            return;
        }

        const device = deviceModel.get(index);
        root.compactSource = device.source;
        root.compactName = device.name;
        root.compactIcon = device.icon;
        root.compactPercentage = device.percentage;
        root.compactCharging = device.charging;
        root.compactChargingKnown = device.chargingKnown;
        root.compactStale = device.stale;
    }

    function betterCompactCandidate(best, candidate) {
        if (best === null)
            return candidate;

        const candidatePercent = Math.round(candidate.percentage * 100);
        const bestPercent = Math.round(best.percentage * 100);
        const delta = candidatePercent - bestPercent;

        if (delta < -root.compactTieThreshold)
            return candidate;

        if (Math.abs(delta) <= root.compactTieThreshold
                && root.recencyOf(candidate.deviceId) > root.recencyOf(best.deviceId)) {
            return candidate;
        }

        return best;
    }

    function bestCompactCandidate() {
        if (deviceModel.count === 0)
            return "";

        let best = null;
        for (let i = 0; i < deviceModel.count; ++i) {
            const candidate = deviceModel.get(i);
            if (candidate.stale)
                continue;
            best = root.betterCompactCandidate(best, candidate);
        }

        if (best !== null)
            return best.deviceId;

        for (let i = 0; i < deviceModel.count; ++i)
            best = root.betterCompactCandidate(best, deviceModel.get(i));

        return best?.deviceId ?? "";
    }

    function desiredCompactDevice() {
        const candidateId = root.bestCompactCandidate();
        if (candidateId === "")
            return "";

        const currentIndex = root.indexOfDevice(root.compactDeviceId);
        if (currentIndex < 0)
            return candidateId;
        if (candidateId === root.compactDeviceId)
            return candidateId;

        const candidateIndex = root.indexOfDevice(candidateId);
        if (candidateIndex < 0)
            return root.compactDeviceId;

        const current = deviceModel.get(currentIndex);
        const candidate = deviceModel.get(candidateIndex);

        if (current.stale && !candidate.stale)
            return candidateId;
        if (!current.stale && candidate.stale)
            return root.compactDeviceId;

        const currentPercent = Math.round(current.percentage * 100);
        const candidatePercent = Math.round(candidate.percentage * 100);
        const advantage = currentPercent - candidatePercent;

        if (advantage >= root.compactSwitchThreshold)
            return candidateId;

        if (Math.abs(advantage) <= root.compactTieThreshold
                && root.recencyOf(candidateId) > root.recencyOf(root.compactDeviceId)) {
            return candidateId;
        }

        return root.compactDeviceId;
    }

    function requestCompactDevice(id) {
        if (id === root.compactDeviceId) {
            root.copyCompactDevice(id);
            return;
        }

        if (root.compactDeviceId === "" || !root.compactMode) {
            compactSwitchAnimation.stop();
            root.compactDeviceId = id;
            root.copyCompactDevice(id);
            compactContent.opacity = 1;
            return;
        }

        root.pendingCompactDeviceId = id;
        compactSwitchAnimation.restart();
    }

    function updateCompactSelection() {
        root.requestCompactDevice(root.desiredCompactDevice());
    }

    function compactStatusText() {
        if (root.compactName === "")
            return "";
        if (root.compactStale)
            return root.compactName + " · " + Translation.tr("stale");
        if (root.compactChargingKnown && root.compactCharging)
            return root.compactName + " " + Translation.tr("charging");
        if (root.compactSource === "bluetooth")
            return root.compactName + " " + Translation.tr("connected");
        return root.compactName;
    }

    function syncDevices() {
        const incoming = batteryDevices.devices;
        const incomingIds = [];
        const previousCount = deviceModel.count;

        for (let i = 0; i < incoming.length; ++i) {
            const device = incoming[i];
            incomingIds.push(device.id);

            let currentIndex = root.indexOfDevice(device.id);
            if (currentIndex < 0) {
                deviceModel.insert(i, {
                    deviceId: device.id,
                    source: device.source,
                    name: device.name,
                    icon: device.icon,
                    percentage: device.percentage,
                    charging: device.charging,
                    chargingKnown: device.chargingKnown,
                    observedAt: device.observedAt ?? 0,
                    stale: device.stale ?? false
                });
                if (root.initialDeviceSyncDone)
                    root.touchDevice(device.id);
                continue;
            }

            if (currentIndex !== i) {
                deviceModel.move(currentIndex, i, 1);
                currentIndex = i;
            }

            deviceModel.setProperty(currentIndex, "source", device.source);
            deviceModel.setProperty(currentIndex, "name", device.name);
            deviceModel.setProperty(currentIndex, "icon", device.icon);
            deviceModel.setProperty(currentIndex, "percentage", device.percentage);
            deviceModel.setProperty(currentIndex, "charging", device.charging);
            deviceModel.setProperty(currentIndex, "chargingKnown", device.chargingKnown);
            deviceModel.setProperty(currentIndex, "observedAt", device.observedAt ?? 0);
            deviceModel.setProperty(currentIndex, "stale", device.stale ?? false);
        }

        for (let i = deviceModel.count - 1; i >= 0; --i) {
            if (incomingIds.indexOf(deviceModel.get(i).deviceId) < 0)
                deviceModel.remove(i);
        }

        if (incoming.length < previousCount) {
            root.layoutRowCount = Math.max(root.layoutRowCount, previousCount, 1);
            shrinkTimer.restart();
        } else if (incoming.length >= root.layoutRowCount) {
            shrinkTimer.stop();
            root.layoutRowCount = Math.max(1, incoming.length);
        } else if (!shrinkTimer.running) {
            root.layoutRowCount = Math.max(1, incoming.length);
        }

        root.updateCompactSelection();
        root.initialDeviceSyncDone = true;
    }

    Timer {
        id: shrinkTimer
        interval: Appearance.animation.elementMoveExit.duration
        repeat: false
        onTriggered: root.layoutRowCount = Math.max(1, deviceModel.count)
    }

    Component.onCompleted: syncDevices()

    onCompactModeChanged: {
        compactSwitchAnimation.stop();
        compactContent.opacity = 1;
        root.updateCompactSelection();
    }

    Connections {
        target: batteryDevices
        function onDevicesChanged() { root.syncDevices(); }
    }

    ListModel { id: deviceModel }

    BackgroundWidgetCard {
        id: card
        host: root
        scaleFactor: root.widgetScale
        baseWidth: root.compactMode ? 220 : 360
        baseHeight: root.compactMode ? 132 : root.listAuthoredHeight

        onRequestScale: v => root.dragScale = v
        onCommitScale: v => {
            Config.options.background.widgets.battery.scale = v;
            root.dragScale = -1;
        }

        ColumnLayout {
            anchors.fill: parent
            spacing: card.scaled(8)
            visible: !root.compactMode

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: card.scaled(36)

                Rectangle {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: card.scaled(36)
                    height: card.scaled(36)
                    radius: card.scaled(Appearance.rounding.full)
                    color: root.chargingCount > 0 ? Appearance.colors.colTertiaryContainer : Appearance.colors.colPrimaryContainer

                    Behavior on color { animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this) }

                    TransformSafeSymbol {
                        anchors.fill: parent
                        text: "battery_full"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        baseIconSize: Appearance.font.pixelSize.normal
                        scaleFactor: root.widgetScale
                        color: root.chargingCount > 0 ? Appearance.colors.colTertiary : Appearance.colors.colPrimary
                        Behavior on color { animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this) }
                    }
                }

                TransformSafeText {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: `${deviceModel.count}`
                    basePixelSize: Appearance.font.pixelSize.smaller
                    scaleFactor: root.widgetScale
                    color: root.adaptiveSubtextColor
                    opacity: (root.containsMouse || layoutToggleArea.containsMouse) ? 0 : 1
                    Behavior on opacity { NumberAnimation { duration: 150 } }
                }
            }

            ListView {
                id: deviceList
                Layout.fillWidth: true
                Layout.preferredHeight: card.scaled(root.layoutRowCount * root.rowHeight
                    + Math.max(0, root.layoutRowCount - 1) * root.rowSpacing)
                model: deviceModel
                spacing: card.scaled(root.rowSpacing)
                interactive: false
                clip: true

                delegate: Item {
                    id: deviceRow
                    required property string deviceId
                    required property string source
                    required property string name
                    required property string icon
                    required property real percentage
                    required property bool charging
                    required property bool chargingKnown
                    required property double observedAt
                    required property bool stale

                    width: ListView.view.width
                    height: card.scaled(root.rowHeight)

                    property real animatedPercentage: percentage
                    readonly property bool chargingActive: !stale && chargingKnown && charging
                    readonly property bool low: percentage <= (Config.options.battery.low / 100)
                    readonly property color percentageColor: chargingActive
                        ? Appearance.colors.colTertiary
                        : low ? Appearance.colors.colError : Appearance.colors.colOnLayer0

                    Behavior on animatedPercentage { animation: Appearance.animation.elementMoveSmall.numberAnimation.createObject(this) }

                    RowLayout {
                        anchors.fill: parent
                        spacing: card.scaled(8)

                        Item {
                            Layout.preferredWidth: card.scaled(36)
                            Layout.preferredHeight: card.scaled(root.rowHeight)
                            TransformSafeSymbol {
                                anchors.fill: parent
                                text: deviceRow.icon
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                baseIconSize: Appearance.font.pixelSize.larger
                                scaleFactor: root.widgetScale
                                color: root.adaptiveSubtextColor
                            }
                        }

                        TransformSafeText {
                            Layout.fillWidth: true
                            text: deviceRow.stale
                                ? deviceRow.name + " · " + Translation.tr("stale")
                                : deviceRow.name
                            basePixelSize: Appearance.font.pixelSize.small
                            scaleFactor: root.widgetScale
                            color: deviceRow.stale ? root.adaptiveSubtextColor : Appearance.colors.colOnLayer0
                            elide: Text.ElideRight
                        }

                        Item {
                            id: chargingSlot
                            readonly property real expandedWidth: chargingPill.implicitWidth
                            property real animatedWidth: deviceRow.chargingActive ? expandedWidth : 0
                            Layout.preferredWidth: animatedWidth
                            Layout.preferredHeight: card.scaled(26)
                            clip: true
                            opacity: deviceRow.chargingActive ? 1 : 0
                            Behavior on animatedWidth { animation: Appearance.animation.elementMoveSmall.numberAnimation.createObject(this) }
                            Behavior on opacity { animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this) }

                            Rectangle {
                                id: chargingPill
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                implicitWidth: chargingPillContent.implicitWidth + card.scaled(16)
                                implicitHeight: card.scaled(26)
                                radius: card.scaled(Appearance.rounding.full)
                                color: Appearance.colors.colTertiaryContainer

                                RowLayout {
                                    id: chargingPillContent
                                    anchors.centerIn: parent
                                    spacing: card.scaled(4)
                                    TransformSafeSymbol {
                                        text: "bolt"
                                        baseIconSize: Appearance.font.pixelSize.smallie
                                        scaleFactor: root.widgetScale
                                        color: Appearance.colors.colTertiary
                                    }
                                    TransformSafeText {
                                        text: Translation.tr("Charging")
                                        basePixelSize: Appearance.font.pixelSize.smaller
                                        scaleFactor: root.widgetScale
                                        requestedWeight: Font.DemiBold
                                        color: Appearance.colors.colOnTertiaryContainer
                                    }
                                }
                            }
                        }

                        TransformSafeText {
                            Layout.preferredWidth: card.scaled(42)
                            horizontalAlignment: Text.AlignRight
                            text: `${Math.round(deviceRow.animatedPercentage * 100)}%`
                            basePixelSize: Appearance.font.pixelSize.small
                            scaleFactor: root.widgetScale
                            requestedWeight: deviceRow.chargingActive ? Font.DemiBold : Font.Normal
                            color: deviceRow.percentageColor
                            Behavior on color { animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this) }
                        }
                    }
                }

                add: Transition {
                    ParallelAnimation {
                        NumberAnimation {
                            property: "opacity"
                            from: 0
                            to: 1
                            duration: Appearance.animation.elementMoveEnter.duration
                            easing.type: Appearance.animation.elementMoveEnter.type
                            easing.bezierCurve: Appearance.animation.elementMoveEnter.bezierCurve
                        }
                        NumberAnimation {
                            property: "x"
                            from: card.scaled(8)
                            to: 0
                            duration: Appearance.animation.elementMoveEnter.duration
                            easing.type: Appearance.animation.elementMoveEnter.type
                            easing.bezierCurve: Appearance.animation.elementMoveEnter.bezierCurve
                        }
                    }
                }

                remove: Transition {
                    ParallelAnimation {
                        NumberAnimation {
                            property: "opacity"
                            to: 0
                            duration: Appearance.animation.elementMoveExit.duration
                            easing.type: Appearance.animation.elementMoveExit.type
                            easing.bezierCurve: Appearance.animation.elementMoveExit.bezierCurve
                        }
                        NumberAnimation {
                            property: "x"
                            to: card.scaled(8)
                            duration: Appearance.animation.elementMoveExit.duration
                            easing.type: Appearance.animation.elementMoveExit.type
                            easing.bezierCurve: Appearance.animation.elementMoveExit.bezierCurve
                        }
                    }
                }

                displaced: Transition {
                    NumberAnimation {
                        properties: "x,y"
                        duration: Appearance.animation.elementMoveSmall.duration
                        easing.type: Appearance.animation.elementMoveSmall.type
                        easing.bezierCurve: Appearance.animation.elementMoveSmall.bezierCurve
                    }
                }
            }

            TransformSafeText {
                Layout.fillWidth: true
                Layout.preferredHeight: card.scaled(12)
                visible: deviceModel.count > 0 || shrinkTimer.running
                opacity: root.chargingCount > 0 ? 1 : 0
                text: root.chargingCount === 1 ? Translation.tr("1 charging") : Translation.tr("%1 charging").arg(root.chargingCount)
                basePixelSize: Appearance.font.pixelSize.smaller
                scaleFactor: root.widgetScale
                color: root.adaptiveSubtextColor
                Behavior on opacity { animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this) }
            }
        }

        RowLayout {
            id: compactContent
            anchors.fill: parent
            spacing: card.scaled(12)
            visible: root.compactMode && deviceModel.count > 0

            property real animatedPercentage: root.compactPercentage
            readonly property bool chargingActive: !root.compactStale && root.compactChargingKnown && root.compactCharging
            readonly property bool low: root.compactPercentage <= (Config.options.battery.low / 100)
            readonly property color levelColor: chargingActive
                ? Appearance.colors.colTertiary
                : low ? Appearance.colors.colError : Appearance.colors.colPrimary

            Behavior on animatedPercentage { animation: Appearance.animation.elementMoveSmall.numberAnimation.createObject(this) }

            BatteryProgressRing {
                Layout.alignment: Qt.AlignVCenter
                ringSize: card.scaled(56)
                lineWidth: card.scaled(5)
                percentage: compactContent.animatedPercentage
                ringColor: compactContent.levelColor
                centerIcon: root.compactIcon
                scaleFactor: root.widgetScale
            }

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: card.scaled(56)
                Layout.alignment: Qt.AlignVCenter

                TransformSafeText {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    height: card.scaled(30)
                    verticalAlignment: Text.AlignVCenter
                    text: `${Math.round(compactContent.animatedPercentage * 100)}%`
                    basePixelSize: Appearance.font.pixelSize.hugeass
                    scaleFactor: root.widgetScale
                    requestedWeight: Font.DemiBold
                    color: Appearance.colors.colOnLayer0
                }

                TransformSafeText {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: card.scaled(20)
                    verticalAlignment: Text.AlignVCenter
                    text: root.compactStatusText()
                    basePixelSize: Appearance.font.pixelSize.smaller
                    scaleFactor: root.widgetScale
                    color: root.adaptiveSubtextColor
                    fontSizeMode: Text.HorizontalFit
                    minimumPixelSize: Appearance.font.pixelSize.smallest * root.widgetScale
                    elide: Text.ElideRight
                }
            }
        }

        SequentialAnimation {
            id: compactSwitchAnimation
            running: false
            NumberAnimation {
                target: compactContent
                property: "opacity"
                to: 0
                duration: Math.max(1, Math.round(Appearance.animation.elementMoveFast.duration / 2))
                easing.type: Easing.InQuad
            }
            ScriptAction {
                script: {
                    root.compactDeviceId = root.pendingCompactDeviceId;
                    root.copyCompactDevice(root.compactDeviceId);
                }
            }
            NumberAnimation {
                target: compactContent
                property: "opacity"
                to: 1
                duration: Math.max(1, Math.round(Appearance.animation.elementMoveFast.duration / 2))
                easing.type: Easing.OutQuad
            }
        }

        TransformSafeText {
            anchors.centerIn: parent
            visible: deviceModel.count === 0 && !shrinkTimer.running
            text: Translation.tr("No battery devices detected")
            basePixelSize: Appearance.font.pixelSize.smaller
            scaleFactor: root.widgetScale
            color: root.adaptiveSubtextColor
        }
    }

    Rectangle {
        id: layoutToggle
        width: card.scaled(16)
        height: width
        radius: card.scaled(4)
        z: 100
        x: card.animatedWidth - width - card.scaled(6)
        y: card.scaled(6)
        color: Appearance.colors.colOnPrimaryContainer
        opacity: (root.containsMouse || layoutToggleArea.containsMouse) ? 0.5 : 0
        visible: opacity > 0 && !Config.options.background.widgetsLocked

        Behavior on opacity { NumberAnimation { duration: 150 } }

        TransformSafeSymbol {
            anchors.centerIn: parent
            text: root.compactMode ? "dashboard" : "view_compact"
            baseIconSize: 11
            scaleFactor: root.widgetScale
            color: Appearance.colors.colPrimaryContainer
        }

        MouseArea {
            id: layoutToggleArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.cycleLayout()
        }
    }
}
