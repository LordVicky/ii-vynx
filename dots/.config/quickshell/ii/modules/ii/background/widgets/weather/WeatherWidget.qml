import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.ii.background.widgets

AbstractBackgroundWidget {
    id: root

    configEntryName: "weather"
    hoverEnabled: true

    // Authored presentation types follow the same persisted layout model used
    // by OpenRGB/Media. Card, compact, and temperature are separate component
    // trees while weather state stays at the widget root.
    readonly property var layoutOrder: ["card", "compact", "temperature"]
    readonly property string layoutMode: {
        const mode = root.configEntry.layout ?? "card";
        return root.layoutOrder.indexOf(mode) >= 0 ? mode : "card";
    }

    function cycleLayout() {
        const index = root.layoutOrder.indexOf(root.layoutMode);
        root.configEntry.layout = root.layoutOrder[(index + 1) % root.layoutOrder.length];
    }

    property real dragScale: -1
    readonly property real widgetScale: dragScale >= 0
        ? dragScale
        : (Config.options.background.widgets.weather.scale ?? 1)

    readonly property real widgetWidth: root.layoutMode === "temperature"
        ? 132
        : (root.layoutMode === "compact" ? 240 : 276)
    readonly property real widgetHeight: root.layoutMode === "temperature"
        ? 120
        : (root.layoutMode === "compact" ? 184 : 252)

    implicitWidth: card.implicitWidth
    implicitHeight: card.implicitHeight

    property var hourlyData: []
    property bool forecastLoading: false
    property bool forecastRefreshQueued: false

    readonly property var upcomingHours: root.nextHourlyEntries(root.hourlyData, 3)
    readonly property var hourlySlots: root.padHourlyEntries(root.upcomingHours, 3)

    function currentTemperatureNumber() {
        const value = String(Weather.data?.temp ?? "");
        const match = value.match(/-?\d+(?:\.\d+)?/);
        return match ? `${match[0]}°` : "--°";
    }

    function currentTemperatureUnit() {
        const value = String(Weather.data?.temp ?? "").toUpperCase();
        if (value.includes("F")) return "F";
        if (value.includes("C")) return "C";
        return "";
    }

    function weatherIcon(code) {
        return Icons.getWeatherIcon(code) ?? "cloud";
    }

    function uvDescription(value) {
        const uv = Number(value ?? 0);
        if (uv >= 11) return Translation.tr("Extreme");
        if (uv >= 8) return Translation.tr("Very high");
        if (uv >= 6) return Translation.tr("High");
        if (uv >= 3) return Translation.tr("Moderate");
        return Translation.tr("Low");
    }

    function forecastTarget() {
        if (Weather.gpsActive && Weather.location?.valid)
            return `${Weather.location.lat},${Weather.location.long ?? Weather.location.lon}`;

        const configuredCity = String(Config.options.bar.weather.city ?? "").trim();
        if (configuredCity.length > 0)
            return configuredCity;

        const resolvedCity = String(Weather.data?.city ?? "").trim();
        if (resolvedCity.length > 0 && resolvedCity !== "City")
            return resolvedCity;

        return "auto";
    }

    function requestForecastRefresh() {
        // Only the full card renders hourly data, so compact/temperature modes do
        // not perform the extra forecast request.
        if (root.layoutMode !== "card")
            return;
        forecastRefreshTimer.restart();
    }

    function fetchForecast() {
        if (root.layoutMode !== "card")
            return;

        if (forecastFetcher.running) {
            root.forecastRefreshQueued = true;
            return;
        }

        const target = encodeURIComponent(root.forecastTarget());
        root.forecastLoading = true;
        forecastFetcher.command = [
            "bash",
            "-c",
            `curl -fsS --max-time 10 "https://wttr.in/${target}?format=j1"`
        ];
        forecastFetcher.running = true;
    }

    function nextHourlyEntries(entries, count) {
        if (!entries || entries.length === 0)
            return [];

        const currentHour = new Date().getHours();
        const currentSlot = Math.floor(currentHour / 3) * 3;
        const result = [];
        let previousHour = -1;
        let passedMidnight = false;

        for (let i = 0; i < entries.length; ++i) {
            const item = entries[i];
            const itemHour = Math.floor(parseInt(item.time ?? "0") / 100);

            if (previousHour >= 0 && itemHour < previousHour)
                passedMidnight = true;
            previousHour = itemHour;

            if (passedMidnight || itemHour >= currentSlot)
                result.push(item);

            if (result.length >= count)
                break;
        }

        return result;
    }

    function padHourlyEntries(entries, count) {
        const result = entries ? entries.slice(0, count) : [];
        while (result.length < count) {
            result.push({
                time: "0",
                tempC: "--",
                tempF: "--",
                code: "119",
                placeholder: true
            });
        }
        return result;
    }

    function formatForecastHour(timeString) {
        if (!timeString || timeString === "0")
            return "--:--";

        const hour = Math.floor(parseInt(timeString) / 100);
        const time = new Date();
        time.setHours(hour, 0, 0, 0);
        return Qt.formatTime(time, Config.options?.time?.format ?? "hh:mm");
    }

    function forecastTemperature(entry) {
        if (!entry || entry.placeholder)
            return "--°";
        const value = Weather.useUSCS ? entry.tempF : entry.tempC;
        return `${value ?? "--"}°`;
    }

    Component.onCompleted: root.requestForecastRefresh()

    onLayoutModeChanged: {
        if (root.layoutMode === "card")
            root.requestForecastRefresh();
    }

    Connections {
        target: Weather

        function onDataChanged() {
            root.requestForecastRefresh();
        }
    }

    Timer {
        id: forecastRefreshTimer
        interval: 250
        repeat: false
        onTriggered: root.fetchForecast()
    }

    Process {
        id: forecastFetcher

        command: ["bash", "-c", ""]

        stdout: StdioCollector {
            onStreamFinished: {
                root.forecastLoading = false;

                if (text.length > 0) {
                    try {
                        const parsed = JSON.parse(text);
                        const days = parsed?.weather ?? [];
                        const flattened = [];

                        for (let dayIndex = 0; dayIndex < Math.min(days.length, 2); ++dayIndex) {
                            const hourly = days[dayIndex]?.hourly ?? [];
                            for (let hourIndex = 0; hourIndex < hourly.length; ++hourIndex) {
                                const item = hourly[hourIndex];
                                flattened.push({
                                    time: item?.time ?? "0",
                                    tempC: item?.tempC ?? "--",
                                    tempF: item?.tempF ?? "--",
                                    code: item?.weatherCode ?? "119",
                                    placeholder: false
                                });
                            }
                        }

                        root.hourlyData = flattened;
                    } catch (error) {
                        console.error(`[WeatherWidget] Forecast parse error: ${error.message}`);
                    }
                }

                if (root.forecastRefreshQueued) {
                    root.forecastRefreshQueued = false;
                    root.requestForecastRefresh();
                }
            }
        }
    }

    BackgroundWidgetCard {
        id: card

        host: root
        scaleFactor: root.widgetScale
        baseWidth: root.widgetWidth
        baseHeight: root.widgetHeight
        contentPadding: root.layoutMode === "temperature"
            ? DesktopWidgetMetrics.padding.compact
            : DesktopWidgetMetrics.padding.standard

        onRequestScale: value => root.dragScale = value
        onCommitScale: value => {
            Config.options.background.widgets.weather.scale = value;
            root.dragScale = -1;
        }

        Loader {
            anchors.fill: parent
            sourceComponent: root.layoutMode === "temperature"
                ? temperatureLayout
                : (root.layoutMode === "compact" ? compactLayout : cardLayout)
        }
    }

    Component {
        id: cardLayout

        ColumnLayout {
            spacing: card.scaled(DesktopWidgetMetrics.spacing.standard)

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: card.scaled(104)
                spacing: card.scaled(DesktopWidgetMetrics.spacing.roomy)

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: -card.scaled(DesktopWidgetMetrics.spacing.tight)

                    RowLayout {
                        spacing: card.scaled(DesktopWidgetMetrics.spacing.tight)

                        TransformSafeText {
                            text: root.currentTemperatureNumber()
                            basePixelSize: 42
                            scaleFactor: root.widgetScale
                            requestedWeight: Font.Medium
                            color: Appearance.colors.colOnLayer0
                        }

                        TransformSafeText {
                            Layout.alignment: Qt.AlignBottom
                            Layout.bottomMargin: card.scaled(5)
                            text: root.currentTemperatureUnit()
                            basePixelSize: DesktopWidgetMetrics.typography.heading
                            scaleFactor: root.widgetScale
                            requestedWeight: Font.Medium
                            color: Appearance.colors.colOnLayer0
                        }
                    }

                    TransformSafeText {
                        Layout.fillWidth: true
                        text: Weather.data?.wDesc || Translation.tr("Unavailable")
                        basePixelSize: DesktopWidgetMetrics.typography.actionLabel
                        scaleFactor: root.widgetScale
                        requestedWeight: Font.Medium
                        color: Appearance.colors.colOnLayer0
                        elide: Text.ElideRight
                    }

                    TransformSafeText {
                        Layout.fillWidth: true
                        text: Translation.tr("Feels like %1").arg(Weather.data?.tempFeelsLike || "--°")
                        basePixelSize: DesktopWidgetMetrics.typography.supporting
                        scaleFactor: root.widgetScale
                        color: root.adaptiveSubtextColor
                        elide: Text.ElideRight
                    }

                    RowLayout {
                        Layout.topMargin: card.scaled(DesktopWidgetMetrics.spacing.tight)
                        Layout.fillWidth: true
                        spacing: card.scaled(DesktopWidgetMetrics.spacing.tight)

                        TransformSafeSymbol {
                            text: "location_on"
                            baseIconSize: DesktopWidgetMetrics.glyph.inline
                            scaleFactor: root.widgetScale
                            color: root.adaptiveSubtextColor
                        }

                        TransformSafeText {
                            Layout.fillWidth: true
                            text: Weather.data?.city || Translation.tr("Locating…")
                            basePixelSize: DesktopWidgetMetrics.typography.caption
                            scaleFactor: root.widgetScale
                            color: root.adaptiveSubtextColor
                            elide: Text.ElideRight
                        }
                    }
                }

                MaterialShape {
                    Layout.preferredWidth: card.scaled(72)
                    Layout.preferredHeight: card.scaled(72)
                    shape: MaterialShape.Shape.Circle
                    color: Appearance.colors.colPrimary

                    TransformSafeSymbol {
                        anchors.centerIn: parent
                        text: root.weatherIcon(Weather.data?.wCode)
                        baseIconSize: 38
                        scaleFactor: root.widgetScale
                        color: Appearance.colors.colOnPrimary
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: card.scaled(64)
                spacing: card.scaled(DesktopWidgetMetrics.spacing.standard)

                Repeater {
                    model: root.hourlySlots

                    delegate: Rectangle {
                        required property var modelData

                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: card.scaled(Appearance.rounding.normal)
                        color: Appearance.colors.colPrimaryContainer
                        opacity: modelData.placeholder ? 0.72 : 1

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: card.scaled(8)
                            spacing: 0

                            TransformSafeText {
                                Layout.alignment: Qt.AlignHCenter
                                text: root.formatForecastHour(modelData.time)
                                basePixelSize: DesktopWidgetMetrics.typography.caption
                                scaleFactor: root.widgetScale
                                color: Appearance.colors.colOnPrimaryContainer
                            }

                            RowLayout {
                                Layout.alignment: Qt.AlignHCenter
                                spacing: card.scaled(DesktopWidgetMetrics.spacing.tight)

                                TransformSafeSymbol {
                                    text: root.weatherIcon(modelData.code)
                                    baseIconSize: DesktopWidgetMetrics.glyph.inline
                                    scaleFactor: root.widgetScale
                                    color: Appearance.colors.colOnPrimaryContainer
                                }

                                TransformSafeText {
                                    text: root.forecastTemperature(modelData)
                                    basePixelSize: DesktopWidgetMetrics.typography.body
                                    scaleFactor: root.widgetScale
                                    requestedWeight: Font.DemiBold
                                    color: Appearance.colors.colOnPrimaryContainer
                                }
                            }
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: card.scaled(1)
                color: Appearance.colors.colOutlineVariant
                opacity: 0.45
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: card.scaled(DesktopWidgetMetrics.spacing.tight)

                MetricItem {
                    Layout.fillWidth: true
                    icon: "humidity_percentage"
                    label: Translation.tr("Humidity")
                    value: Weather.data?.humidity ? `${Weather.data.humidity}%` : "--%"
                }

                MetricItem {
                    Layout.fillWidth: true
                    icon: "air"
                    label: Translation.tr("Wind")
                    value: Weather.data?.wind || "--"
                }

                MetricItem {
                    Layout.fillWidth: true
                    icon: "wb_sunny"
                    label: Translation.tr("UV Index")
                    value: `${Weather.data?.uv ?? "--"} ${root.uvDescription(Weather.data?.uv)}`
                }
            }
        }
    }

    Component {
        id: compactLayout

        ColumnLayout {
            spacing: card.scaled(DesktopWidgetMetrics.spacing.standard)

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: card.scaled(DesktopWidgetMetrics.spacing.standard)

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: -card.scaled(DesktopWidgetMetrics.spacing.tight)

                    RowLayout {
                        spacing: card.scaled(DesktopWidgetMetrics.spacing.tight)

                        TransformSafeText {
                            text: root.currentTemperatureNumber()
                            basePixelSize: 38
                            scaleFactor: root.widgetScale
                            requestedWeight: Font.Medium
                            color: Appearance.colors.colOnLayer0
                        }

                        TransformSafeText {
                            Layout.alignment: Qt.AlignBottom
                            Layout.bottomMargin: card.scaled(5)
                            text: root.currentTemperatureUnit()
                            basePixelSize: DesktopWidgetMetrics.typography.heading
                            scaleFactor: root.widgetScale
                            requestedWeight: Font.Medium
                            color: Appearance.colors.colOnLayer0
                        }
                    }

                    TransformSafeText {
                        Layout.fillWidth: true
                        text: Weather.data?.wDesc || Translation.tr("Unavailable")
                        basePixelSize: DesktopWidgetMetrics.typography.actionLabel
                        scaleFactor: root.widgetScale
                        requestedWeight: Font.Medium
                        color: Appearance.colors.colOnLayer0
                        elide: Text.ElideRight
                    }

                    TransformSafeText {
                        Layout.fillWidth: true
                        text: Translation.tr("Feels like %1").arg(Weather.data?.tempFeelsLike || "--°")
                        basePixelSize: DesktopWidgetMetrics.typography.caption
                        scaleFactor: root.widgetScale
                        color: root.adaptiveSubtextColor
                        elide: Text.ElideRight
                    }

                    RowLayout {
                        Layout.topMargin: card.scaled(DesktopWidgetMetrics.spacing.tight)
                        Layout.fillWidth: true
                        spacing: card.scaled(DesktopWidgetMetrics.spacing.tight)

                        TransformSafeSymbol {
                            text: "location_on"
                            baseIconSize: DesktopWidgetMetrics.glyph.inline
                            scaleFactor: root.widgetScale
                            color: root.adaptiveSubtextColor
                        }

                        TransformSafeText {
                            Layout.fillWidth: true
                            text: Weather.data?.city || Translation.tr("Locating…")
                            basePixelSize: DesktopWidgetMetrics.typography.caption
                            scaleFactor: root.widgetScale
                            color: root.adaptiveSubtextColor
                            elide: Text.ElideRight
                        }
                    }
                }

                MaterialShape {
                    Layout.preferredWidth: card.scaled(64)
                    Layout.preferredHeight: card.scaled(64)
                    shape: MaterialShape.Shape.Circle
                    color: Appearance.colors.colPrimary

                    TransformSafeSymbol {
                        anchors.centerIn: parent
                        text: root.weatherIcon(Weather.data?.wCode)
                        baseIconSize: 34
                        scaleFactor: root.widgetScale
                        color: Appearance.colors.colOnPrimary
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: card.scaled(50)
                radius: card.scaled(Appearance.rounding.large)
                color: Appearance.colors.colLayer1

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: card.scaled(10)
                    anchors.rightMargin: card.scaled(10)
                    spacing: card.scaled(DesktopWidgetMetrics.spacing.tight)

                    MetricItem {
                        Layout.fillWidth: true
                        icon: "humidity_percentage"
                        label: Translation.tr("Humidity")
                        value: Weather.data?.humidity ? `${Weather.data.humidity}%` : "--%"
                    }

                    MetricItem {
                        Layout.fillWidth: true
                        icon: "air"
                        label: Translation.tr("Wind")
                        value: Weather.data?.wind || "--"
                    }

                    MetricItem {
                        Layout.fillWidth: true
                        icon: "wb_sunny"
                        label: Translation.tr("UV Index")
                        value: `${Weather.data?.uv ?? "--"} ${root.uvDescription(Weather.data?.uv)}`
                    }
                }
            }
        }
    }

    Component {
        id: temperatureLayout

        Item {
            // Match one ResourcesWidget card exactly: 132 x 120 authored size.
            TransformSafeText {
                anchors.left: parent.left
                anchors.leftMargin: card.scaled(12)
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: card.scaled(9)
                text: root.currentTemperatureNumber()
                basePixelSize: 42
                scaleFactor: root.widgetScale
                requestedWeight: Font.Medium
                color: Appearance.colors.colOnLayer0
            }

            TransformSafeText {
                anchors.left: parent.left
                anchors.leftMargin: card.scaled(83)
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: card.scaled(19)
                text: root.currentTemperatureUnit()
                basePixelSize: DesktopWidgetMetrics.typography.heading
                scaleFactor: root.widgetScale
                requestedWeight: Font.Medium
                color: Appearance.colors.colOnLayer0
            }

            MaterialShape {
                anchors.top: parent.top
                anchors.right: parent.right
                width: card.scaled(44)
                height: card.scaled(44)
                shape: MaterialShape.Shape.Circle
                color: Appearance.colors.colPrimary

                TransformSafeSymbol {
                    anchors.centerIn: parent
                    text: root.weatherIcon(Weather.data?.wCode)
                    baseIconSize: 24
                    scaleFactor: root.widgetScale
                    color: Appearance.colors.colOnPrimary
                }
            }
        }
    }

    component MetricItem: RowLayout {
        required property string icon
        required property string label
        required property string value

        spacing: card.scaled(DesktopWidgetMetrics.spacing.tight)

        TransformSafeSymbol {
            text: icon
            baseIconSize: DesktopWidgetMetrics.glyph.inline
            scaleFactor: root.widgetScale
            color: root.adaptiveSubtextColor
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: -card.scaled(2)

            TransformSafeText {
                Layout.fillWidth: true
                text: label
                basePixelSize: DesktopWidgetMetrics.typography.caption
                scaleFactor: root.widgetScale
                color: root.adaptiveSubtextColor
                elide: Text.ElideRight
            }

            TransformSafeText {
                Layout.fillWidth: true
                text: value
                basePixelSize: DesktopWidgetMetrics.typography.supporting
                scaleFactor: root.widgetScale
                requestedWeight: Font.Medium
                color: Appearance.colors.colOnLayer0
                elide: Text.ElideRight
            }
        }
    }

    // The presentation switch follows the same hover-only editing affordance as
    // OpenRGB/Media. It is independent of BackgroundWidgetCard's resize handle.
    Rectangle {
        z: 20
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: card.scaled(6)
        anchors.rightMargin: card.scaled(root.layoutMode === "temperature" ? 54 : 6)
        width: card.scaled(DesktopWidgetMetrics.control.compact)
        height: width
        radius: card.scaled(Appearance.rounding.full)
        color: layoutMouse.containsMouse
            ? Appearance.colors.colPrimaryContainerHover
            : Appearance.colors.colPrimaryContainer
        opacity: !Config.options.background.widgetsLocked && (root.containsMouse || layoutMouse.containsMouse) ? 1 : 0
        visible: opacity > 0

        Behavior on opacity {
            NumberAnimation { duration: 150 }
        }

        TransformSafeSymbol {
            anchors.centerIn: parent
            text: root.layoutMode === "card"
                ? "view_compact"
                : (root.layoutMode === "compact" ? "thermometer" : "dashboard")
            baseIconSize: DesktopWidgetMetrics.glyph.compactAction
            scaleFactor: root.widgetScale
            color: Appearance.colors.colOnPrimaryContainer
        }

        MouseArea {
            id: layoutMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.cycleLayout()
        }
    }
}
