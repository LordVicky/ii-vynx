import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.ii.background.widgets
import "OpenRgbLayout.js" as OpenRgbLayout

AbstractBackgroundWidget {
    id: root
    configEntryName: "openRgb"
    hoverEnabled: true

    property real dragScale: -1
    property bool showingEffects: true
    property bool iconExpanded: false
    property bool iconInteractionActive: false
    property string stagedProfile: ""
    property string stagedEffect: ""
    readonly property real widgetScale: dragScale >= 0 ? dragScale : (Config.options.background.widgets.openRgb.scale ?? 1)
    readonly property string layoutMode: OpenRgbLayout.normalizeLayout(root.configEntry.layout ?? "spindle")
    readonly property bool hasProfiles: OpenRgb.profiles.length > 0
    readonly property bool hasEffects: OpenRgb.effects.length > 0
    readonly property var currentItems: root.showingEffects ? OpenRgb.effects : OpenRgb.profiles
    readonly property bool hasCurrentItems: root.currentItems.length > 0
    readonly property string stagedName: root.showingEffects ? root.stagedEffect : root.stagedProfile
    readonly property string activeName: root.showingEffects ? OpenRgb.activeEffect : OpenRgb.activeProfile
    readonly property string currentLabel: root.hasCurrentItems ? root.stagedName : (root.showingEffects ? Translation.tr("No effects found") : Translation.tr("No profiles found"))
    readonly property var spindleMetrics: ({
        minimumWidth: 330,
        maximumWidth: 410,
        padding: DesktopWidgetMetrics.padding.compact,
        prominentFootprint: 56,
        applyFootprint: DesktopWidgetMetrics.control.prominent,
        outerSpacing: DesktopWidgetMetrics.spacing.standard,
        minimumSelectorWidth: 186,
        labelOverhead: 212
    })
    readonly property real spindleBaseWidth: OpenRgbLayout.spindleBaseWidth(
        stagedLabelMetrics.advanceWidth,
        root.spindleMetrics
    )
    property real iconRevealProgress: 0
    readonly property string collectionStatus: root.showingEffects
        ? (OpenRgb.effectAvailable ? Translation.tr("Effects Plugin connected") : Translation.tr("Effects Plugin unavailable"))
        : (root.hasProfiles ? Translation.tr("%1 profiles").arg(OpenRgb.profiles.length) : Translation.tr("Add .orp profiles in OpenRGB"))

    function itemIndex(items, name) {
        for (let index = 0; index < items.length; index++) {
            if (items[index].name === name)
                return index;
        }
        return -1;
    }

    function reconcileProfiles() {
        if (root.itemIndex(OpenRgb.profiles, root.stagedProfile) >= 0)
            return;
        root.stagedProfile = root.itemIndex(OpenRgb.profiles, OpenRgb.activeProfile) >= 0
            ? OpenRgb.activeProfile
            : (OpenRgb.profiles[0]?.name ?? "");
    }

    function reconcileEffects() {
        if (root.itemIndex(OpenRgb.effects, root.stagedEffect) >= 0)
            return;
        root.stagedEffect = root.itemIndex(OpenRgb.effects, OpenRgb.activeEffect) >= 0
            ? OpenRgb.activeEffect
            : (OpenRgb.effects[0]?.name ?? "");
    }

    function cycleStaged(delta) {
        if (!root.hasCurrentItems)
            return;
        let index = root.itemIndex(root.currentItems, root.stagedName);
        index = index < 0 ? 0 : (index + delta + root.currentItems.length) % root.currentItems.length;
        if (root.showingEffects)
            root.stagedEffect = root.currentItems[index].name;
        else
            root.stagedProfile = root.currentItems[index].name;
    }

    function applyStaged() {
        if (!root.hasCurrentItems)
            return;
        if (root.showingEffects)
            OpenRgb.applyEffect(root.stagedEffect);
        else
            OpenRgb.applyProfile(root.stagedProfile);
    }

    function cycleLayout() {
        root.configEntry.layout = OpenRgbLayout.nextLayout(root.layoutMode);
    }

    function cancelIconCollapse() {
        iconCollapseTimer.stop();
    }

    function scheduleIconCollapse() {
        if (root.layoutMode !== "icon" || root.containsMouse || root.iconInteractionActive || root.dragScale >= 0)
            return;
        iconCollapseTimer.restart();
    }

    function beginIconInteraction() {
        if (root.layoutMode !== "icon")
            return;
        root.cancelIconCollapse();
        root.iconInteractionActive = true;
        root.iconExpanded = true;
    }

    function endIconInteraction() {
        root.iconInteractionActive = false;
        if (!root.containsMouse)
            root.scheduleIconCollapse();
    }

    onContainsMouseChanged: {
        if (root.layoutMode !== "icon")
            return;
        if (root.containsMouse) {
            root.cancelIconCollapse();
            root.iconExpanded = true;
        } else {
            root.scheduleIconCollapse();
        }
    }
    onLayoutModeChanged: {
        root.cancelIconCollapse();
        root.iconInteractionActive = false;
        root.iconExpanded = false;
    }

    Timer {
        id: iconCollapseTimer
        interval: 180
        repeat: false
        onTriggered: {
            if (root.layoutMode === "icon" && !root.containsMouse && !root.iconInteractionActive && root.dragScale < 0)
                root.iconExpanded = false;
        }
    }

    Component.onCompleted: {
        if (Math.abs((Config.options.background.widgets.openRgb.blur ?? 0.6) - 0.6) < 0.001)
            Config.options.background.widgets.openRgb.blur = 0.8;
        root.reconcileProfiles();
        root.reconcileEffects();
    }

    Connections {
        target: OpenRgb
        function onProfilesChanged() { root.reconcileProfiles(); }
        function onEffectsChanged() { root.reconcileEffects(); }
    }

    TextMetrics {
        id: stagedLabelMetrics
        text: root.currentLabel
        font.pixelSize: DesktopWidgetMetrics.typography.primaryLabel
        font.weight: Font.DemiBold
    }

    implicitWidth: card.implicitWidth
    implicitHeight: card.implicitHeight

    BackgroundWidgetCard {
        id: card
        host: root
        scaleFactor: root.widgetScale
        baseWidth: OpenRgbLayout.widgetBaseWidth(root.layoutMode, root.iconExpanded, root.spindleBaseWidth)
        baseHeight: OpenRgbLayout.widgetBaseHeight(root.layoutMode)
        cornerRadius: root.layoutMode === "card" ? (Appearance.rounding?.verylarge ?? 30) : 72 / 2
        contentPadding: root.layoutMode === "card" ? DesktopWidgetMetrics.padding.standard : DesktopWidgetMetrics.padding.compact
        showResizeHandle: root.layoutMode !== "icon" || root.iconExpanded

        onRequestScale: v => {
            root.cancelIconCollapse();
            root.dragScale = v;
        }
        onCommitScale: v => {
            Config.options.background.widgets.openRgb.scale = v;
            root.dragScale = -1;
            if (!root.containsMouse)
                root.scheduleIconCollapse();
        }

        Loader {
            anchors.fill: parent
            active: root.layoutMode === "card"
            sourceComponent: cardLayout
        }

        Loader {
            anchors.fill: parent
            active: root.layoutMode === "icon"
            sourceComponent: iconLayout
        }

        Loader {
            anchors.fill: parent
            active: root.layoutMode === "spindle"
            sourceComponent: spindleLayout
        }
    }

    Rectangle {
        id: layoutToggle
        width: card.scaled(16)
        height: width
        radius: card.scaled(4)
        z: 100
        x: (root.layoutMode === "icon" ? card.animatedWidth : root.width)
            - width - card.scaled(8)
        y: card.scaled(8)
        color: Appearance.colors.colOnPrimaryContainer
        opacity: {
            const presentationOpacity = root.layoutMode !== "icon" ? 1 : root.iconRevealProgress;
            return presentationOpacity
                * ((root.containsMouse || layoutToggleArea.containsMouse) ? 0.5 : 0);
        }
        visible: opacity > 0 && !Config.options.background.widgetsLocked

        Behavior on opacity {
            NumberAnimation { duration: 150 }
        }

        TransformSafeSymbol {
            anchors.centerIn: parent
            text: root.layoutMode === "card" ? "crop_16_9" : "dashboard"
            baseIconSize: 11
            scaleFactor: root.widgetScale
            color: Appearance.colors.colPrimaryContainer
        }

        MouseArea {
            id: layoutToggleArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onPressed: root.beginIconInteraction()
            onReleased: root.endIconInteraction()
            onCanceled: root.endIconInteraction()
            onClicked: root.cycleLayout()
        }
    }

    Component {
        id: spindleLayout

        RowLayout {
            spacing: card.scaled(DesktopWidgetMetrics.spacing.standard)

            Item {
                Layout.preferredWidth: card.scaled(56)
                Layout.fillHeight: true

                PowerControl {
                    anchors.fill: parent
                    glyph: root.layoutMode === "icon" ? "lightbulb" : "power_settings_new"
                }
            }

            SelectionBlock {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumWidth: card.scaled(root.spindleMetrics.minimumSelectorWidth)
            }

            ApplyControl {
                Layout.preferredWidth: card.scaled(root.spindleMetrics.applyFootprint)
                Layout.fillHeight: true
            }
        }
    }

    Component {
        id: iconLayout

        Item {
            id: iconPresentation
            readonly property real collapsedContentWidth: card.scaled(
                72 - DesktopWidgetMetrics.padding.compact * 2
            )
            readonly property real expandedContentWidth: card.scaled(
                root.spindleBaseWidth - DesktopWidgetMetrics.padding.compact * 2
            )
            readonly property real currentContentWidth: card.animatedWidth
                - card.scaled(DesktopWidgetMetrics.padding.compact * 2)
            readonly property real trailingLeftMargin: card.scaled(
                DesktopWidgetMetrics.spacing.standard
            )
            readonly property real trailingRequiredWidth: card.scaled(
                root.spindleMetrics.minimumSelectorWidth
                + DesktopWidgetMetrics.spacing.standard
                + root.spindleMetrics.applyFootprint
            )
            readonly property real revealProgress: OpenRgbLayout.iconRevealProgress(
                iconPresentation.currentContentWidth,
                iconPresentation.collapsedContentWidth,
                iconPresentation.expandedContentWidth,
                iconPresentation.trailingRequiredWidth,
                iconPresentation.trailingLeftMargin
            )

            Binding {
                target: root
                property: "iconRevealProgress"
                value: iconPresentation.revealProgress
                when: root.layoutMode === "icon"
                restoreMode: Binding.RestoreBindingOrValue
            }

            Item {
                id: iconPowerAnchor
                width: card.scaled(72 - DesktopWidgetMetrics.padding.compact * 2)
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom

                PowerControl {
                    anchors.fill: parent
                    glyph: "lightbulb"
                }
            }

            Item {
                id: trailingControls
                anchors.left: iconPowerAnchor.right
                anchors.leftMargin: iconPresentation.trailingLeftMargin
                anchors.right: parent.right
                anchors.top: parent.top
                height: Math.max(iconPresentation.height, trailingContent.implicitHeight)
                clip: true
                opacity: iconPresentation.revealProgress
                enabled: OpenRgbLayout.iconInteractionEnabled(iconPresentation.revealProgress)

                Item {
                    id: trailingContent
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    height: iconPresentation.height
                    implicitHeight: trailingRow.implicitHeight

                    RowLayout {
                        id: trailingRow
                        anchors.fill: parent
                        spacing: card.scaled(DesktopWidgetMetrics.spacing.standard)
                        transform: Translate {
                            x: card.scaled(-8 * (1 - iconPresentation.revealProgress))
                        }

                        SelectionBlock {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Layout.minimumWidth: card.scaled(root.spindleMetrics.minimumSelectorWidth)
                        }

                        ApplyControl {
                            Layout.preferredWidth: card.scaled(root.spindleMetrics.applyFootprint)
                            Layout.fillHeight: true
                        }
                    }
                }
            }
        }
    }

    Component {
        id: cardLayout

        ColumnLayout {
            spacing: card.scaled(DesktopWidgetMetrics.spacing.standard)

            RowLayout {
                Layout.fillWidth: true
                spacing: card.scaled(DesktopWidgetMetrics.spacing.standard)

                TransformSafeSymbol {
                    text: "lightbulb"
                    baseIconSize: DesktopWidgetMetrics.glyph.standardAction
                    scaleFactor: root.widgetScale
                    color: OpenRgb.available && OpenRgb.lightsEnabled ? Appearance.colors.colPrimary : root.adaptiveSubtextColor
                }

                TransformSafeText {
                    Layout.fillWidth: true
                    text: "OpenRGB"
                    basePixelSize: DesktopWidgetMetrics.typography.body
                    scaleFactor: root.widgetScale
                    requestedWeight: Font.DemiBold
                    color: Appearance.colors.colOnLayer0
                }

                TransformSafeText {
                    text: OpenRgb.statusText
                    basePixelSize: DesktopWidgetMetrics.typography.caption
                    scaleFactor: root.widgetScale
                    color: OpenRgb.lastError.length > 0 ? Appearance.colors.colError : root.adaptiveSubtextColor
                    elide: Text.ElideRight
                    Layout.maximumWidth: card.scaled(106)
                }

                ControlButton {
                    icon: "refresh"
                    size: DesktopWidgetMetrics.control.compact
                    enabled: !OpenRgb.busy
                    opacity: root.containsMouse || OpenRgb.lastError.length > 0 ? 1 : 0
                    onTriggered: OpenRgb.refresh()

                    Behavior on opacity {
                        NumberAnimation { duration: 150 }
                    }
                }
            }

            ModeSwitch {
                Layout.fillWidth: true
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: card.scaled(DesktopWidgetMetrics.spacing.roomy)

                Rectangle {
                    id: cardPowerButton
                    implicitWidth: OpenRgbLayout.pixelScaled(DesktopWidgetMetrics.control.prominent, root.widgetScale)
                    implicitHeight: implicitWidth
                    radius: width / 2
                    color: {
                        if (!OpenRgb.available)
                            return Appearance.colors.colSurfaceContainerLow;
                        if (OpenRgb.lightsEnabled)
                            return cardPowerArea.containsMouse ? Appearance.colors.colPrimaryHover : Appearance.colors.colPrimary;
                        return cardPowerArea.containsMouse ? Appearance.colors.colLayer1Hover : Appearance.colors.colSurfaceContainerLow;
                    }
                    opacity: OpenRgb.applying ? 0.65 : 1

                    TransformSafeSymbol {
                        anchors.centerIn: parent
                        text: "power_settings_new"
                        baseIconSize: DesktopWidgetMetrics.glyph.prominentAction
                        scaleFactor: root.widgetScale
                        color: OpenRgb.available && OpenRgb.lightsEnabled ? Appearance.colors.colOnPrimary : root.adaptiveSubtextColor
                    }

                    MouseArea {
                        id: cardPowerArea
                        anchors.fill: parent
                        enabled: OpenRgb.available && !OpenRgb.busy
                        hoverEnabled: true
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: OpenRgb.toggleLights()
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: card.scaled(DesktopWidgetMetrics.spacing.compact)

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: card.scaled(DesktopWidgetMetrics.spacing.compact)

                        ControlButton {
                            icon: "chevron_left"
                            size: DesktopWidgetMetrics.control.compact
                            enabled: OpenRgb.available && root.hasCurrentItems && !OpenRgb.busy
                            onTriggered: root.cycleStaged(-1)
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: card.scaled(DesktopWidgetMetrics.control.standard)
                            radius: card.scaled(Appearance.rounding?.small ?? 12)
                            color: Appearance.colors.colSurfaceContainerLow

                            TransformSafeText {
                                anchors.fill: parent
                                anchors.leftMargin: card.scaled(8)
                                anchors.rightMargin: card.scaled(8)
                                verticalAlignment: Text.AlignVCenter
                                horizontalAlignment: Text.AlignHCenter
                                text: root.currentLabel
                                basePixelSize: DesktopWidgetMetrics.typography.primaryLabel
                                scaleFactor: root.widgetScale
                                requestedWeight: root.hasCurrentItems ? Font.DemiBold : Font.Normal
                                color: root.hasCurrentItems ? Appearance.colors.colOnLayer0 : root.adaptiveSubtextColor
                                elide: Text.ElideMiddle
                            }
                        }

                        ControlButton {
                            icon: "chevron_right"
                            size: DesktopWidgetMetrics.control.compact
                            enabled: OpenRgb.available && root.hasCurrentItems && !OpenRgb.busy
                            onTriggered: root.cycleStaged(1)
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: card.scaled(DesktopWidgetMetrics.control.standard)
                        radius: card.scaled(Appearance.rounding?.small ?? 12)
                        color: cardApplyArea.containsMouse && cardApplyArea.enabled
                            ? Appearance.colors.colPrimaryHover
                            : Appearance.colors.colPrimary
                        opacity: cardApplyArea.enabled ? 1 : 0.55

                        TransformSafeText {
                            anchors.centerIn: parent
                            text: root.showingEffects ? Translation.tr("Apply effect") : Translation.tr("Apply profile")
                            basePixelSize: DesktopWidgetMetrics.typography.actionLabel
                            scaleFactor: root.widgetScale
                            requestedWeight: Font.DemiBold
                            color: Appearance.colors.colOnPrimary
                        }

                        MouseArea {
                            id: cardApplyArea
                            anchors.fill: parent
                            enabled: OpenRgb.available && root.hasCurrentItems && !OpenRgb.busy && (!root.showingEffects || OpenRgb.effectAvailable)
                            hoverEnabled: true
                            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onPressed: root.beginIconInteraction()
                            onReleased: root.endIconInteraction()
                            onCanceled: root.endIconInteraction()
                            onClicked: root.applyStaged()
                        }
                    }

                }
            }
        }
    }

    component PowerControl: Item {
        id: powerControl
        required property string glyph

        Rectangle {
            width: OpenRgbLayout.pixelScaled(DesktopWidgetMetrics.control.prominent, root.widgetScale)
            height: width
            anchors.horizontalCenter: parent.horizontalCenter
            y: OpenRgbLayout.centeredContentY(card.implicitHeight, height, card.scaled(card.contentPadding))
            radius: width / 2
            color: {
                if (!OpenRgb.available)
                    return Appearance.colors.colSurfaceContainerLow;
                if (OpenRgb.lightsEnabled)
                    return powerArea.containsMouse ? Appearance.colors.colPrimaryHover : Appearance.colors.colPrimary;
                return powerArea.containsMouse ? Appearance.colors.colLayer1Hover : Appearance.colors.colSurfaceContainerLow;
            }
            opacity: OpenRgb.applying ? 0.65 : 1

            Behavior on color {
                animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
            }

            TransformSafeSymbol {
                anchors.centerIn: parent
                text: powerControl.glyph
                baseIconSize: DesktopWidgetMetrics.glyph.prominentAction
                scaleFactor: root.widgetScale
                color: OpenRgb.available && OpenRgb.lightsEnabled ? Appearance.colors.colOnPrimary : root.adaptiveSubtextColor
            }

            MouseArea {
                id: powerArea
                anchors.fill: parent
                enabled: OpenRgb.available && !OpenRgb.busy
                hoverEnabled: true
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                onPressed: root.beginIconInteraction()
                onReleased: root.endIconInteraction()
                onCanceled: root.endIconInteraction()
                onClicked: OpenRgb.toggleLights()
            }
        }
    }

    component SelectionBlock: ColumnLayout {
        spacing: card.scaled(DesktopWidgetMetrics.spacing.tight)

        ModeSwitch {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: card.scaled(164)
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: card.scaled(DesktopWidgetMetrics.control.standard)
            spacing: card.scaled(root.layoutMode === "spindle"
                ? DesktopWidgetMetrics.spacing.compact
                : DesktopWidgetMetrics.spacing.standard)

            ControlButton {
                icon: "chevron_left"
                size: DesktopWidgetMetrics.control.compact
                enabled: OpenRgb.available && root.hasCurrentItems && !OpenRgb.busy
                onTriggered: root.cycleStaged(-1)
            }

            TransformSafeText {
                Layout.fillWidth: true
                text: root.currentLabel
                basePixelSize: DesktopWidgetMetrics.typography.primaryLabel
                scaleFactor: root.widgetScale
                requestedWeight: root.hasCurrentItems ? Font.DemiBold : Font.Normal
                color: root.hasCurrentItems ? Appearance.colors.colOnLayer0 : root.adaptiveSubtextColor
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideMiddle
            }

            ControlButton {
                icon: "chevron_right"
                size: DesktopWidgetMetrics.control.compact
                enabled: OpenRgb.available && root.hasCurrentItems && !OpenRgb.busy
                onTriggered: root.cycleStaged(1)
            }
        }

    }

    component ModeSwitch: Item {
        implicitHeight: card.scaled(26)

        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: Appearance.colors.colSurfaceContainerLow

            RowLayout {
                anchors.fill: parent
                anchors.margins: card.scaled(2)
                spacing: card.scaled(2)

                ModeTab {
                    Layout.fillWidth: true
                    label: Translation.tr("Profiles")
                    selected: !root.showingEffects
                    onTriggered: root.showingEffects = false
                }

                ModeTab {
                    Layout.fillWidth: true
                    label: Translation.tr("Effects")
                    selected: root.showingEffects
                    onTriggered: root.showingEffects = true
                }
            }
        }
    }

    component ApplyControl: Item {
        Rectangle {
            id: applyButton
            width: OpenRgbLayout.pixelScaled(DesktopWidgetMetrics.control.prominent, root.widgetScale)
            height: width
            anchors.horizontalCenter: parent.horizontalCenter
            y: OpenRgbLayout.centeredContentY(card.implicitHeight, height, card.scaled(card.contentPadding))
            radius: width / 2
            color: applyArea.enabled
                ? (applyArea.containsMouse ? Appearance.colors.colPrimaryHover : Appearance.colors.colPrimary)
                : Appearance.colors.colSurfaceContainerLow
            opacity: applyArea.enabled ? 1 : 0.55

            TransformSafeSymbol {
                anchors.centerIn: parent
                text: "check"
                baseIconSize: DesktopWidgetMetrics.glyph.prominentAction
                scaleFactor: root.widgetScale
                color: applyArea.enabled ? Appearance.colors.colOnPrimary : root.adaptiveSubtextColor
            }

            MouseArea {
                id: applyArea
                anchors.fill: parent
                enabled: OpenRgb.available && root.hasCurrentItems && !OpenRgb.busy && (!root.showingEffects || OpenRgb.effectAvailable)
                hoverEnabled: true
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                onPressed: root.beginIconInteraction()
                onReleased: root.endIconInteraction()
                onCanceled: root.endIconInteraction()
                onClicked: root.applyStaged()
            }
        }
    }

    component ModeTab: Rectangle {
        id: tab
        required property string label
        required property bool selected
        signal triggered

        implicitHeight: card.scaled(22)
        radius: height / 2
        color: tab.selected ? Appearance.colors.colPrimary : "transparent"

        TransformSafeText {
            anchors.centerIn: parent
            text: tab.label
            basePixelSize: DesktopWidgetMetrics.typography.caption
            scaleFactor: root.widgetScale
            requestedWeight: Font.DemiBold
            color: tab.selected ? Appearance.colors.colOnPrimary : root.adaptiveSubtextColor
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onPressed: root.beginIconInteraction()
            onReleased: root.endIconInteraction()
            onCanceled: root.endIconInteraction()
            onClicked: tab.triggered()
        }
    }

    component ControlButton: Rectangle {
        id: button
        property string icon: ""
        property real size: DesktopWidgetMetrics.control.compact
        signal triggered

        implicitWidth: card.scaled(button.size)
        implicitHeight: card.scaled(button.size)
        radius: width / 2
        color: button.enabled
            ? (buttonArea.containsMouse ? Appearance.colors.colSecondaryContainerHover : Appearance.colors.colSecondaryContainer)
            : Appearance.colors.colSurfaceContainerLow
        opacity: button.enabled ? 1 : 0.55

        TransformSafeSymbol {
            anchors.centerIn: parent
            text: button.icon
            baseIconSize: DesktopWidgetMetrics.glyph.compactAction
            scaleFactor: root.widgetScale
            color: button.enabled ? Appearance.colors.colOnSecondaryContainer : root.adaptiveSubtextColor
        }

        MouseArea {
            id: buttonArea
            anchors.fill: parent
            enabled: button.enabled
            hoverEnabled: true
            cursorShape: button.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onPressed: root.beginIconInteraction()
            onReleased: root.endIconInteraction()
            onCanceled: root.endIconInteraction()
            onClicked: button.triggered()
        }
    }
}
