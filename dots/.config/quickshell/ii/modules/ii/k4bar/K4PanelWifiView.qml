import QtQuick
import QtQuick.Layouts

Item {
    id: root

    ColumnLayout {
        anchors.fill: parent
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 28
            spacing: 10

            Text {
                text: K4Wifi.enabled
                    ? (K4Wifi.scanning ? "Searching networks…" : "Networks")
                    : "Wi-Fi disabled"
                color: K4Theme.muted
                font.family: K4Theme.uiFont
                font.pixelSize: 11
                renderType: Text.NativeRendering
            }

            Item { Layout.fillWidth: true }

            K4PanelButton {
                glyph: "↻"
                glyphSize: 14
                enabledAction: K4Wifi.enabled && !K4Wifi.scanning
                onActivated: K4Wifi.scan()
            }

            K4PanelSwitch {
                checked: K4Wifi.enabled
                onToggled: K4Wifi.toggle()
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: 12
            color: K4Theme.surface

            ListView {
                anchors.fill: parent
                anchors.margins: 10
                clip: true
                spacing: 2
                model: K4Wifi.networks
                boundsBehavior: Flickable.StopAtBounds

                delegate: K4PanelConnectionRow {
                    required property var modelData
                    width: ListView.view.width
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
                    onActivated: K4Wifi.activate(modelData)
                    onForgotten: K4Wifi.forget(modelData)
                }

                Text {
                    anchors.centerIn: parent
                    visible: K4Wifi.networks.length === 0
                    text: K4Wifi.enabled ? "Searching networks…" : "Enable Wi-Fi to see networks"
                    color: K4Theme.muted
                    font.family: K4Theme.uiFont
                    font.pixelSize: 12
                    renderType: Text.NativeRendering
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: K4Wifi.passwordTarget ? 42 : 0
            visible: K4Wifi.passwordTarget !== null
            radius: 12
            color: K4Theme.surfaceHi
            clip: true

            Behavior on Layout.preferredHeight {
                NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 8
                spacing: 9

                Text {
                    text: K4Theme.ico.lock
                    color: K4Theme.muted
                    font.family: K4Theme.iconFont
                    font.pixelSize: 13
                    renderType: Text.NativeRendering
                }

                TextInput {
                    id: passwordInput
                    Layout.fillWidth: true
                    Layout.preferredHeight: 26
                    verticalAlignment: TextInput.AlignVCenter
                    echoMode: TextInput.Password
                    color: K4Theme.ink
                    selectionColor: K4Theme.blue
                    font.family: K4Theme.uiFont
                    font.pixelSize: 12
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
                        font.pixelSize: 12
                        renderType: Text.NativeRendering
                    }
                }

                K4PanelButton {
                    glyph: K4Theme.ico.check
                    glyphColor: K4Wifi.password.length > 0 ? K4Theme.green : K4Theme.dim
                    enabledAction: K4Wifi.password.length > 0
                    onActivated: K4Wifi.submitPassword()
                }

                K4PanelButton {
                    glyph: K4Theme.ico.close
                    onActivated: K4Wifi.cancelPassword()
                }
            }
        }

        K4PanelTile {
            Layout.fillWidth: true
            Layout.preferredHeight: 30
            visible: K4Wifi.active !== null && !K4Wifi.active.isSecure
            onActivated: K4Wifi.openPortal()

            Text {
                anchors.centerIn: parent
                text: "Open network portal"
                color: K4Theme.muted
                font.family: K4Theme.uiFont
                font.pixelSize: 11
                renderType: Text.NativeRendering
            }
        }
    }
}
