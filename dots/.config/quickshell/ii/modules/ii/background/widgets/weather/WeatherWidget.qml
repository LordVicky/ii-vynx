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
        contentPadding: root.layoutMode === "card"
            ? DesktopWidgetMetrics.padding.standard
            : DesktopWidgetMetrics.padding.compact

        onRequestScale: v => root.dragScale = v
        onCommitScale: v => {
            Config.options.background.widgets.weather.scale = v;
            root.dragScale = -1;
        }

        Loader {
            anchors.fill: parent
            active: root.layoutMode === "card"
            sourceComponent: cardLayout
        }

        Loader {
            anchors.fill: parent
            active: root.layoutMode === "compact"
            sourceComponent: compactLayout
        }

        Loader {
            anchors.fill: parent
            active: root.layoutMode === "temperature"
            sourceComponent: temperatureLayout
        }
    }

    // Full 276x252 card: preserve the existing information-rich layout exactly,
    // including the three near-term forecast slots.
    Component {
        id: cardLayout

        ColumnLayout {
            spacing: card.scaled(DesktopWidgetMetrics.spacing.compact)

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: card.scaled(98)
                spacing: card.scaled(DesktopWidgetMetrics.spacing.roomy)

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: card.scaled(DesktopWidgetMetrics.spacing.tight)

                    RowLayout {
                        spacing: card.scaled(DesktopWidgetMetrics.spacing.tight)

                        TransformSafeText {
                            text: root.currentTemperatureNumber()
                            basePixelSize: DesktopWidgetMetrics.typography.heading * 2
                            scaleFactor: root.widgetScale
                            requestedWeight: Font.Medium
                            color: Appearance.colors.colOnLayer0
                        }

                        TransformSafeText {
                            Layout.alignment: Qt.AlignBottom
                            Layout.bottomMargin: card.scaled(7)
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
                        Layout.fillWidth: true
                        spacing: card.scaled(DesktopWidgetMetrics.spacing.tight)

                        TransformSafeSymbol {
                            text: "location_on"
                            baseIconSize: DesktopWidgetMetrics.glyph.caption
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

                Item {
                    Layout.preferredWidth: card.scaled(DesktopWidgetMetrics.height.compactBar)
                    Layout.preferredHeight: card.scaled(DesktopWidgetMetrics.height.compactBar)
                    Layout.alignment: Qt.AlignTop

                    MaterialShape {
                        anchors.fill: parent
                        shape: MaterialShape.Shape.Circle
                        color: Appearance.colors.colPrimary

                        TransformSafeSymbol {
                            anchors.centerIn: parent
                            text: root.weatherIcon(Weather.data?.wCode)
                            baseIconSize: DesktopWidgetMetrics.glyph.standardAction * 2
                            scaleFactor: root.widgetScale
                            color: Appearance.colors.colOnPrimary
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: card.scaled(DesktopWidgetMetrics.control.prominent)
                spacing: card.scaled(DesktopWidgetMetrics.spacing.compact)

                Repeater {
                    model: root.hourlySlots

                    delegate: Rectangle {
                        required property var modelData

                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: card.scaled(Appearance.rounding.normal)
                        color: Appearance.colors.colPrimaryContainer

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: card.scaled(DesktopWidgetMetrics.spacing.compact)
                            spacing: card.scaled(DesktopWidgetMetrics.spacing.tight)

                            TransformSafeText {
                                Layout.fillWidth: true
                                text: root.formatForecastHour(modelData.time)
                                basePixelSize: DesktopWidgetMetrics.typography.caption
                                scaleFactor: root.widgetScale
                                requestedWeight: Font.Medium
                                color: Appearance.colors.colOnPrimaryContainer
                                horizontalAlignment: Text.AlignHCenter
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                spacing: card.scaled(DesktopWidgetMetrics.spacing.tight)

                                Item { Layout.fillWidth: true }

                                TransformSafeSymbol {
                                    text: modelData.placeholder
                                        ? (root.forecastLoading ? "progress_activity" : "cloud")
                                        : root.weatherIcon(modelData.code)
                                    baseIconSize: DesktopWidgetMetrics.glyph.compactAction
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

                                Item { Layout.fillWidth: true }
                            }
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: card.scaled(1)
                color: Appearance.colors.colOutlineVariant
                opacity: 0.35
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: card.scaled(DesktopWidgetMetrics.spacing.standard)

                MetricCell {
                    glyph: "humidity_percentage"
                    label: Translation.tr("Humidity")
                    value: Weather.data?.humidity || "--%"
                }

                MetricCell {
                    glyph: "air"
                    label: Translation.tr("Wind")
                    value: Weather.data?.wind || "--"
                }

                MetricCell {
                    glyph: "wb_sunny"
                    label: Translation.tr("UV Index")
                    value: `${Weather.data?.uv ?? 0} ${root.uvDescription(Weather.data?.uv)}`
                }
            }
        }
    }

    // Compact 240x184 card: faithful to the selected mockup. Location stays in
    // the small top row, the temperature/round weather accent dominate the hero,
    // and the recessed bottom tray carries only humidity, wind, and UV.
    Component {
        id: compactLayout

        ColumnLayout {
            spacing: card.scaled(DesktopWidgetMetrics.spacing.tight)

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: card.scaled(18)
                spacing: card.scaled(DesktopWidgetMetrics.spacing.tight)

                TransformSafeSymbol {
                    text: "location_on"
                    baseIconSize: DesktopWidgetMetrics.glyph.caption
                    scaleFactor: root.widgetScale
                    color: root.adaptiveSubtextColor
                }

                TransformSafeText {
                    Layout.fillWidth: true
                    text: Weather.data?.city || Translation.tr("Locating…")
                    basePixelSize: DesktopWidgetMetrics.typography.supporting
                    scaleFactor: root.widgetScale
                    requestedWeight: Font.Medium
                    color: Appearance.colors.colOnLayer0
                    elide: Text.ElideRight
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: card.scaled(92)
                spacing: card.scaled(DesktopWidgetMetrics.spacing.standard)

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
                            Layout.bottomMargin: card.scaled(6)
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
                }

                Item {
                    Layout.preferredWidth: card.scaled(64)
                    Layout.preferredHeight: card.scaled(64)
                    Layout.alignment: Qt.AlignVCenter

                    MaterialShape {
                        anchors.fill: parent
                        shape: MaterialShape.Shape.Circle
                        color: Appearance.colors.colPrimary

                        TransformSafeSymbol {
                            anchors.centerIn: parent
                            text: root.weatherIcon(Weather.data?.wCode)
                            baseIconSize: DesktopWidgetMetrics.glyph.prominentAction
                            scaleFactor: root.widgetScale
                            color: Appearance.colors.colOnPrimary
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumHeight: card.scaled(48)
                radius: card.scaled(Appearance.rounding.normal)
                color: Appearance.colors.colSurfaceContainerLow

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: card.scaled(DesktopWidgetMetrics.spacing.compact)
                    spacing: card.scaled(DesktopWidgetMetrics.spacing.compact)

                    CompactMetricCell {
                        glyph: "humidity_percentage"
                        label: Translation.tr("Humidity")
                        value: Weather.data?.humidity || "--%"
                    }

                    CompactMetricCell {
                        glyph: "air"
                        label: Translation.tr("Wind")
                        value: Weather.data?.wind || "--"
                    }

                    CompactMetricCell {
                        glyph: "wb_sunny"
                        label: Translation.tr("UV Index")
                        value: `${Weather.data?.uv ?? 0} ${root.uvDescription(Weather.data?.uv)}`
                    }
                }
            }
        }
    }

    // Temperature 132x120 card: exactly one ResourcesWidget stat-card footprint.
    // It intentionally carries only the current temperature and the circular
    // weather accent from the selected mockup.
    Component {
        id: temperatureLayout

        Item {
            Item {
                width: card.scaled(40)
                height: width
                anchors {
                    top: parent.top
                    right: parent.right
                }

                MaterialShape {
                    anchors.fill: parent
                    shape: MaterialShape.Shape.Circle
                    color: Appearance.colors.colPrimary

                    TransformSafeSymbol {
                        anchors.centerIn: parent
                        text: root.weatherIcon(Weather.data?.wCode)
                        baseIconSize: DesktopWidgetMetrics.glyph.standardAction
                        scaleFactor: root.widgetScale
                        color: Appearance.colors.colOnPrimary
                    }
                }
            }

            RowLayout {
                anchors {
                    left: parent.left
                    bottom: parent.bottom
                    bottomMargin: card.scaled(3)
                }
                spacing: card.scaled(DesktopWidgetMetrics.spacing.compact)

                TransformSafeText {
                    text: root.currentTemperatureNumber()
                    basePixelSize: 42
                    scaleFactor: root.widgetScale
                    requestedWeight: Font.Medium
                    color: Appearance.colors.colOnLayer0
                }

                TransformSafeText {
                    Layout.alignment: Qt.AlignBottom
                    Layout.bottomMargin: card.scaled(7)
                    text: root.currentTemperatureUnit()
                    basePixelSize: DesktopWidgetMetrics.typography.heading
                    scaleFactor: root.widgetScale
                    requestedWeight: Font.Medium
                    color: Appearance.colors.colOnLayer0
                }
            }
        }
    }

    // Hover-only card-type switch, matching OpenRGB. It is absent while locked
    // and does not consume permanent visual chrome in either presentation.
    Rectangle {
        id: layoutToggle
        width: card.scaled(16)
        height: width
        radius: card.scaled(4)
        z: 100
        x: root.layoutMode === "temperature"
            ? card.scaled(6)
            : card.animatedWidth - width - card.scaled(6)
        y: card.scaled(6)
        color: Appearance.colors.colOnPrimaryContainer
        opacity: (root.containsMouse || layoutToggleArea.containsMouse) ? 0.5 : 0
        visible: opacity > 0 && !Config.options.background.widgetsLocked

        Behavior on opacity { NumberAnimation { duration: 150 } }

        TransformSafeSymbol {
            anchors.centerIn: parent
            text: root.layoutMode === "card"
                ? "view_compact"
                : (root.layoutMode === "compact" ? "crop_square" : "dashboard")
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

    component MetricCell: RowLayout {
        id: metricCell

        property string glyph
        property string label
        property string value

        Layout.fillWidth: true
        Layout.preferredWidth: 1
        spacing: card.scaled(DesktopWidgetMetrics.spacing.tight)

        TransformSafeSymbol {
            text: metricCell.glyph
            baseIconSize: DesktopWidgetMetrics.glyph.compactAction
            scaleFactor: root.widgetScale
            color: root.adaptiveSubtextColor
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: -card.scaled(DesktopWidgetMetrics.spacing.tight)

            TransformSafeText {
                Layout.fillWidth: true
                text: metricCell.label
                basePixelSize: DesktopWidgetMetrics.typography.caption
                scaleFactor: root.widgetScale
                color: root.adaptiveSubtextColor
                elide: Text.ElideRight
            }

            TransformSafeText {
                Layout.fillWidth: true
                text: metricCell.value
                basePixelSize: DesktopWidgetMetrics.typography.supporting
                scaleFactor: root.widgetScale
                requestedWeight: Font.Medium
                color: Appearance.colors.colOnLayer0
                elide: Text.ElideRight
            }
        }
    }

    component CompactMetricCell: RowLayout {
        id: compactMetricCell

        property string glyph
        property string label
        property string value

        Layout.fillWidth: true
        Layout.preferredWidth: 1
        spacing: card.scaled(DesktopWidgetMetrics.spacing.tight)

        TransformSafeSymbol {
            text: compactMetricCell.glyph
            baseIconSize: DesktopWidgetMetrics.glyph.caption
            scaleFactor: root.widgetScale
            color: root.adaptiveSubtextColor
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: -card.scaled(DesktopWidgetMetrics.spacing.tight)

            TransformSafeText {
                Layout.fillWidth: true
                text: compactMetricCell.label
                basePixelSize: DesktopWidgetMetrics.typography.caption
                scaleFactor: root.widgetScale
                color: root.adaptiveSubtextColor
                elide: Text.ElideRight
            }

            TransformSafeText {
                Layout.fillWidth: true
                text: compactMetricCell.value
                basePixelSize: DesktopWidgetMetrics.typography.supporting
                scaleFactor: root.widgetScale
                requestedWeight: Font.Medium
                color: Appearance.colors.colOnLayer0
                elide: Text.ElideRight
            }
        }
    }
}
