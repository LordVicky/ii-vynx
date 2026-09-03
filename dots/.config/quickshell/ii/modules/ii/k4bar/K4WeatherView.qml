import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Three-page weather utility. The K4 host owns the rounded OLED silhouette;
// this view only paints content inside that surface.
Item {
    id: root
    required property var plugin

    property int pageIndex: 0

    opacity: 0
    clip: true
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
        return Math.floor(root.valueMin(root.hourlyValues("tempValue"), 0) - 1)
    }

    function hourlyTempMax() {
        return Math.ceil(root.valueMax(root.hourlyValues("tempValue"), 1) + 1)
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
        return Math.max(0, Math.min(1,
            (Number(value) - low) / Math.max(1, high - low)))
    }

    function tempValueText(value) {
        return Number.isFinite(Number(value))
            ? `${Math.round(Number(value))}°` : "--"
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
        if (index === 0)
            return K4Weather.humidityStatus(K4Weather.numeric(current.humidity))
        if (index === 1) return current.windDir || "Current"
        if (index === 2) return K4Weather.precipitationStatus()
        if (index === 3) return K4Weather.visibilityStatus(current.visib)
        if (index === 4) return "Current"
        if (index === 5) return K4Weather.uvStatus(current.uv)
        return ""
    }

    component MetaText: Text {
        color: K4Theme.muted
        font.family: K4Theme.uiFont
        font.pixelSize: 11
        textFormat: Text.PlainText
    }

    component LabelText: Text {
        color: K4Theme.muted
        font.family: K4Theme.uiFont
        font.pixelSize: 11
        textFormat: Text.PlainText
    }

    component ValueText: Text {
        color: K4Theme.ink
        font.family: K4Theme.uiFont
        font.pixelSize: 12
        font.weight: Font.DemiBold
        textFormat: Text.PlainText
    }

    component WeatherGlyph: Text {
        color: K4Theme.ink
        font.family: K4Theme.iconFont
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        textFormat: Text.PlainText
    }

    component Hairline: Rectangle {
        implicitHeight: 1
        color: K4Theme.panelLineStrong
        opacity: 0.72
    }

    component HeaderButton: Rectangle {
        id: button
        property string glyph: ""
        signal activated()

        implicitWidth: 30
        implicitHeight: 28
        radius: 9
        color: buttonMouse.containsMouse
            ? Qt.rgba(1, 1, 1, 0.05) : "transparent"
        border.width: 1
        border.color: buttonMouse.containsMouse
            ? K4Theme.panelLineStrong : "transparent"

        Text {
            anchors.centerIn: parent
            text: button.glyph
            color: buttonMouse.containsMouse ? K4Theme.ink : K4Theme.muted
            font.family: K4Theme.iconFont
            font.pixelSize: 15
            textFormat: Text.PlainText
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

                ctx.lineWidth = 1.2
                ctx.strokeStyle = String(K4Theme.panelLineStrong)
                ctx.globalAlpha = 0.8
                const count = Math.max(2, lineChart.gridCount)
                for (let i = 0; i < count; ++i) {
                    const y = 1 + (height - 2) * i / (count - 1)
                    ctx.beginPath()
                    ctx.moveTo(0, y)
                    ctx.lineTo(width, y)
                    ctx.stroke()
                }
                ctx.globalAlpha = 1

                if (!lineChart.values || lineChart.values.length < 2)
                    return

                const range = Math.max(1, lineChart.maximum - lineChart.minimum)
                const point = function(index) {
                    const x = 4 + (width - 8) * index
                        / Math.max(1, lineChart.values.length - 1)
                    const normalized = (Number(lineChart.values[index])
                        - lineChart.minimum) / range
                    const y = height - 5
                        - Math.max(0, Math.min(1, normalized)) * (height - 10)
                    return { x: x, y: y }
                }

                ctx.lineWidth = 2.4
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
                ctx.lineWidth = 1.7
                for (let i = 0; i < lineChart.values.length; ++i) {
                    p = point(i)
                    ctx.beginPath()
                    ctx.arc(p.x, p.y, 3, 0, Math.PI * 2)
                    ctx.fill()
                    ctx.stroke()
                }
            }
        }
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
            Layout.preferredHeight: 30
            spacing: 8

            Rectangle {
                Layout.preferredWidth: 7
                Layout.preferredHeight: 7
                radius: 4
                color: "#67d8ff"
            }

            Text {
                Layout.fillWidth: true
                text: K4Weather.place.length ? K4Weather.place : "No location"
                color: K4Theme.ink
                font.family: K4Theme.uiFont
                font.pixelSize: 14
                font.weight: Font.DemiBold
                elide: Text.ElideRight
                textFormat: Text.PlainText
            }

            MetaText {
                visible: K4Weather.loading || K4Weather.historyLoading
                text: K4Weather.loading ? "Updating…" : "Loading history…"
            }

            LabelText {
                visible: !K4Weather.loading && !K4Weather.historyLoading
                    && String(K4Weather.current.lastRefresh || "").length > 0
                text: K4Weather.current.lastRefresh || ""
            }

            HeaderButton {
                glyph: String.fromCodePoint(0xF0349)
                onActivated: root.plugin.searchOpen
                    ? root.plugin.closeSearch() : root.plugin.openSearch()
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
            sourceComponent: Item {
                ColumnLayout {
                    anchors.fill: parent
                    spacing: 9

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 44
                        radius: 11
                        color: Qt.rgba(1, 1, 1, 0.03)
                        border.width: 1
                        border.color: K4Theme.panelLineStrong

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 10

                            Text {
                                text: String.fromCodePoint(0xF0349)
                                color: K4Theme.muted
                                font.family: K4Theme.iconFont
                                font.pixelSize: 15
                                textFormat: Text.PlainText
                            }

                            Item {
                                Layout.fillWidth: true
                                Layout.fillHeight: true

                                MetaText {
                                    anchors.fill: parent
                                    verticalAlignment: Text.AlignVCenter
                                    visible: cityInput.text.length === 0
                                    text: "Type a city…"
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
                                    Component.onCompleted:
                                        Qt.callLater(() => forceActiveFocus())
                                    onTextEdited: {
                                        root.plugin.query = text
                                        searchDelay.restart()
                                    }
                                    Keys.onPressed: function(event) {
                                        if (event.key === Qt.Key_Escape) {
                                            root.plugin.closeSearch()
                                            event.accepted = true
                                        } else if ((event.key === Qt.Key_Return
                                                || event.key === Qt.Key_Enter)
                                                && K4Weather.matches.length > 0) {
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

                            LabelText {
                                text: K4Weather.searching ? "Searching…" : "Esc"
                            }
                        }
                    }

                    ListView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        model: K4Weather.matches
                        spacing: 4
                        boundsBehavior: Flickable.StopAtBounds

                        delegate: Rectangle {
                            id: cityRow
                            required property var modelData
                            width: ListView.view.width
                            height: 48
                            radius: 10
                            color: cityHover.containsMouse
                                ? Qt.rgba(1, 1, 1, 0.04) : "transparent"
                            border.width: cityHover.containsMouse ? 1 : 0
                            border.color: K4Theme.panelLineStrong

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 11
                                anchors.rightMargin: 11
                                spacing: 10

                                Text {
                                    text: String.fromCodePoint(0xF0417)
                                    color: K4Theme.muted
                                    font.family: K4Theme.iconFont
                                    font.pixelSize: 15
                                    textFormat: Text.PlainText
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 1
                                    ValueText {
                                        Layout.fillWidth: true
                                        text: cityRow.modelData.name
                                        font.pixelSize: 13
                                        elide: Text.ElideRight
                                    }
                                    MetaText {
                                        Layout.fillWidth: true
                                        text: cityRow.modelData.region
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

                        MetaText {
                            anchors.centerIn: parent
                            visible: !K4Weather.searching
                                && root.plugin.query.length >= 2
                                && K4Weather.matches.length === 0
                            text: "No matching places"
                            font.pixelSize: 12
                        }
                    }
                }
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: !root.plugin.searchOpen
            clip: true

            Item {
                id: pageViewport
                anchors.fill: parent
                clip: true

                Item {
                    id: pageStack
                    width: pageViewport.width
                    height: pageViewport.height * 3
                    y: -root.pageIndex * pageViewport.height

                    Behavior on y {
                        NumberAnimation {
                            duration: 220
                            easing.type: Easing.OutCubic
                        }
                    }

                    Loader {
                        x: 0
                        y: 0
                        width: pageViewport.width
                        height: pageViewport.height
                        sourceComponent: overviewPage
                        clip: true
                    }

                    Loader {
                        x: 0
                        y: pageViewport.height
                        width: pageViewport.width
                        height: pageViewport.height
                        sourceComponent: detailsPage
                        clip: true
                    }

                    Loader {
                        x: 0
                        y: pageViewport.height * 2
                        width: pageViewport.width
                        height: pageViewport.height
                        sourceComponent: historyPage
                        clip: true
                    }
                }
            }

            MouseArea {
                id: pageWheelArea
                anchors.fill: parent
                acceptedButtons: Qt.NoButton
                z: 4

                onWheel: function(wheel) {
                    const delta = wheel.angleDelta.y !== 0
                        ? wheel.angleDelta.y : wheel.pixelDelta.y
                    if (delta === 0) {
                        wheel.accepted = false
                        return
                    }

                    if (!pageWheelGuard.running) {
                        const direction = delta < 0 ? 1 : -1
                        const next = Math.max(0, Math.min(2,
                            root.pageIndex + direction))
                        if (next !== root.pageIndex) {
                            root.pageIndex = next
                            pageWheelGuard.restart()
                        }
                    }
                    wheel.accepted = true
                }
            }

            Timer {
                id: pageWheelGuard
                interval: 240
            }

            Column {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 5
                z: 5

                Repeater {
                    model: 3
                    delegate: Rectangle {
                        required property int index
                        width: 4
                        height: root.pageIndex === index ? 22 : 11
                        radius: 2
                        color: root.pageIndex === index
                            ? K4Theme.ink : K4Theme.panelLineStrong

                        Behavior on height {
                            NumberAnimation { duration: 120 }
                        }

                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -6
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.pageIndex = index
                        }
                    }
                }
            }

            Row {
                visible: root.pageIndex < 2
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.rightMargin: 11
                spacing: 5
                opacity: 0.7
                z: 3

                Text {
                    text: K4Theme.ico.chevronUp
                    rotation: 180
                    color: K4Theme.muted
                    font.family: K4Theme.iconFont
                    font.pixelSize: 11
                    textFormat: Text.PlainText
                }
                LabelText {
                    text: root.pageIndex === 0
                        ? "Scroll for hourly details" : "Scroll for 7-day history"
                }
            }
        }
    }

    Component {
        id: overviewPage

        Item {
            clip: true

            ColumnLayout {
                anchors.fill: parent
                anchors.rightMargin: 10
                spacing: 0

                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 86
                    spacing: 18

                    RowLayout {
                        Layout.preferredWidth: 320
                        Layout.fillHeight: true
                        spacing: 13

                        WeatherGlyph {
                            text: K4Weather.icon(K4Weather.current.wCode)
                            font.pixelSize: 50
                            Layout.preferredWidth: 58
                            Layout.fillHeight: true
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0

                            Text {
                                text: K4Weather.current.temp || "--"
                                color: K4Theme.ink
                                font.family: K4Theme.uiFont
                                font.pixelSize: 40
                                font.weight: Font.Light
                                textFormat: Text.PlainText
                            }
                            ValueText {
                                text: K4Weather.current.wDesc || "No weather data"
                                font.pixelSize: 13
                            }
                            MetaText {
                                text: `Feels like ${K4Weather.current.tempFeelsLike || "--"}`
                            }
                            LabelText {
                                text: K4Weather.daily.length > 0
                                    ? `${K4Weather.daily[0].max} high · ${K4Weather.daily[0].min} low`
                                    : ""
                            }
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        Layout.maximumWidth: 340
                        text: K4Weather.summary
                        color: K4Theme.ink
                        font.family: K4Theme.uiFont
                        font.pixelSize: 15
                        font.weight: Font.Medium
                        lineHeight: 1.2
                        wrapMode: Text.WordWrap
                        textFormat: Text.PlainText
                    }
                }

                Hairline { Layout.fillWidth: true }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 58
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
                                spacing: 1

                                LabelText {
                                    text: root.factLabel(index).toUpperCase()
                                    font.letterSpacing: 0.2
                                }
                                ValueText { text: root.factValue(index) }
                                MetaText { text: root.factNote(index) }
                            }

                            Rectangle {
                                visible: index < 5
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                anchors.topMargin: 8
                                anchors.bottomMargin: 8
                                width: 1
                                color: K4Theme.panelLineStrong
                                opacity: 0.7
                            }
                        }
                    }
                }

                Hairline { Layout.fillWidth: true }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 22
                    ValueText { text: "Today"; font.pixelSize: 12 }
                    Item { Layout.fillWidth: true }
                    LabelText { text: "temperature · rain chance" }
                }

                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 84

                    WeatherLineChart {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        anchors.topMargin: 20
                        anchors.bottomMargin: 25
                        values: root.hourlyValues("tempValue")
                        minimum: root.hourlyTempMin()
                        maximum: root.hourlyTempMax()
                        lineColor: "#67d8ff"
                    }

                    Row {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        height: 18

                        Repeater {
                            model: K4Weather.hourly.length
                            delegate: ValueText {
                                required property int index
                                width: parent.width / Math.max(1, K4Weather.hourly.length)
                                text: K4Weather.hourly[index].temp || "--"
                                font.pixelSize: 11
                                horizontalAlignment: Text.AlignHCenter
                            }
                        }
                    }

                    Row {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        height: 24

                        Repeater {
                            model: K4Weather.hourly.length
                            delegate: Column {
                                required property int index
                                width: parent.width / Math.max(1, K4Weather.hourly.length)
                                spacing: 0

                                Text {
                                    width: parent.width
                                    text: `${K4Weather.hourly[index].rain}%`
                                    color: "#67d8ff"
                                    font.family: K4Theme.uiFont
                                    font.pixelSize: 11
                                    font.weight: Font.Medium
                                    horizontalAlignment: Text.AlignHCenter
                                    textFormat: Text.PlainText
                                }
                                LabelText {
                                    width: parent.width
                                    text: K4Weather.hourly[index].hour || ""
                                    horizontalAlignment: Text.AlignHCenter
                                }
                            }
                        }
                    }

                    MetaText {
                        anchors.centerIn: parent
                        visible: K4Weather.hourly.length === 0
                        text: K4Weather.loading
                            ? "Loading hourly forecast…" : "Hourly forecast unavailable"
                        font.pixelSize: 12
                    }
                }

                Hairline { Layout.fillWidth: true }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 22
                    ValueText { text: "Next 3 days"; font.pixelSize: 12 }
                    Item { Layout.fillWidth: true }
                    LabelText { text: "rain · high / low" }
                }

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true

                    Column {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top

                        Repeater {
                            model: Math.min(3, K4Weather.daily.length)
                            delegate: Item {
                                required property int index
                                width: parent.width
                                height: 30
                                readonly property var day: K4Weather.daily[index]

                                ValueText {
                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 64
                                    text: index === 0 ? "Today" : day.label
                                    font.pixelSize: 12
                                }

                                WeatherGlyph {
                                    anchors.left: parent.left
                                    anchors.leftMargin: 67
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 25
                                    text: K4Weather.icon(day.code)
                                    font.pixelSize: 18
                                    color: K4Theme.muted
                                }

                                MetaText {
                                    anchors.left: parent.left
                                    anchors.leftMargin: 101
                                    anchors.right: rainText.left
                                    anchors.rightMargin: 10
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: day.description
                                    elide: Text.ElideRight
                                }

                                Text {
                                    id: rainText
                                    anchors.right: tempsText.left
                                    anchors.rightMargin: 18
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 44
                                    text: `${day.rain}%`
                                    color: "#67d8ff"
                                    font.family: K4Theme.uiFont
                                    font.pixelSize: 11
                                    font.weight: Font.Medium
                                    horizontalAlignment: Text.AlignRight
                                    textFormat: Text.PlainText
                                }

                                ValueText {
                                    id: tempsText
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 92
                                    text: `${day.max}   ${day.min}`
                                    font.pixelSize: 12
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

                    MetaText {
                        anchors.centerIn: parent
                        visible: K4Weather.daily.length === 0
                        text: K4Weather.error.length
                            ? K4Weather.error
                            : (K4Weather.loading
                                ? "Loading forecast…" : "Forecast unavailable")
                        font.pixelSize: 12
                    }
                }
            }
        }
    }

    Component {
        id: detailsPage

        Item {
            clip: true

            ColumnLayout {
                anchors.fill: parent
                anchors.rightMargin: 10
                spacing: 0

                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 42

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        ValueText {
                            text: "Hourly details"
                            font.pixelSize: 14
                        }
                        MetaText {
                            text: "Precipitation probability and humidity through today"
                        }
                    }

                    LabelText { text: "local time" }
                }

                Hairline { Layout.fillWidth: true }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 20

                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        ValueText {
                            anchors.left: parent.left
                            anchors.top: parent.top
                            text: "Precipitation chance"
                            font.pixelSize: 13
                        }
                        MetaText {
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.topMargin: 19
                            text: "hourly probability"
                        }
                        ValueText {
                            anchors.right: parent.right
                            anchors.top: parent.top
                            text: `${K4Weather.peakRainChance()}%`
                            font.pixelSize: 14
                        }
                        LabelText {
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.topMargin: 19
                            text: "daily peak"
                        }

                        Item {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.topMargin: 48
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 6

                            Column {
                                anchors.left: parent.left
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: 24
                                width: 34

                                LabelText {
                                    width: parent.width
                                    height: parent.height / 3
                                    text: "100"
                                    horizontalAlignment: Text.AlignRight
                                }
                                LabelText {
                                    width: parent.width
                                    height: parent.height / 3
                                    text: "50"
                                    horizontalAlignment: Text.AlignRight
                                    verticalAlignment: Text.AlignVCenter
                                }
                                LabelText {
                                    width: parent.width
                                    height: parent.height / 3
                                    text: "0%"
                                    horizontalAlignment: Text.AlignRight
                                    verticalAlignment: Text.AlignBottom
                                }
                            }

                            Item {
                                id: precipPlot
                                anchors.left: parent.left
                                anchors.leftMargin: 44
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom

                                Repeater {
                                    model: 3
                                    delegate: Rectangle {
                                        required property int index
                                        x: 0
                                        y: index * (precipPlot.height - 24) / 2
                                        width: precipPlot.width
                                        height: 1
                                        color: K4Theme.panelLineStrong
                                        opacity: 0.8
                                    }
                                }

                                Row {
                                    id: precipBars
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.top: parent.top
                                    anchors.bottom: parent.bottom
                                    anchors.bottomMargin: 24

                                    Repeater {
                                        model: K4Weather.hourly.length
                                        delegate: Item {
                                            required property int index
                                            width: precipBars.width
                                                / Math.max(1, K4Weather.hourly.length)
                                            height: precipBars.height
                                            readonly property real chance:
                                                Number(K4Weather.hourly[index].rain || 0)

                                            Rectangle {
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                anchors.bottom: parent.bottom
                                                width: Math.max(8, parent.width * 0.36)
                                                height: chance > 0
                                                    ? Math.max(3,
                                                        parent.height * chance / 100) : 0
                                                radius: 3
                                                color: "#67d8ff"
                                                opacity: 0.95
                                            }

                                            Text {
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                anchors.bottom: parent.bottom
                                                anchors.bottomMargin: chance > 0
                                                    ? Math.max(13,
                                                        parent.height * chance / 100 + 4)
                                                    : 3
                                                text: chance > 0 ? `${chance}` : ""
                                                color: "#67d8ff"
                                                font.family: K4Theme.uiFont
                                                font.pixelSize: 11
                                                font.weight: Font.Medium
                                                textFormat: Text.PlainText
                                            }
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
                                        delegate: LabelText {
                                            required property int index
                                            width: parent.width
                                                / Math.max(1, K4Weather.hourly.length)
                                            text: K4Weather.hourly[index].hour.substring(0, 2)
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
                        Layout.topMargin: 10
                        Layout.bottomMargin: 10
                        color: K4Theme.panelLineStrong
                        opacity: 0.72
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        ValueText {
                            anchors.left: parent.left
                            anchors.top: parent.top
                            text: "Humidity"
                            font.pixelSize: 13
                        }
                        MetaText {
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.topMargin: 19
                            text: "relative humidity"
                        }
                        ValueText {
                            anchors.right: parent.right
                            anchors.top: parent.top
                            text: K4Weather.current.humidity || "--"
                            font.pixelSize: 14
                        }
                        LabelText {
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.topMargin: 19
                            text: "current"
                        }

                        Item {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.topMargin: 48
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 6

                            Column {
                                anchors.left: parent.left
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: 24
                                width: 34

                                LabelText {
                                    width: parent.width
                                    height: parent.height / 3
                                    text: "100"
                                    horizontalAlignment: Text.AlignRight
                                }
                                LabelText {
                                    width: parent.width
                                    height: parent.height / 3
                                    text: "50"
                                    horizontalAlignment: Text.AlignRight
                                    verticalAlignment: Text.AlignVCenter
                                }
                                LabelText {
                                    width: parent.width
                                    height: parent.height / 3
                                    text: "0%"
                                    horizontalAlignment: Text.AlignRight
                                    verticalAlignment: Text.AlignBottom
                                }
                            }

                            Item {
                                anchors.left: parent.left
                                anchors.leftMargin: 44
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom

                                WeatherLineChart {
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.top: parent.top
                                    anchors.bottom: parent.bottom
                                    anchors.bottomMargin: 24
                                    values: root.hourlyValues("humidity")
                                    minimum: 0
                                    maximum: 100
                                    lineColor: "#c0b4ff"
                                }

                                Row {
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.bottom: parent.bottom
                                    height: 20

                                    Repeater {
                                        model: K4Weather.hourly.length
                                        delegate: LabelText {
                                            required property int index
                                            width: parent.width
                                                / Math.max(1, K4Weather.hourly.length)
                                            text: K4Weather.hourly[index].hour.substring(0, 2)
                                            horizontalAlignment: Text.AlignHCenter
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Component {
        id: historyPage

        Item {
            clip: true

            ColumnLayout {
                anchors.fill: parent
                anchors.rightMargin: 10
                spacing: 0

                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 42

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        ValueText {
                            text: "7-day history"
                            font.pixelSize: 14
                        }
                        MetaText {
                            text: "Daily temperature range, precipitation and mean humidity"
                        }
                    }

                    LabelText {
                        text: `${root.tempValueText(root.historyMinimum())} – ${root.tempValueText(root.historyMaximum())}`
                    }
                }

                Hairline { Layout.fillWidth: true }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 32

                    ValueText {
                        Layout.preferredWidth: 82
                        text: "Day"
                        font.pixelSize: 11
                    }
                    LabelText {
                        Layout.fillWidth: true
                        text: "temperature range"
                    }
                    LabelText {
                        Layout.preferredWidth: 72
                        text: "rain"
                        horizontalAlignment: Text.AlignRight
                    }
                    LabelText {
                        Layout.preferredWidth: 74
                        text: "humidity"
                        horizontalAlignment: Text.AlignRight
                    }
                }

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true

                    Column {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top

                        Repeater {
                            model: K4Weather.history.length
                            delegate: Item {
                                required property int index
                                width: parent.width
                                height: 36
                                readonly property var day: K4Weather.history[index]

                                ValueText {
                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 82
                                    text: day.label
                                    font.pixelSize: 12
                                }

                                Item {
                                    id: rangeCell
                                    anchors.left: parent.left
                                    anchors.leftMargin: 92
                                    anchors.right: rainHistory.left
                                    anchors.rightMargin: 16
                                    anchors.top: parent.top
                                    anchors.bottom: parent.bottom

                                    MetaText {
                                        anchors.left: parent.left
                                        anchors.top: parent.top
                                        anchors.topMargin: 2
                                        text: `${root.tempValueText(day.minValue)} → ${root.tempValueText(day.maxValue)}`
                                    }

                                    Rectangle {
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.top: parent.top
                                        anchors.topMargin: 25
                                        height: 1
                                        color: K4Theme.panelLineStrong
                                        opacity: 0.85
                                    }

                                    Rectangle {
                                        id: rangeBand
                                        x: rangeCell.width
                                            * root.historyFraction(day.minValue)
                                        y: 21
                                        width: Math.max(7, rangeCell.width
                                            * (root.historyFraction(day.maxValue)
                                                - root.historyFraction(day.minValue)))
                                        height: 8
                                        radius: 4
                                        gradient: Gradient {
                                            orientation: Gradient.Horizontal
                                            GradientStop {
                                                position: 0
                                                color: "#67d8ff"
                                            }
                                            GradientStop {
                                                position: 1
                                                color: "#ffd37a"
                                            }
                                        }
                                    }

                                    Rectangle {
                                        x: rangeBand.x - 3
                                        y: 21
                                        width: 8
                                        height: 8
                                        radius: 4
                                        color: K4Theme.islandBg
                                        border.width: 2
                                        border.color: "#67d8ff"
                                    }
                                    Rectangle {
                                        x: rangeBand.x + rangeBand.width - 5
                                        y: 21
                                        width: 8
                                        height: 8
                                        radius: 4
                                        color: K4Theme.islandBg
                                        border.width: 2
                                        border.color: "#ffd37a"
                                    }
                                }

                                MetaText {
                                    id: rainHistory
                                    anchors.right: humidityHistory.left
                                    anchors.rightMargin: 16
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 72
                                    text: root.precipText(day.precip)
                                    font.pixelSize: 12
                                    horizontalAlignment: Text.AlignRight
                                }

                                MetaText {
                                    id: humidityHistory
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 74
                                    text: `${Math.round(Number(day.humidity || 0))}%`
                                    font.pixelSize: 12
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

                    MetaText {
                        anchors.centerIn: parent
                        visible: K4Weather.history.length === 0
                        text: K4Weather.historyError.length
                            ? K4Weather.historyError
                            : (K4Weather.historyLoading
                                ? "Loading 7-day history…"
                                : "7-day history unavailable")
                        font.pixelSize: 12
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 28

                    Item { Layout.preferredWidth: 92 }
                    LabelText {
                        Layout.fillWidth: true
                        text: `${root.tempValueText(root.historyMinimum())}                  ${root.tempValueText((root.historyMinimum() + root.historyMaximum()) / 2)}                  ${root.tempValueText(root.historyMaximum())}`
                        horizontalAlignment: Text.AlignHCenter
                    }
                    Item { Layout.preferredWidth: 162 }
                }
            }
        }
    }
}
