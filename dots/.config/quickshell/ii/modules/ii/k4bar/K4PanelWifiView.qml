import QtQuick
import QtQuick.Layouts

Item {
    id: root

    RowLayout {
        anchors.fill: parent
        spacing: 10

        Rectangle {
            Layout.minimumWidth: 0
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: 17
            color: K4Theme.panelSurface
            border.width: 1
            border.color: K4Theme.panelLine

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 11
                spacing: 8

                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 28
                    spacing: 10

                    Text {
                        text: K4Wifi.enabled
                            ? (K4Wifi.scanning ? "Searching networks…" : "Available networks")
                            : "Wi-Fi disabled"
                        color: K4Theme.ink
                        font.family: K4Theme.uiFont
                        font.pixelSize: 10
                        font.weight: Font.DemiBold
                        renderType: Text.NativeRendering
                    }

                    Item { Layout.fillWidth: true }

                    K4PanelButton {
                        glyph: "↻"
                        glyphSize: 13
                        activeColor: K4Theme.panelSurfaceHi
                        enabledAction: K4Wifi.enabled && !K4Wifi.scanning
                        onActivated: K4Wifi.scan()
                    }

                    K4PanelSwitch {
                        checked: K4Wifi.enabled
                        onToggled: K4Wifi.toggle()
                    }
                }

                K4CursorTrackedListView {
                    id: networksList
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    spacing: 3
                    rowHeight: 46
                    model: K4Wifi.networks
                    boundsBehavior: Flickable.StopAtBounds

                    delegate: K4PanelConnectionRow {
                        required property var modelData
                        required property int index
                        width: ListView.view.width
                        height: ListView.view.rowHeight
                        title: modelData.ssid.length > 0 ? modelData.ssid : "(hidden network)"
                        subtitle: modelData.active ? "Connected"
                            : modelData.askingPassword ? "Password required"
                            : modelData.known ? "Saved"
                            : modelData.security.length > 0 ? modelData.security : "Open network"
                        glyph: K4Wifi.strengthGlyph(modelData)
                        active: modelData.active
                        busy: K4Wifi.connecting && K4Wifi.connectTarget === modelData
                        secure: modelData.isSecure && !modelData.known
                        forgettable: modelData.known
                        hovered: index === networksList.hoveredIndex
                        onActivated: K4Wifi.activate(modelData)
                        onForgotten: K4Wifi.forget(modelData)
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: K4Wifi.networks.length === 0
                        text: K4Wifi.enabled ? "Searching networks…" : "Enable Wi-Fi to see networks"
                        color: K4Theme.muted
                        font.family: K4Theme.uiFont
                        font.pixelSize: 11
                        renderType: Text.NativeRendering
                    }
                }
            }
        }

        Rectangle {
            Layout.minimumWidth: 0
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: 17
            color: K4Theme.panelSurface
            border.width: 1
            border.color: K4Theme.panelLine

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 11
                spacing: 8

                Text {
                    text: "Connection"
                    color: K4Theme.ink
                    font.family: K4Theme.uiFont
                    font.pixelSize: 10
                    font.weight: Font.DemiBold
                    renderType: Text.NativeRendering
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 58
                    radius: 12
                    color: K4Theme.panelSurfaceHi
                    visible: K4Wifi.active !== null

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 9

                        Rectangle {
                            Layout.preferredWidth: 30
                            Layout.preferredHeight: 30
                            radius: 10
                            color: K4Theme.panelSurfaceHot

                            Text {
                                anchors.centerIn: parent
                                text: K4Wifi.active ? K4Wifi.strengthGlyph(K4Wifi.active) : K4Theme.ico.wifi
                                color: K4Theme.muted
                                font.family: K4Theme.iconFont
                                font.pixelSize: 13
                                renderType: Text.NativeRendering
                            }
                        }

                        ColumnLayout {
                            Layout.minimumWidth: 0
                            Layout.fillWidth: true
                            spacing: 1

                            Text {
                                Layout.fillWidth: true
                                text: K4Wifi.name.length > 0 ? K4Wifi.name : "Connected network"
                                color: K4Theme.ink
                                font.family: K4Theme.uiFont
                                font.pixelSize: 10
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                                renderType: Text.NativeRendering
                            }

                            Text {
                                Layout.fillWidth: true
                                text: K4Wifi.statusText
                                color: K4Theme.muted
                                font.family: K4Theme.uiFont
                                font.pixelSize: 8
                                elide: Text.ElideRight
                                renderType: Text.NativeRendering
                            }
                        }
                    }
                }

                Text {
                    visible: K4Wifi.active === null
                    text: K4Wifi.enabled ? "Not connected" : "Wi-Fi is off"
                    color: K4Theme.muted
                    font.family: K4Theme.uiFont
                    font.pixelSize: 10
                    renderType: Text.NativeRendering
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: K4Wifi.passwordTarget ? 48 : 0
                    visible: K4Wifi.passwordTarget !== null
                    radius: 12
                    color: K4Theme.panelSurfaceHi
                    clip: true

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 11
                        anchors.rightMargin: 8
                        spacing: 8

                        Text {
                            text: K4Theme.ico.lock
                            color: K4Theme.muted
                            font.family: K4Theme.iconFont
                            font.pixelSize: 13
                            renderType: Text.NativeRendering
                        }

                        TextInput {
                            id: passwordInput
                            Layout.minimumWidth: 0
                            Layout.fillWidth: true
                            Layout.preferredHeight: 28
                            verticalAlignment: TextInput.AlignVCenter
                            echoMode: TextInput.Password
                            color: K4Theme.ink
                            selectionColor: K4Theme.panelBlue
                            font.family: K4Theme.uiFont
                            font.pixelSize: 11
                            clip: true
                            selectByMouse: true
                            text: K4Wifi.password
                            onTextEdited: K4Wifi.password = text

                            Connections {
                                target: K4Wifi
                                function onPasswordTargetChanged() {
                                    if (K4Wifi.passwordTarget)
                                        Qt.callLater(function () { passwordInput.forceActiveFocus() })
                                }
                            }

                            Keys.onPressed: function (event) {
                                if (event.key === Qt.Key_Escape) {
                                    K4Wifi.cancelPassword()
                                    event.accepted = true
                                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                    K4Wifi.submitPassword()
                                    event.accepted = true
                                }
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: passwordInput.text.length === 0
                                text: K4Wifi.passwordTarget
                                    ? "Password for " + K4Wifi.passwordTarget.ssid : "Password"
                                color: K4Theme.dim
                                font.family: K4Theme.uiFont
                                font.pixelSize: 10
                                renderType: Text.NativeRendering
                            }
                        }

                        K4PanelButton {
                            glyph: K4Theme.ico.check
                            glyphColor: K4Wifi.password.length > 0 ? K4Theme.green : K4Theme.dim
                            activeColor: K4Theme.panelSurfaceHot
                            enabledAction: K4Wifi.password.length > 0
                            onActivated: K4Wifi.submitPassword()
                        }

                        K4PanelButton {
                            glyph: K4Theme.ico.close
                            activeColor: K4Theme.panelSurfaceHot
                            onActivated: K4Wifi.cancelPassword()
                        }
                    }
                }

                K4PanelTile {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 38
                    visible: K4Wifi.active !== null && !K4Wifi.active.isSecure
                    baseColor: K4Theme.panelSurfaceHi
                    hoverColor: K4Theme.panelSurfaceHot
                    cornerRadius: 12
                    onActivated: K4Wifi.openPortal()

                    Text {
                        anchors.centerIn: parent
                        text: "Open network portal"
                        color: K4Theme.muted
                        font.family: K4Theme.uiFont
                        font.pixelSize: 10
                        renderType: Text.NativeRendering
                    }
                }

                Item { Layout.fillHeight: true }
            }
        }
    }
}
