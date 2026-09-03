import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Compact two-page weather surface. Page one is glanceable current/forecast
// information; page two exposes scaled analytical plots and real 7-day history.
Item {
    id: root
    required property var plugin

    property int pageIndex: 0

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

    function hourlyValues(key) {
        const values = []
        for (let i = 0; i < K4Weather.hourly.length; ++i)
            values.push(Number(K4Weather.hourly[i][key] || 0))
        return values
    }

    function valueMin(values, fallback) {
        if (!values.length) return fallback
        let result = Number(values[0])
        for (let i = 1; i < values.length; ++i)
            result = Math.min(result, Number(values[i]))
        return result
    }

    function valueMax(values, fallback) {
        if (!values.length) return fallback
        let result = Number(values[0])
        for (let i = 1; i < values.length; ++i)
            result = Math.max(result, Number(values[i]))
        return result
    }

    function hourlyTempMin() {
        const values = root.hourlyValues("tempValue")
        return Math.floor(root.valueMin(values, 0) - 1)
    }

    function hourlyTempMax() {
        const values = root.hourlyValues("tempValue")
        return Math.ceil(root.valueMax(values, 1) + 1)
    }

    function historyMinimum() {
        if (!K4Weather.history.length) return 0
        let value = Number(K4Weather.history[0].minValue)
        for (let i = 1; i < K4Weather.history.length; ++i)
            value = Math.min(value, Number(K4Weather.history[i].minValue))
        return Math.floor(value - 1)
    }

    function historyMaximum() {
        if (!K4Weather.history.length) return 1
        let value = Number(K4Weather.history[0].maxValue)
        for (let i = 1; i < K4Weather.history.length; ++i)
            value = Math.max(value, Number(K4Weather.history[i].maxValue))
        return Math.ceil(value + 1)
    }

    function historyFraction(value) {
        const low = root.historyMinimum()
        const high = root.historyMaximum()
        return Math.max(0, Math.min(1, (Number(value) - low) / Math.max(1, high - low)))
    }

    function tempValueText(value) {
        if (!Number.isFinite(Number(value))) return "--"
        return `${Math.round(Number(value))}°`
    }

    function precipText(value) {
        const digits = K4Weather.precipitationUnit === "in" ? 2 : 1
        return `${K4Weather.round(Number(value || 0), digits)} ${K4Weather.precipitationUnit}`
    }

    function factLabel(index) {
        return ["Humidity", "Wind", "Precipitation", "Visibility", "Pressure", "UV Index"][index] || ""
    }

    function factValue(index) {
        const current = K4Weather.current
        if (index === 0) return current.humidity || "--"
        if (index === 1) return current.wind || "--"
        if (index === 2) return current.precip || "--"
        if (index === 3) return current.visib || "--"
        if (index === 4) return current.press || "--"
        if (index === 5) return String(current.uv ?? "--")
        return "--"
    }

    function factNote(index) {
        const current = K4Weather.current
        if (index === 0) return K4Weather.humidityStatus(K4Weather.numeric(current.humidity))
        if (index === 1) return current.windDir || "Current"
        if (index === 2) return K4Weather.precipitationStatus()
        if (index === 3) return K4Weather.visibilityStatus(current.visib)
        if (index === 4) return "Current"
        if (index === 5) return K4Weather.uvStatus(current.uv)
        return ""
    }

    component WeatherGlyph: Text {
        color: K4Theme.ink
        font.family: K4Theme.iconFont
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        renderType: Text.NativeRendering
    }

    component Hairline: Rectangle {
        implicitHeight: 1
        color: K4Theme.panelLine
    }

    component HeaderButton: Rectangle {
        id: button
        property string glyph: ""
        signal activated()

        implicitWidth: 28
        implicitHeight: 26
        radius: 8
        color: K4Theme.islandBg
        border.width: 1
        border.color: buttonMouse.containsMouse ? K4Theme.panelLineStrong : "transparent"

        Text {
            anchors.centerIn: parent
            text: button.glyph
            color: buttonMouse.containsMouse ? K4Theme.ink : K4Theme.muted
            font.family: K4Theme.iconFont
            font.pixelSize: 14
        }

        MouseArea {
            id: buttonMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: button.activated()
        }
    }

    component WeatherLineChart: Item {
        id: lineChart
        property var values: []
        property real minimum: 0
        property real maximum: 100
        property color lineColor: K4Theme.ink
        property int gridCount: 3

        onValuesChanged: chart.requestPaint()
        onMinimumChanged: chart.requestPaint()
        onMaximumChanged: chart.requestPaint()
        onLineColorChanged: chart.requestPaint()

        Canvas {
            id: chart
            anchors.fill: parent
            antialiasing: true

            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()

            onPaint: {
                const ctx = getContext("2d")
                ctx.clearRect(0, 0, width, height)

                ctx.lineWidth = 1
                ctx.strokeStyle = String(K4Theme.panelLine)
                const count = Math.max(2, lineChart.gridCount)
                for (let i = 0; i < count; ++i) {
                    const y = 1 + (height - 2) * i / (count - 1)
                    ctx.beginPath()
                    ctx.moveTo(0, y)
                    ctx.lineTo(width, y)
                    ctx.stroke()
                }

                if (!lineChart.values || lineChart.values.length < 2) return
                const range = Math.max(1, lineChart.maximum - lineChart.minimum)
                const point = function(index) {
                    const x = 2 + (width - 4) * index / Math.max(1, lineChart.values.length - 1)
                    const normalized = (Number(lineChart.values[index]) - lineChart.minimum) / range
                    const y = height - 3 - Math.max(0, Math.min(1, normalized)) * (height - 6)
                    return { x: x, y: y }
                }

                ctx.lineWidth = 1.7
                ctx.lineJoin = "round"
                ctx.lineCap = "round"
                ctx.strokeStyle = String(lineChart.lineColor)
                ctx.beginPath()
                let p = point(0)
                ctx.moveTo(p.x, p.y)
                for (let i = 1; i < lineChart.values.length; ++i) {
                    p = point(i)
                    ctx.lineTo(p.x, p.y)
                }
                ctx.stroke()

                ctx.fillStyle = String(K4Theme.islandBg)
                ctx.strokeStyle = String(lineChart.lineColor)
                ctx.lineWidth = 1.2
                for (let i = 0; i < lineChart.values.length; ++i) {
                    p = point(i)
                    ctx.beginPath()
                    ctx.arc(p.x, p.y, 2.3, 0, Math.PI * 2)
                    ctx.fill()
                    ctx.stroke()
                }
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        color: K4Theme.islandBg
        z: -1
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        anchors.topMargin: 12
        anchors.bottomMargin: 14
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 28
            spacing: 8

            Rectangle {
                Layout.preferredWidth: 6
                Layout.preferredHeight: 6
                radius: 3
                color: "#8fd8ff"
            }

            Text {
                Layout.fillWidth: true
                text: K4Weather.place.length ? K4Weather.place : "No location"
                color: K4Theme.ink
                font.family: K4Theme.uiFont
                font.pixelSize: 13
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }

            Text {
                visible: K4Weather.loading || K4Weather.historyLoading
                text: K4Weather.loading ? "updating…" : "history…"
                color: K4Theme.dim
                font.family: K4Theme.uiFont
                font.pixelSize: 8
            }

            Text {
                visible: !K4Weather.loading && !K4Weather.historyLoading && String(K4Weather.current.lastRefresh || "").length > 0
                text: K4Weather.current.lastRefresh || ""
                color: K4Theme.dim
                font.family: K4Theme.uiFont
                font.pixelSize: 8
            }

            HeaderButton {
                glyph: String.fromCodePoint(0xF0349)
                onActivated: root.plugin.searchOpen ? root.plugin.closeSearch() : root.plugin.openSearch()
            }
            HeaderButton {
                glyph: String.fromCodePoint(0xF0450)
                onActivated: K4Weather.refresh()
            }
            HeaderButton {
                glyph: K4Theme.ico.close
                onActivated: root.plugin.close()
            }
        }

        Hairline { Layout.fillWidth: true }

        Loader {
            Layout.fillWidth: true
            Layout.fillHeight: true
            active: root.plugin.searchOpen
            visible: active
            sourceComponent: Rectangle {
                color: K4Theme.islandBg

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 8

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 38
                        radius: 10
                        color: K4Theme.islandBg
                        border.width: 1
                        border.color: K4Theme.panelLineStrong

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 11
                            anchors.rightMargin: 11
                            spacing: 8

                            Text {
                                text: String.fromCodePoint(0xF0349)
                                color: K4Theme.muted
                                font.family: K4Theme.iconFont
                                font.pixelSize: 14
                            }

                            Item {
                                Layout.fillWidth: true
                                Layout.fillHeight: true

                                Text {
                                    anchors.fill: parent
                                    verticalAlignment: Text.AlignVCenter
                                    visible: cityInput.text.length === 0
                                    text: "Type a city…"
                                    color: K4Theme.dim
                                    font.family: K4Theme.uiFont
                                    font.pixelSize: 13
                                }

                                TextInput {
                                    id: cityInput
                                    anchors.fill: parent
                                    verticalAlignment: TextInput.AlignVCenter
                                    color: K4Theme.ink
                                    font.family: K4Theme.uiFont
                                    font.pixelSize: 13
                                    focus: true
                                    clip: true
                                    selectByMouse: true
                                    cursorVisible: true
                                    selectionColor: K4Theme.blue
                                    text: root.plugin.query
                                    Component.onCompleted: Qt.callLater(() => forceActiveFocus())
                                    onTextEdited: {
                                        root.plugin.query = text
                                        searchDelay.restart()
                                    }
                                    Keys.onPressed: function(event) {
                                        if (event.key === Qt.Key_Escape) {
                                            root.plugin.closeSearch()
                                            event.accepted = true
                                        } else if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && K4Weather.matches.length > 0) {
                                            root.plugin.choose(K4Weather.matches[0])
                                            event.accepted = true
                                        }
                                    }

                                    Timer {
                                        id: searchDelay
                                        interval: 350
                                        onTriggered: K4Weather.search(root.plugin.query)
                                    }
                                }
                            }

                            Text {
                                text: K4Weather.searching ? "searching…" : "esc"
                                color: K4Theme.dim
                                font.family: K4Theme.uiFont
                                font.pixelSize: 8
                            }
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
                            height: 42
                            radius: 8
                            color: K4Theme.islandBg
                            border.width: cityHover.containsMouse ? 1 : 0
                            border.color: K4Theme.panelLineStrong

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                spacing: 9

                                Text {
                                    text: String.fromCodePoint(0xF0417)
                                    color: K4Theme.muted
                                    font.family: K4Theme.iconFont
                                    font.pixelSize: 14
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 0
                                    Text {
                                        Layout.fillWidth: true
                                        text: cityRow.modelData.name
                                        color: K4Theme.ink
                                        font.family: K4Theme.uiFont
                                        font.pixelSize: 12
                                        font.weight: Font.DemiBold
                                        elide: Text.ElideRight
                                    }
                                    Text {
                                        Layout.fillWidth: true
                                        text: cityRow.modelData.region
                                        color: K4Theme.muted
                                        font.family: K4Theme.uiFont
                                        font.pixelSize: 9
                                        elide: Text.ElideRight
                                    }
                                }
                            }

                            MouseArea {
                                id: cityHover
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.plugin.choose(cityRow.modelData)
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: !K4Weather.searching && root.plugin.query.length >= 2 && K4Weather.matches.length === 0
                            text: "No matching places"
                            color: K4Theme.muted
                            font.family: K4Theme.uiFont
                            font.pixelSize: 11
                        }
                    }
                }
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: !root.plugin.searchOpen

            ListView {
                id: pages
                anchors.fill: parent
                orientation: ListView.Vertical
                model: 2
                clip: true
                snapMode: ListView.SnapOneItem
                boundsBehavior: Flickable.StopAtBounds
                flickDeceleration: 5000

                onContentYChanged: {
                    if (height > 0)
                        root.pageIndex = Math.max(0, Math.min(1, Math.round(contentY / height)))
                }

                delegate: Loader {
                    required property int index
                    width: pages.width
                    height: pages.height
                    sourceComponent: index === 0 ? overviewPage : detailsPage
                }
            }

            Column {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 5
                z: 5

                Repeater {
                    model: 2
                    delegate: Rectangle {
                        required property int index
                        width: 3
                        height: root.pageIndex === index ? 22 : 12
                        radius: 2
                        color: root.pageIndex === index ? K4Theme.ink : K4Theme.panelLineStrong

                        Behavior on height { NumberAnimation { duration: 120 } }

                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -5
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.pageIndex = index
                                pages.positionViewAtIndex(index, ListView.Beginning)
                            }
                        }
                    }
                }
            }

            Row {
                visible: root.pageIndex === 0
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.rightMargin: 9
                spacing: 3
                opacity: 0.45

                Text {
                    text: K4Theme.ico.chevronUp
                    rotation: 180
                    color: K4Theme.dim
                    font.family: K4Theme.iconFont
                    font.pixelSize: 9
                }
                Text {
                    text: "scroll for details"
                    color: K4Theme.dim
                    font.family: K4Theme.uiFont
                    font.pixelSize: 7
                }
            }
        }
    }

    Component {
        id: overviewPage

        Item {
            ColumnLayout {
                anchors.fill: parent
                anchors.rightMargin: 10
                spacing: 0

                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 100
                    spacing: 22

                    RowLayout {
                        Layout.preferredWidth: 320
                        Layout.fillHeight: true
                        spacing: 14

                        WeatherGlyph {
                            text: K4Weather.icon(K4Weather.current.wCode)
                            font.pixelSize: 54
                            Layout.preferredWidth: 62
                            Layout.fillHeight: true
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            Text {
                                text: K4Weather.current.temp || "--"
                                color: K4Theme.ink
                                font.family: K4Theme.uiFont
                                font.pixelSize: 43
                                font.weight: Font.Light
                            }
                            Text {
                                text: K4Weather.current.wDesc || "No weather data"
                                color: K4Theme.ink
                                font.family: K4Theme.uiFont
                                font.pixelSize: 12
                                font.weight: Font.DemiBold
                            }
                            Text {
                                text: `Feels like ${K4Weather.current.tempFeelsLike || "--"}`
                                color: K4Theme.muted
                                font.family: K4Theme.uiFont
                                font.pixelSize: 8
                            }
                            Text {
                                text: K4Weather.daily.length > 0
                                    ? `${K4Weather.daily[0].max} high   ${K4Weather.daily[0].min} low`
                                    : ""
                                color: K4Theme.dim
                                font.family: K4Theme.uiFont
                                font.pixelSize: 8
                            }
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        Layout.maximumWidth: 335
                        text: K4Weather.summary
                        color: K4Theme.ink
                        font.family: K4Theme.uiFont
                        font.pixelSize: 14
                        font.weight: Font.Medium
                        lineHeight: 1.18
                        wrapMode: Text.WordWrap
                    }
                }

                Hairline { Layout.fillWidth: true }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 56
                    spacing: 0

                    Repeater {
                        model: 6
                        delegate: Item {
                            required property int index
                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            Column {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.leftMargin: index === 0 ? 1 : 10
                                spacing: 2

                                Text {
                                    text: root.factLabel(index).toUpperCase()
                                    color: K4Theme.dim
                                    font.family: K4Theme.uiFont
                                    font.pixelSize: 7
                                    font.letterSpacing: 0.3
                                }
                                Text {
                                    text: root.factValue(index)
                                    color: K4Theme.ink
                                    font.family: K4Theme.uiFont
                                    font.pixelSize: 11
                                    font.weight: Font.DemiBold
                                }
                                Text {
                                    text: root.factNote(index)
                                    color: K4Theme.muted
                                    font.family: K4Theme.uiFont
                                    font.pixelSize: 7
                                }
                            }

                            Rectangle {
                                visible: index < 5
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                anchors.topMargin: 9
                                anchors.bottomMargin: 9
                                width: 1
                                color: K4Theme.panelLine
                            }
                        }
                    }
                }

                Hairline { Layout.fillWidth: true }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 20
                    Text {
                        text: "Today"
                        color: K4Theme.ink
                        font.family: K4Theme.uiFont
                        font.pixelSize: 9
                        font.weight: Font.DemiBold
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: "temperature · rain chance"
                        color: K4Theme.dim
                        font.family: K4Theme.uiFont
                        font.pixelSize: 7
                    }
                }

                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 78

                    WeatherLineChart {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        anchors.topMargin: 17
                        anchors.bottomMargin: 21
                        values: root.hourlyValues("tempValue")
                        minimum: root.hourlyTempMin()
                        maximum: root.hourlyTempMax()
                        lineColor: "#8fd8ff"
                    }

                    Row {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        height: 13

                        Repeater {
                            model: K4Weather.hourly.length
                            delegate: Text {
                                required property int index
                                width: parent.width / Math.max(1, K4Weather.hourly.length)
                                text: K4Weather.hourly[index].temp || "--"
                                color: K4Theme.ink
                                font.family: K4Theme.uiFont
                                font.pixelSize: 7
                                font.weight: Font.DemiBold
                                horizontalAlignment: Text.AlignHCenter
                            }
                        }
                    }

                    Row {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        height: 20

                        Repeater {
                            model: K4Weather.hourly.length
                            delegate: Column {
                                required property int index
                                width: parent.width / Math.max(1, K4Weather.hourly.length)
                                spacing: 0
                                Text {
                                    width: parent.width
                                    text: `${K4Weather.hourly[index].rain}%`
                                    color: K4Theme.blue
                                    font.family: K4Theme.uiFont
                                    font.pixelSize: 6
                                    horizontalAlignment: Text.AlignHCenter
                                }
                                Text {
                                    width: parent.width
                                    text: K4Weather.hourly[index].hour || ""
                                    color: K4Theme.dim
                                    font.family: K4Theme.uiFont
                                    font.pixelSize: 6
                                    horizontalAlignment: Text.AlignHCenter
                                }
                            }
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: K4Weather.hourly.length === 0
                        text: K4Weather.loading ? "Loading hourly forecast…" : "Hourly forecast unavailable"
                        color: K4Theme.muted
                        font.family: K4Theme.uiFont
                        font.pixelSize: 10
                    }
                }

                Hairline { Layout.fillWidth: true }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 20
                    Text {
                        text: "Next 3 days"
                        color: K4Theme.ink
                        font.family: K4Theme.uiFont
                        font.pixelSize: 9
                        font.weight: Font.DemiBold
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: "high / low"
                        color: K4Theme.dim
                        font.family: K4Theme.uiFont
                        font.pixelSize: 7
                    }
                }

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    Column {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top

                        Repeater {
                            model: Math.min(3, K4Weather.daily.length)
                            delegate: Item {
                                required property int index
                                width: parent.width
                                height: 25
                                readonly property var day: K4Weather.daily[index]

                                Text {
                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 60
                                    text: index === 0 ? "Today" : day.label
                                    color: K4Theme.ink
                                    font.family: K4Theme.uiFont
                                    font.pixelSize: 8
                                    font.weight: Font.DemiBold
                                }
                                WeatherGlyph {
                                    anchors.left: parent.left
                                    anchors.leftMargin: 62
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 22
                                    text: K4Weather.icon(day.code)
                                    font.pixelSize: 16
                                    color: K4Theme.muted
                                }
                                Text {
                                    anchors.left: parent.left
                                    anchors.leftMargin: 92
                                    anchors.right: rainText.left
                                    anchors.rightMargin: 10
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: day.description
                                    color: K4Theme.muted
                                    font.family: K4Theme.uiFont
                                    font.pixelSize: 7
                                    elide: Text.ElideRight
                                }
                                Text {
                                    id: rainText
                                    anchors.right: tempsText.left
                                    anchors.rightMargin: 18
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 38
                                    text: `${day.rain}%`
                                    color: K4Theme.blue
                                    font.family: K4Theme.uiFont
                                    font.pixelSize: 7
                                    horizontalAlignment: Text.AlignRight
                                }
                                Text {
                                    id: tempsText
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 84
                                    text: `${day.max}   ${day.min}`
                                    color: K4Theme.ink
                                    font.family: K4Theme.uiFont
                                    font.pixelSize: 8
                                    horizontalAlignment: Text.AlignRight
                                }
                                Hairline {
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.bottom: parent.bottom
                                    visible: index < Math.min(3, K4Weather.daily.length) - 1
                                }
                            }
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: K4Weather.daily.length === 0
                        text: K4Weather.error.length ? K4Weather.error : (K4Weather.loading ? "Loading forecast…" : "Forecast unavailable")
                        color: K4Theme.muted
                        font.family: K4Theme.uiFont
                        font.pixelSize: 10
                    }
                }
            }
        }
    }

    Component {
        id: detailsPage

        Item {
            ColumnLayout {
                anchors.fill: parent
                anchors.rightMargin: 10
                spacing: 0

                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 34
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        Text {
                            text: "Weather details"
                            color: K4Theme.ink
                            font.family: K4Theme.uiFont
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                        }
                        Text {
                            text: "Hourly conditions today · 7-day context below"
                            color: K4Theme.muted
                            font.family: K4Theme.uiFont
                            font.pixelSize: 7
                        }
                    }
                    Text {
                        text: "local time"
                        color: K4Theme.dim
                        font.family: K4Theme.uiFont
                        font.pixelSize: 7
                    }
                }

                Hairline { Layout.fillWidth: true }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 132
                    spacing: 18

                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        Text {
                            anchors.left: parent.left
                            anchors.top: parent.top
                            text: "Precipitation chance"
                            color: K4Theme.ink
                            font.family: K4Theme.uiFont
                            font.pixelSize: 9
                            font.weight: Font.DemiBold
                        }
                        Text {
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.topMargin: 13
                            text: "hourly probability"
                            color: K4Theme.muted
                            font.family: K4Theme.uiFont
                            font.pixelSize: 7
                        }
                        Text {
                            anchors.right: parent.right
                            anchors.top: parent.top
                            text: `${K4Weather.peakRainChance()}%`
                            color: K4Theme.ink
                            font.family: K4Theme.uiFont
                            font.pixelSize: 11
                            font.weight: Font.DemiBold
                        }
                        Text {
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.topMargin: 14
                            text: "daily peak"
                            color: K4Theme.dim
                            font.family: K4Theme.uiFont
                            font.pixelSize: 6
                        }

                        Item {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.topMargin: 34
                            anchors.bottom: parent.bottom

                            Column {
                                anchors.left: parent.left
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: 16
                                width: 24

                                Text { width: parent.width; height: parent.height / 3; text: "100"; color: K4Theme.dim; font.family: K4Theme.uiFont; font.pixelSize: 6; horizontalAlignment: Text.AlignRight }
                                Text { width: parent.width; height: parent.height / 3; text: "50"; color: K4Theme.dim; font.family: K4Theme.uiFont; font.pixelSize: 6; horizontalAlignment: Text.AlignRight; verticalAlignment: Text.AlignVCenter }
                                Text { width: parent.width; height: parent.height / 3; text: "0%"; color: K4Theme.dim; font.family: K4Theme.uiFont; font.pixelSize: 6; horizontalAlignment: Text.AlignRight; verticalAlignment: Text.AlignBottom }
                            }

                            Item {
                                id: precipPlot
                                anchors.left: parent.left
                                anchors.leftMargin: 31
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom

                                Repeater {
                                    model: 3
                                    delegate: Rectangle {
                                        required property int index
                                        x: 0
                                        y: index * (precipPlot.height - 16) / 2
                                        width: precipPlot.width
                                        height: 1
                                        color: K4Theme.panelLine
                                    }
                                }

                                Row {
                                    id: precipBars
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.top: parent.top
                                    anchors.bottom: parent.bottom
                                    anchors.bottomMargin: 16

                                    Repeater {
                                        model: K4Weather.hourly.length
                                        delegate: Item {
                                            required property int index
                                            width: precipBars.width / Math.max(1, K4Weather.hourly.length)
                                            height: precipBars.height
                                            readonly property real chance: Number(K4Weather.hourly[index].rain || 0)

                                            Rectangle {
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                anchors.bottom: parent.bottom
                                                width: Math.max(7, parent.width * 0.35)
                                                height: chance > 0 ? Math.max(2, parent.height * chance / 100) : 0
                                                radius: 2
                                                color: K4Theme.blue
                                                opacity: 0.78
                                            }

                                            Text {
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                anchors.bottom: parent.bottom
                                                anchors.bottomMargin: chance > 0 ? Math.max(4, parent.height * chance / 100 + 2) : 2
                                                text: chance > 0 ? `${chance}` : ""
                                                color: K4Theme.blue
                                                font.family: K4Theme.uiFont
                                                font.pixelSize: 6
                                            }
                                        }
                                    }
                                }

                                Row {
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.bottom: parent.bottom
                                    height: 13
                                    Repeater {
                                        model: K4Weather.hourly.length
                                        delegate: Text {
                                            required property int index
                                            width: parent.width / Math.max(1, K4Weather.hourly.length)
                                            text: K4Weather.hourly[index].hour.substring(0, 2)
                                            color: K4Theme.dim
                                            font.family: K4Theme.uiFont
                                            font.pixelSize: 6
                                            horizontalAlignment: Text.AlignHCenter
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Rectangle {
                        Layout.preferredWidth: 1
                        Layout.fillHeight: true
                        Layout.topMargin: 7
                        Layout.bottomMargin: 7
                        color: K4Theme.panelLine
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        Text {
                            anchors.left: parent.left
                            anchors.top: parent.top
                            text: "Humidity"
                            color: K4Theme.ink
                            font.family: K4Theme.uiFont
                            font.pixelSize: 9
                            font.weight: Font.DemiBold
                        }
                        Text {
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.topMargin: 13
                            text: "relative humidity"
                            color: K4Theme.muted
                            font.family: K4Theme.uiFont
                            font.pixelSize: 7
                        }
                        Text {
                            anchors.right: parent.right
                            anchors.top: parent.top
                            text: K4Weather.current.humidity || "--"
                            color: K4Theme.ink
                            font.family: K4Theme.uiFont
                            font.pixelSize: 11
                            font.weight: Font.DemiBold
                        }
                        Text {
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.topMargin: 14
                            text: "current"
                            color: K4Theme.dim
                            font.family: K4Theme.uiFont
                            font.pixelSize: 6
                        }

                        Item {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.topMargin: 34
                            anchors.bottom: parent.bottom

                            Column {
                                anchors.left: parent.left
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: 16
                                width: 24
                                Text { width: parent.width; height: parent.height / 3; text: "100"; color: K4Theme.dim; font.family: K4Theme.uiFont; font.pixelSize: 6; horizontalAlignment: Text.AlignRight }
                                Text { width: parent.width; height: parent.height / 3; text: "50"; color: K4Theme.dim; font.family: K4Theme.uiFont; font.pixelSize: 6; horizontalAlignment: Text.AlignRight; verticalAlignment: Text.AlignVCenter }
                                Text { width: parent.width; height: parent.height / 3; text: "0%"; color: K4Theme.dim; font.family: K4Theme.uiFont; font.pixelSize: 6; horizontalAlignment: Text.AlignRight; verticalAlignment: Text.AlignBottom }
                            }

                            Item {
                                anchors.left: parent.left
                                anchors.leftMargin: 31
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom

                                WeatherLineChart {
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.top: parent.top
                                    anchors.bottom: parent.bottom
                                    anchors.bottomMargin: 16
                                    values: root.hourlyValues("humidity")
                                    minimum: 0
                                    maximum: 100
                                    lineColor: "#aaa5ff"
                                }

                                Row {
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.bottom: parent.bottom
                                    height: 13
                                    Repeater {
                                        model: K4Weather.hourly.length
                                        delegate: Text {
                                            required property int index
                                            width: parent.width / Math.max(1, K4Weather.hourly.length)
                                            text: K4Weather.hourly[index].hour.substring(0, 2)
                                            color: K4Theme.dim
                                            font.family: K4Theme.uiFont
                                            font.pixelSize: 6
                                            horizontalAlignment: Text.AlignHCenter
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                Hairline { Layout.fillWidth: true }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 24
                    Text {
                        Layout.preferredWidth: 64
                        text: "7-day history"
                        color: K4Theme.ink
                        font.family: K4Theme.uiFont
                        font.pixelSize: 9
                        font.weight: Font.DemiBold
                    }
                    Text {
                        Layout.fillWidth: true
                        text: "temperature range"
                        color: K4Theme.dim
                        font.family: K4Theme.uiFont
                        font.pixelSize: 6
                    }
                    Text {
                        Layout.preferredWidth: 56
                        text: "rain"
                        color: K4Theme.dim
                        font.family: K4Theme.uiFont
                        font.pixelSize: 6
                        horizontalAlignment: Text.AlignRight
                    }
                    Text {
                        Layout.preferredWidth: 58
                        text: "humidity"
                        color: K4Theme.dim
                        font.family: K4Theme.uiFont
                        font.pixelSize: 6
                        horizontalAlignment: Text.AlignRight
                    }
                }

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    Column {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top

                        Repeater {
                            model: K4Weather.history.length
                            delegate: Item {
                                required property int index
                                width: parent.width
                                height: 21
                                readonly property var day: K4Weather.history[index]

                                Text {
                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 64
                                    text: day.label
                                    color: K4Theme.ink
                                    font.family: K4Theme.uiFont
                                    font.pixelSize: 7
                                    font.weight: Font.DemiBold
                                }

                                Item {
                                    id: rangeCell
                                    anchors.left: parent.left
                                    anchors.leftMargin: 72
                                    anchors.right: rainHistory.left
                                    anchors.rightMargin: 12
                                    anchors.top: parent.top
                                    anchors.bottom: parent.bottom

                                    Text {
                                        anchors.left: parent.left
                                        anchors.top: parent.top
                                        text: `${root.tempValueText(day.minValue)} → ${root.tempValueText(day.maxValue)}`
                                        color: K4Theme.muted
                                        font.family: K4Theme.uiFont
                                        font.pixelSize: 6
                                    }

                                    Rectangle {
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.top: parent.top
                                        anchors.topMargin: 14
                                        height: 1
                                        color: K4Theme.panelLine
                                    }

                                    Rectangle {
                                        id: rangeBand
                                        x: rangeCell.width * root.historyFraction(day.minValue)
                                        y: 12
                                        width: Math.max(5, rangeCell.width * (root.historyFraction(day.maxValue) - root.historyFraction(day.minValue)))
                                        height: 5
                                        radius: 3
                                        gradient: Gradient {
                                            orientation: Gradient.Horizontal
                                            GradientStop { position: 0; color: "#8fd8ff" }
                                            GradientStop { position: 1; color: "#ffd37a" }
                                        }
                                    }

                                    Rectangle {
                                        x: rangeBand.x - 2
                                        y: 12
                                        width: 5
                                        height: 5
                                        radius: 3
                                        color: K4Theme.islandBg
                                        border.width: 1
                                        border.color: K4Theme.ink
                                    }
                                    Rectangle {
                                        x: rangeBand.x + rangeBand.width - 3
                                        y: 12
                                        width: 5
                                        height: 5
                                        radius: 3
                                        color: K4Theme.islandBg
                                        border.width: 1
                                        border.color: K4Theme.ink
                                    }
                                }

                                Text {
                                    id: rainHistory
                                    anchors.right: humidityHistory.left
                                    anchors.rightMargin: 12
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 56
                                    text: root.precipText(day.precip)
                                    color: K4Theme.muted
                                    font.family: K4Theme.uiFont
                                    font.pixelSize: 7
                                    horizontalAlignment: Text.AlignRight
                                }

                                Text {
                                    id: humidityHistory
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 58
                                    text: `${Math.round(Number(day.humidity || 0))}%`
                                    color: K4Theme.muted
                                    font.family: K4Theme.uiFont
                                    font.pixelSize: 7
                                    horizontalAlignment: Text.AlignRight
                                }

                                Hairline {
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.bottom: parent.bottom
                                    visible: index < K4Weather.history.length - 1
                                }
                            }
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: K4Weather.history.length === 0
                        text: K4Weather.historyError.length
                            ? K4Weather.historyError
                            : (K4Weather.historyLoading ? "Loading 7-day history…" : "7-day history unavailable")
                        color: K4Theme.muted
                        font.family: K4Theme.uiFont
                        font.pixelSize: 10
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 18
                    Item { Layout.preferredWidth: 72 }
                    Text {
                        Layout.fillWidth: true
                        text: `${root.tempValueText(root.historyMinimum())}                 ${root.tempValueText((root.historyMinimum() + root.historyMaximum()) / 2)}                 ${root.tempValueText(root.historyMaximum())}`
                        color: K4Theme.dim
                        font.family: K4Theme.uiFont
                        font.pixelSize: 6
                        horizontalAlignment: Text.AlignHCenter
                    }
                    Item { Layout.preferredWidth: 126 }
                }
            }
        }
    }
}
