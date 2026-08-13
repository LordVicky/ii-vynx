import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell.Io
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.widgets.widgetCanvas
import qs.modules.ii.background.widgets

AbstractBackgroundWidget {
    id: root
    configEntryName: "userCard"
    hoverEnabled: true

    // Live drag override. -1 means "not dragging", which lets widgetScale keep
    // its binding to the persisted config value; a plain assignment during drag
    // would break that binding permanently.
    property real dragScale: -1
    readonly property real widgetScale: dragScale >= 0 ? dragScale : (Config.options.background.widgets.userCard.scale ?? 1)

    implicitWidth: scaleWrapper.implicitWidth * root.widgetScale
    implicitHeight: scaleWrapper.implicitHeight * root.widgetScale

    property int cardWidth: 276
    property int blurMargin: 18
    property int avatarSize: 64
    property string hostname: SystemInfo.hostname
    property string username: SystemInfo.username
    property string userDisplay: username.length > 10 ? username : (username + "@" + hostname)
    property var currentQuip: weatherQuip()


    function weatherQuip() {
        // Weather.qml exposes "wDesc" (not "description")
        const desc = (Weather.data?.wDesc ?? "").toLowerCase();
        const temp = Weather.data?.temp ?? "--";
        if (desc.includes("rain"))
            return { text: `• raining, grab a coffee`, icon: "coffee" };
        if (desc.includes("clear"))
            return { text: `• good day to touch grass`, icon: "eco" };
        if (desc.includes("cloud"))
            return { text: `• a bit cloudy today`, icon: "cloud" };
        if (desc.includes("snow"))
            return { text: `• snowing`, icon: "ac_unit" };
        return { text: `• ${Weather.data?.wDesc ?? ""}`, icon: "thermostat" };
    }

    Item {
        id: scaleWrapper
        implicitWidth: 276
        implicitHeight: 252
        width: implicitWidth
        height: implicitHeight
        transformOrigin: Item.TopLeft
        scale: root.widgetScale
        Behavior on scale { animation: Appearance.animation.elementResize.numberAnimation.createObject(this) }

    StyledDropShadow {
        target: outerRect
    }

    Item {
        id: outerRect
        implicitWidth: root.cardWidth
        implicitHeight: 252

        Item {
            id: bgImage
            anchors.fill: parent
            visible: false

            property string effectiveSource: "file://" + (GlobalStates.screenLocked && Config.options.background.lockWall !== ""
                ? Config.options.background.lockWall
                : Config.options.background.wallpaperPath)

            Image {
                id: bgImageA
                anchors.fill: parent
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: false
                opacity: 1
                Behavior on opacity {
                    NumberAnimation { duration: 400; easing.type: Easing.InOutCubic }
                }
            }
            Image {
                id: bgImageB
                anchors.fill: parent
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: false
                opacity: 0
                Behavior on opacity {
                    NumberAnimation { duration: 400; easing.type: Easing.InOutCubic }
                }
            }

            property bool usingA: true

            onEffectiveSourceChanged: {
                if (usingA) {
                    bgImageB.source = effectiveSource
                    bgImageB.opacity = 1
                    bgImageA.opacity = 0
                } else {
                    bgImageA.source = effectiveSource
                    bgImageA.opacity = 1
                    bgImageB.opacity = 0
                }
                usingA = !usingA
            }

            Component.onCompleted: {
                bgImageA.source = effectiveSource
            }
        }

        FastBlur {
            id: blurredBg
            anchors.fill: bgImage
            source: bgImage
            radius: 48
            layer.enabled: true
            layer.effect: OpacityMask {
                maskSource: Rectangle {
                    width: outerRect.width
                    height: outerRect.height
                    radius: Appearance.rounding?.verylarge ?? 30
                }
            }
        }

        Rectangle {
            anchors.fill: blurredBg
            radius: Appearance.rounding?.verylarge ?? 30
            color: Appearance.colors.colScrim
            opacity: 0.1
        }

        Rectangle {
            id: contentBox
            x: root.blurMargin
            y: root.avatarSize / 2 + root.blurMargin + 30
            width: 240
            color: "transparent"
            radius: Appearance.rounding.large
            implicitHeight: contentColumn.implicitHeight + 30

            WidgetBlurBackground {
                anchors.fill: parent
                cornerRadius: contentBox.radius
                blur: root.blur
                wallpaperPath: root.wallpaperPath
                sourceWidth: root.scaledScreenWidth
                sourceHeight: root.scaledScreenHeight
                offsetX: root.x
                offsetY: root.y
                wallpaperRenderX: root.wallpaperRenderX
                wallpaperRenderY: root.wallpaperRenderY
                wallpaperRenderWidth: root.wallpaperRenderWidth
                wallpaperRenderHeight: root.wallpaperRenderHeight
                parallaxBackdrop: root.parallaxBackdrop
                wallpaperSourceItem: root.wallpaperSourceItem
                hostScale: root.widgetScale
            }

            ColumnLayout {
                id: contentColumn
                anchors {
                    top: parent.top
                    left: parent.left
                    right: parent.right
                    margins: 16
                }
                Layout.topMargin: root.avatarSize / 2 + 4
                spacing: 10

                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: root.avatarSize / 2
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    MaterialSymbol {
                        Layout.alignment: Qt.AlignTop
                        Layout.topMargin: 2
                        iconSize: Appearance.font.pixelSize.normal
                        text: root.currentQuip.icon
                        color: Appearance.colors.colOnPrimaryContainer
                        opacity: 0.85
                    }

                    StyledText {
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.colors.colOnPrimaryContainer
                        opacity: 0.85
                        text: root.currentQuip.text
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 4
                    spacing: 8

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 40
                        radius: Appearance.rounding.full
                        color: Appearance.colors.colOnPrimaryContainer

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 4
                            MaterialSymbol {
                                iconSize: Appearance.font.pixelSize.normal
                                text: "lock"
                                color: Appearance.colors.colPrimaryContainer
                            }
                            StyledText {
                                font.pixelSize: Appearance.font.pixelSize.small
                                font.weight: Font.DemiBold
                                color: Appearance.colors.colPrimaryContainer
                                text: GlobalStates.screenLocked ? "Locked" : "Lock"
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: GlobalStates.screenLocked = true
                        }
                    }

                    Rectangle {
                        implicitWidth: 40
                        implicitHeight: 40
                        radius: 20
                        color: "transparent"
                        border.width: 1
                        border.color: Appearance.colors.colOnPrimaryContainer
                        MaterialSymbol {
                            anchors.centerIn: parent
                            iconSize: Appearance.font.pixelSize.normal
                            text: "settings"
                            color: Appearance.colors.colOnPrimaryContainer
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Quickshell.execDetached(["qs", "-p", Quickshell.shellPath("settings.qml")])
                        }
                    }

                    Rectangle {
                        implicitWidth: 40
                        implicitHeight: 40
                        radius: 20
                        color: "transparent"
                        border.width: 1
                        border.color: Appearance.colors.colOnPrimaryContainer
                        MaterialSymbol {
                            anchors.centerIn: parent
                            iconSize: Appearance.font.pixelSize.normal
                            text: "power_settings_new"
                            color: Appearance.colors.colOnPrimaryContainer
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: GlobalStates.sessionOpen = true
                        }
                    }
                }
            }
        }

        Rectangle {
            id: avatarRect
            x: root.blurMargin + 16
            y: contentBox.y - root.avatarSize / 2
            width: root.avatarSize + 10
            height: root.avatarSize + 10
            radius: width / 2
            color: Appearance.colors.colPrimaryContainer
            border.width: 3
            border.color: Appearance.colors.colLayer1
            z: 2

            StyledImage {
                id: avatarImage
                anchors.fill: parent
                anchors.margins: 3
                source: Directories.userAvatarPathAccountsService
                fallbacks: [Directories.userAvatarPathRicersAndWeirdSystems, Directories.userAvatarPathRicersAndWeirdSystems2]
                fillMode: Image.PreserveAspectCrop
                layer.enabled: true
                layer.effect: OpacityMask {
                    maskSource: Rectangle {
                        width: avatarRect.width - 6
                        height: avatarRect.height - 6
                        radius: (avatarRect.width - 6) / 2
                    }
                }
            }

            MaterialSymbol {
                anchors.centerIn: parent
                text: "account_circle"
                iconSize: 32
                color: Appearance.colors.colOnPrimaryContainer
                visible: avatarImage.status === Image.Error
            }
        }

        ColumnLayout {
            x: avatarRect.x + avatarRect.width + 13
            y: avatarRect.y + (avatarRect.height - implicitHeight) / 2 + 20
            spacing: 0
            z: 2


            StyledText {
                text: root.userDisplay
                font.pixelSize: Appearance.font.pixelSize.small
                font.weight: Font.DemiBold
                color: Appearance.colors.colOnLayer1
            }
            StyledText {
                text: "Up • " + DateTime.uptime
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colOnLayer1
                opacity: 0.6
            }
        }
    }
    }

    WidgetResizeHandle {
        hostWidget: root
        currentScale: root.widgetScale
        baseSize: scaleWrapper.implicitWidth
        onRequestScale: (v) => root.dragScale = v
        onRequestCommit: (v) => { Config.options.background.widgets.userCard.scale = v; root.dragScale = -1 }
    }
}
