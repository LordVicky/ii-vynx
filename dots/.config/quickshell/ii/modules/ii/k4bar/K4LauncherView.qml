import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets

// Spotlight-style launcher surface adapted from k4ditano/k4 LauncherView at
// the pinned source commit, including its pacman/AUR package-search mode.
Item {
    id: root

    required property var plugin
    property int focusAttempts: 0

    readonly property string searchGlyph: String.fromCodePoint(0xF0349)
    readonly property string enterGlyph: String.fromCodePoint(0xF0311)
    readonly property string packageGlyph: String.fromCodePoint(0xF03D7)
    readonly property string installedGlyph: String.fromCodePoint(0xF012C)
    readonly property string uninstallGlyph: String.fromCodePoint(0xF0A7A)

    opacity: 0
    Component.onCompleted: {
        root.plugin.rebuild()
        focusAttempts = 0
        fadeIn.start()
        focusTimer.start()
        Qt.callLater(() => launcherInput.forceActiveFocus())
    }

    NumberAnimation {
        id: fadeIn
        target: root
        property: "opacity"
        from: 0
        to: 1
        duration: 180
        easing.type: Easing.OutCubic
    }

    Timer {
        id: focusTimer
        interval: 140
        onTriggered: {
            if (!root.plugin.open)
                return
            launcherInput.forceActiveFocus()
            if (!launcherInput.activeFocus && root.focusAttempts < 6) {
                root.focusAttempts += 1
                restart()
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: 18
        anchors.rightMargin: 18
        anchors.topMargin: 14
        anchors.bottomMargin: 16
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 40
            spacing: 12

            Text {
                text: root.plugin.mode === "packages" ? root.packageGlyph : root.searchGlyph
                color: root.plugin.mode === "packages" ? K4Theme.blue : K4Theme.muted
                font.family: K4Theme.iconFont
                font.pixelSize: 20
                renderType: Text.NativeRendering
                Layout.alignment: Qt.AlignVCenter
            }

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 30
                Layout.alignment: Qt.AlignVCenter

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.plugin.query.length === 0
                    text: root.plugin.mode === "packages"
                        ? "Search packages to install" : "Search applications"
                    color: K4Theme.dim
                    font.family: K4Theme.uiFont
                    font.pixelSize: 19
                    renderType: Text.NativeRendering
                }

                TextInput {
                    id: launcherInput
                    anchors.fill: parent
                    verticalAlignment: TextInput.AlignVCenter
                    color: K4Theme.ink
                    font.family: K4Theme.uiFont
                    font.pixelSize: 19
                    focus: true
                    activeFocusOnTab: true
                    clip: true
                    selectByMouse: true
                    cursorVisible: true
                    selectionColor: K4Theme.blue
                    selectedTextColor: K4Theme.ink
                    text: root.plugin.query

                    onTextEdited: {
                        root.plugin.query = text
                        if (root.plugin.mode === "packages")
                            root.plugin.schedulePackageSearch()
                        else
                            root.plugin.rebuild()
                    }

                    Keys.onPressed: function(event) {
                        if (event.key === Qt.Key_Escape) {
                            if (root.plugin.mode === "packages")
                                root.plugin.leavePackageMode()
                            else
                                root.plugin.close()
                            event.accepted = true
                        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            root.plugin.launchSelected()
                            event.accepted = true
                        } else if (event.key === Qt.Key_Delete
                                   && (event.modifiers & Qt.ControlModifier)
                                   && root.plugin.mode === "packages") {
                            root.plugin.uninstallSelected()
                            event.accepted = true
                        } else if (event.key === Qt.Key_Down) {
                            root.plugin.moveSelection(1)
                            event.accepted = true
                        } else if (event.key === Qt.Key_Up) {
                            root.plugin.moveSelection(-1)
                            event.accepted = true
                        }
                    }
                }
            }

            Text {
                text: root.plugin.mode !== "packages" ? "esc"
                    : root.plugin.aurSearching ? "searching AUR…" : "esc returns to apps"
                color: K4Theme.dim
                font.family: K4Theme.uiFont
                font.pixelSize: 11
                renderType: Text.NativeRendering
                Layout.alignment: Qt.AlignVCenter

                SequentialAnimation on opacity {
                    running: root.plugin.aurSearching
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.35; duration: 620; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1; duration: 620; easing.type: Easing.InOutSine }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: K4Theme.surfaceHi
        }

        ListView {
            id: appResults
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: root.plugin.mode === "apps"
            clip: true
            spacing: 2
            boundsBehavior: Flickable.StopAtBounds
            model: root.plugin.matches
            currentIndex: root.plugin.index
            highlightMoveDuration: 140

            onCurrentIndexChanged: {
                if (currentIndex >= 0)
                    positionViewAtIndex(currentIndex, ListView.Contain)
            }

            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
                width: 5
                contentItem: Rectangle {
                    implicitWidth: 4
                    radius: 2
                    color: parent.pressed ? K4Theme.muted : K4Theme.dim
                }
                background: Item {}
            }

            delegate: Rectangle {
                id: appRow
                required property var modelData
                required property int index

                width: ListView.view.width
                height: 42
                radius: 10
                color: index === root.plugin.index ? K4Theme.surfaceHi : "transparent"

                Behavior on color { ColorAnimation { duration: 120 } }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 12
                    spacing: 12

                    Item {
                        Layout.preferredWidth: 26
                        Layout.preferredHeight: 26
                        Layout.alignment: Qt.AlignVCenter

                        IconImage {
                            anchors.fill: parent
                            visible: appRow.modelData.isInstall !== true
                            source: Quickshell.iconPath(appRow.modelData.icon, "image-missing")
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: appRow.modelData.isInstall === true
                            text: root.packageGlyph
                            color: K4Theme.blue
                            font.family: K4Theme.iconFont
                            font.pixelSize: 20
                            renderType: Text.NativeRendering
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 0

                        Text {
                            Layout.fillWidth: true
                            text: appRow.modelData.name ?? ""
                            color: K4Theme.ink
                            font.family: K4Theme.uiFont
                            font.pixelSize: 13
                            font.weight: Font.Medium
                            elide: Text.ElideRight
                            renderType: Text.NativeRendering
                        }

                        Text {
                            Layout.fillWidth: true
                            text: appRow.modelData.genericName
                                || appRow.modelData.comment
                                || appRow.modelData.id
                                || ""
                            color: K4Theme.muted
                            font.family: K4Theme.uiFont
                            font.pixelSize: 10
                            elide: Text.ElideRight
                            renderType: Text.NativeRendering
                        }
                    }

                    Text {
                        visible: appRow.index === root.plugin.index
                        text: root.enterGlyph
                        color: K4Theme.muted
                        font.family: K4Theme.iconFont
                        font.pixelSize: 14
                        renderType: Text.NativeRendering
                        Layout.alignment: Qt.AlignVCenter
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: root.plugin.index = appRow.index
                    onClicked: {
                        root.plugin.index = appRow.index
                        root.plugin.launchSelected()
                    }
                }
            }

            Text {
                anchors.centerIn: parent
                visible: root.plugin.matches.length === 0
                text: "No results"
                color: K4Theme.muted
                font.family: K4Theme.uiFont
                font.pixelSize: 13
                renderType: Text.NativeRendering
            }
        }

        ListView {
            id: packageResults
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: root.plugin.mode === "packages"
            clip: true
            spacing: 2
            boundsBehavior: Flickable.StopAtBounds
            model: root.plugin.packageMatches
            currentIndex: root.plugin.index

            onCurrentIndexChanged: {
                if (currentIndex >= 0)
                    positionViewAtIndex(currentIndex, ListView.Contain)
            }

            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
                width: 5
                contentItem: Rectangle {
                    implicitWidth: 4
                    radius: 2
                    color: parent.pressed ? K4Theme.muted : K4Theme.dim
                }
                background: Item {}
            }

            delegate: Rectangle {
                id: packageRow
                required property var modelData
                required property int index

                width: ListView.view.width
                height: 48
                radius: 10
                color: index === root.plugin.index ? K4Theme.surfaceHi : "transparent"

                Behavior on color { ColorAnimation { duration: 120 } }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 12

                    Text {
                        text: packageRow.modelData.installed ? root.installedGlyph : root.packageGlyph
                        color: packageRow.modelData.installed ? K4Theme.green : K4Theme.muted
                        font.family: K4Theme.iconFont
                        font.pixelSize: 18
                        renderType: Text.NativeRendering
                        Layout.alignment: Qt.AlignVCenter
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 1

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 7

                            Text {
                                text: packageRow.modelData.name
                                color: K4Theme.ink
                                font.family: K4Theme.uiFont
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                                Layout.maximumWidth: 260
                            }

                            Rectangle {
                                Layout.preferredWidth: repoLabel.implicitWidth + 12
                                Layout.preferredHeight: 15
                                Layout.alignment: Qt.AlignVCenter
                                radius: 7
                                color: packageRow.modelData.repo === "aur" ? "#3a2a12" : K4Theme.surfaceHi

                                Text {
                                    id: repoLabel
                                    anchors.centerIn: parent
                                    text: packageRow.modelData.repo
                                    color: packageRow.modelData.repo === "aur" ? "#ff9f0a" : K4Theme.muted
                                    font.family: K4Theme.uiFont
                                    font.pixelSize: 9
                                }
                            }

                            Text {
                                text: packageRow.modelData.version
                                color: K4Theme.dim
                                font.family: K4Theme.uiFont
                                font.pixelSize: 10
                                elide: Text.ElideRight
                                Layout.alignment: Qt.AlignVCenter
                            }

                            Item { Layout.fillWidth: true }
                        }

                        Text {
                            Layout.fillWidth: true
                            text: packageRow.modelData.installed
                                ? "Installed · " + packageRow.modelData.description
                                : packageRow.modelData.description
                            color: packageRow.modelData.installed ? K4Theme.green : K4Theme.muted
                            font.family: K4Theme.uiFont
                            font.pixelSize: 10
                            elide: Text.ElideRight
                        }
                    }

                    Text {
                        visible: packageRow.index === root.plugin.index
                        text: packageRow.modelData.installed ? "update ↵" : "install ↵"
                        color: K4Theme.muted
                        font.family: K4Theme.uiFont
                        font.pixelSize: 10
                        Layout.alignment: Qt.AlignVCenter
                    }

                    Rectangle {
                        id: uninstallAction
                        visible: packageRow.modelData.installed
                            && packageRow.index === root.plugin.index
                        Layout.preferredWidth: uninstallContent.implicitWidth + 18
                        Layout.preferredHeight: 26
                        Layout.alignment: Qt.AlignVCenter
                        radius: 13
                        color: uninstallMouse.containsMouse ? "#3a1518" : "#2a0f12"
                        border.width: 1
                        border.color: K4Theme.red

                        RowLayout {
                            id: uninstallContent
                            anchors.centerIn: parent
                            spacing: 5

                            Text {
                                text: root.uninstallGlyph
                                color: K4Theme.red
                                font.family: K4Theme.iconFont
                                font.pixelSize: 11
                            }

                            Text {
                                text: "uninstall"
                                color: K4Theme.red
                                font.family: K4Theme.uiFont
                                font.pixelSize: 10
                            }
                        }

                        MouseArea {
                            id: uninstallMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.plugin.uninstallPackage(packageRow.modelData)
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    anchors.rightMargin: uninstallAction.visible ? uninstallAction.width + 12 : 0
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: root.plugin.index = packageRow.index
                    onClicked: {
                        root.plugin.index = packageRow.index
                        root.plugin.launchSelected()
                    }
                }
            }

            Text {
                anchors.centerIn: parent
                visible: root.plugin.packageMatches.length === 0
                text: K4Packages.packageQuery().length < 2
                    ? "Type at least two characters"
                    : root.plugin.aurSearching ? "Searching…" : "No matching packages"
                color: K4Theme.muted
                font.family: K4Theme.uiFont
                font.pixelSize: 13
                renderType: Text.NativeRendering
            }
        }
    }
}
