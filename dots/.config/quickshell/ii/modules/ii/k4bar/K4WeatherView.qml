import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Weather surface adapted from pinned k4 WeatherView. The K4 visual language is
// preserved while data comes through the ii-owned Weather + K4Weather bridge.
Item {
    id: root
    required property var plugin

    opacity: 0
    Component.onCompleted: fadeIn.start()

    NumberAnimation {
        id: fadeIn
        target: root
        property: "opacity"
        from: 0
        to: 1
        duration: 180
        easing.type: Easing.OutCubic
    }

    component WeatherGlyph: Text {
        color: K4Theme.ink
        font.family: K4Theme.iconFont
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        renderType: Text.NativeRendering
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
            Layout.preferredHeight: 30
            spacing: 10

            Text {
                text: String.fromCodePoint(0xF0417)
                color: K4Theme.muted
                font.family: K4Theme.iconFont
                font.pixelSize: 16
            }
            Text {
                text: K4Weather.place.length ? K4Weather.place : "No location"
                color: K4Theme.ink
                font.family: K4Theme.uiFont
                font.pixelSize: 15
                font.weight: Font.DemiBold
            }
            Item { Layout.fillWidth: true }
            Text {
                visible: K4Weather.loading
                text: "loading…"
                color: K4Theme.dim
                font.family: K4Theme.uiFont
                font.pixelSize: 10
            }
            Rectangle {
                implicitWidth: 30; implicitHeight: 26; radius: 13
                color: searchMouse.containsMouse || root.plugin.searchOpen ? K4Theme.surfaceHi : "transparent"
                Text { anchors.centerIn: parent; text: String.fromCodePoint(0xF0349); color: K4Theme.muted; font.family: K4Theme.iconFont; font.pixelSize: 15 }
                MouseArea { id: searchMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.plugin.searchOpen ? root.plugin.closeSearch() : root.plugin.openSearch() }
            }
            Rectangle {
                implicitWidth: 30; implicitHeight: 26; radius: 13
                color: refreshMouse.containsMouse ? K4Theme.surfaceHi : "transparent"
                Text { anchors.centerIn: parent; text: String.fromCodePoint(0xF0450); color: K4Theme.muted; font.family: K4Theme.iconFont; font.pixelSize: 15 }
                MouseArea { id: refreshMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: K4Weather.refresh() }
            }
            Rectangle {
                implicitWidth: 30; implicitHeight: 26; radius: 13
                color: closeMouse.containsMouse ? K4Theme.surfaceHi : "transparent"
                Text { anchors.centerIn: parent; text: K4Theme.ico.close; color: K4Theme.muted; font.family: K4Theme.iconFont; font.pixelSize: 15 }
                MouseArea { id: closeMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.plugin.close() }
            }
        }

        Loader {
            Layout.fillWidth: true
            Layout.fillHeight: true
            active: root.plugin.searchOpen
            sourceComponent: Rectangle {
                radius: 16
                color: K4Theme.surface

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 10

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 42
                        radius: 11
                        color: K4Theme.surfaceHi
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 10
                            Text { text: String.fromCodePoint(0xF0349); color: K4Theme.muted; font.family: K4Theme.iconFont; font.pixelSize: 16 }
                            Item {
                                Layout.fillWidth: true; Layout.fillHeight: true
                                Text { anchors.fill: parent; verticalAlignment: Text.AlignVCenter; visible: cityInput.text.length === 0; text: "Type a city…"; color: K4Theme.dim; font.family: K4Theme.uiFont; font.pixelSize: 16 }
                                TextInput {
                                    id: cityInput
                                    anchors.fill: parent
                                    verticalAlignment: TextInput.AlignVCenter
                                    color: K4Theme.ink
                                    font.family: K4Theme.uiFont
                                    font.pixelSize: 16
                                    focus: true
                                    clip: true
                                    selectByMouse: true
                                    cursorVisible: true
                                    selectionColor: K4Theme.blue
                                    text: root.plugin.query
                                    Component.onCompleted: Qt.callLater(() => forceActiveFocus())
                                    onTextEdited: { root.plugin.query = text; searchDelay.restart() }
                                    Keys.onPressed: function(event) {
                                        if (event.key === Qt.Key_Escape) {
                                            root.plugin.closeSearch(); event.accepted = true
                                        } else if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && K4Weather.matches.length > 0) {
                                            root.plugin.choose(K4Weather.matches[0]); event.accepted = true
                                        }
                                    }
                                    Timer { id: searchDelay; interval: 350; onTriggered: K4Weather.search(root.plugin.query) }
                                }
                            }
                            Text { text: K4Weather.searching ? "searching…" : "esc"; color: K4Theme.dim; font.family: K4Theme.uiFont; font.pixelSize: 10 }
                        }
                    }

                    ListView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        model: K4Weather.matches
                        spacing: 2
                        boundsBehavior: Flickable.StopAtBounds
                        delegate: Rectangle {
                            id: cityRow
                            required property var modelData
                            width: ListView.view.width
                            height: 46
                            radius: 10
                            color: cityHover.containsMouse ? K4Theme.surfaceHi : "transparent"
                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12; anchors.rightMargin: 12; spacing: 10
                                Text { text: String.fromCodePoint(0xF0417); color: K4Theme.muted; font.family: K4Theme.iconFont; font.pixelSize: 15 }
                                ColumnLayout {
                                    Layout.fillWidth: true; spacing: 0
                                    Text { Layout.fillWidth: true; text: cityRow.modelData.name; color: K4Theme.ink; font.family: K4Theme.uiFont; font.pixelSize: 13; font.weight: Font.DemiBold; elide: Text.ElideRight }
                                    Text { Layout.fillWidth: true; text: cityRow.modelData.region; color: K4Theme.muted; font.family: K4Theme.uiFont; font.pixelSize: 10; elide: Text.ElideRight }
                                }
                            }
                            MouseArea { id: cityHover; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.plugin.choose(cityRow.modelData) }
                        }
                        Text { anchors.centerIn: parent; visible: !K4Weather.searching && root.plugin.query.length >= 2 && K4Weather.matches.length === 0; text: "No matching places"; color: K4Theme.muted; font.family: K4Theme.uiFont; font.pixelSize: 12 }
                    }
                }
            }
        }

        Loader {
            Layout.fillWidth: true
            Layout.fillHeight: true
            active: !root.plugin.searchOpen
            sourceComponent: ColumnLayout {
                spacing: 10

                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 112
                    spacing: 14

                    WeatherGlyph {
                        text: K4Weather.icon(K4Weather.current.wCode)
                        font.pixelSize: 68
                        Layout.preferredWidth: 90
                        Layout.fillHeight: true
                    }
                    ColumnLayout {
                        Layout.preferredWidth: 220
                        spacing: 0
                        Text { text: K4Weather.current.temp || "--"; color: K4Theme.ink; font.family: K4Theme.uiFont; font.pixelSize: 42; font.weight: Font.Light }
                        Text { Layout.fillWidth: true; text: K4Weather.current.wDesc || "No weather data"; color: K4Theme.muted; font.family: K4Theme.uiFont; font.pixelSize: 13; elide: Text.ElideRight }
                        Text { text: `Feels like ${K4Weather.current.tempFeelsLike || "--"}`; color: K4Theme.dim; font.family: K4Theme.uiFont; font.pixelSize: 10 }
                    }
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: 14
                        color: K4Theme.surface
                        GridLayout {
                            anchors.fill: parent
                            anchors.margins: 14
                            columns: 3
                            rowSpacing: 8; columnSpacing: 18
                            Repeater {
                                model: [
                                    ["Humidity", K4Weather.current.humidity || "--"],
                                    ["Wind", K4Weather.current.wind || "--"],
                                    ["Precip", K4Weather.current.precip || "--"],
                                    ["Visibility", K4Weather.current.visib || "--"],
                                    ["Pressure", K4Weather.current.press || "--"],
                                    ["UV", String(K4Weather.current.uv ?? "--")]
                                ]
                                delegate: ColumnLayout {
                                    required property var modelData
                                    spacing: 1
                                    Text { text: parent.modelData[0]; color: K4Theme.dim; font.family: K4Theme.uiFont; font.pixelSize: 9 }
                                    Text { text: parent.modelData[1]; color: K4Theme.ink; font.family: K4Theme.uiFont; font.pixelSize: 11; font.weight: Font.DemiBold }
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 92
                    radius: 14
                    color: K4Theme.surface
                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 4
                        Repeater {
                            model: K4Weather.hourly
                            delegate: ColumnLayout {
                                required property var modelData
                                Layout.fillWidth: true; spacing: 2
                                Text { Layout.alignment: Qt.AlignHCenter; text: parent.modelData.hour; color: K4Theme.dim; font.family: K4Theme.uiFont; font.pixelSize: 9 }
                                WeatherGlyph { Layout.alignment: Qt.AlignHCenter; text: K4Weather.icon(parent.modelData.code); font.pixelSize: 22 }
                                Text { Layout.alignment: Qt.AlignHCenter; text: parent.modelData.temp; color: K4Theme.ink; font.family: K4Theme.uiFont; font.pixelSize: 10; font.weight: Font.DemiBold }
                                Text { Layout.alignment: Qt.AlignHCenter; text: parent.modelData.rain > 0 ? `${parent.modelData.rain}%` : ""; color: K4Theme.blue; font.family: K4Theme.uiFont; font.pixelSize: 8 }
                            }
                        }
                        Text { visible: K4Weather.hourly.length === 0; text: K4Weather.loading ? "Loading hourly forecast…" : "Hourly forecast unavailable"; color: K4Theme.muted; font.family: K4Theme.uiFont; font.pixelSize: 11 }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: 14
                    color: K4Theme.surface
                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 5
                        Repeater {
                            model: K4Weather.daily
                            delegate: ColumnLayout {
                                required property var modelData
                                Layout.fillWidth: true; spacing: 3
                                Text { Layout.alignment: Qt.AlignHCenter; text: parent.modelData.date; color: K4Theme.dim; font.family: K4Theme.uiFont; font.pixelSize: 9 }
                                WeatherGlyph { Layout.alignment: Qt.AlignHCenter; text: K4Weather.icon(parent.modelData.code); font.pixelSize: 25 }
                                Text { Layout.alignment: Qt.AlignHCenter; text: `${parent.modelData.max}  ${parent.modelData.min}`; color: K4Theme.ink; font.family: K4Theme.uiFont; font.pixelSize: 10 }
                                Text { Layout.fillWidth: true; text: parent.modelData.description; color: K4Theme.muted; font.family: K4Theme.uiFont; font.pixelSize: 8; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight }
                            }
                        }
                        Text { visible: K4Weather.daily.length === 0; text: K4Weather.error.length ? K4Weather.error : (K4Weather.loading ? "Loading forecast…" : "Forecast unavailable"); color: K4Theme.muted; font.family: K4Theme.uiFont; font.pixelSize: 11 }
                    }
                }
            }
        }
    }
}
