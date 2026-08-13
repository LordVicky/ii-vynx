import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets

ColumnLayout {
    id: root
    Layout.fillWidth: true
    spacing: 8

    function statusText() {
        if (AppleBatteryStatus.refreshing)
            return Translation.tr("Checking Apple devices…");
        switch (AppleBatteryStatus.state) {
        case "connected":
            return Translation.tr("Connected");
        case "notConfigured":
            return Translation.tr("Not connected");
        case "authenticationRequired":
            return Translation.tr("Sign-in required");
        case "termsRequired":
            return Translation.tr("Apple terms need attention");
        case "dependencyMissing":
            return Translation.tr("pyicloud is not installed");
        case "error":
            return Translation.tr("Connection error");
        case "disabled":
            return Translation.tr("Source disabled");
        default:
            return Translation.tr("Checking…");
        }
    }

    function lastRefreshText() {
        if (!AppleBatteryStatus.lastRefresh)
            return Translation.tr("Never");
        return Qt.formatDateTime(new Date(AppleBatteryStatus.lastRefresh), "yyyy-MM-dd hh:mm");
    }

    ContentSubsection {
        Layout.fillWidth: true
        title: Translation.tr("Apple Account")

        ConfigRow {
            Layout.fillWidth: true

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                StyledText {
                    text: root.statusText()
                    color: Appearance.colors.colOnLayer0
                    font.weight: Font.DemiBold
                }

                StyledText {
                    text: Translation.tr("Last refresh: %1").arg(root.lastRefreshText())
                    color: Appearance.colors.colSubtext
                    font.pixelSize: Appearance.font.pixelSize.smaller
                }
            }

            RippleButtonWithIcon {
                materialIcon: AppleBatteryStatus.state === "connected" ? "passkey" : "login"
                mainText: AppleBatteryStatus.state === "connected"
                    ? Translation.tr("Re-authenticate")
                    : Translation.tr("Connect Apple Account")
                enabled: !AppleBatteryStatus.refreshing && !AppleBatteryStatus.disconnecting
                onClicked: AppleBatteryStatus.openLogin()
            }
        }

        StyledText {
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            text: Translation.tr("Sign-in opens in your configured terminal so your Apple password and verification code never enter Vynx configuration or command-line arguments.")
            color: Appearance.colors.colSubtext
            font.pixelSize: Appearance.font.pixelSize.smaller
        }

        ConfigRow {
            Layout.fillWidth: true

            RippleButtonWithIcon {
                materialIcon: "refresh"
                mainText: AppleBatteryStatus.refreshing
                    ? Translation.tr("Refreshing…")
                    : Translation.tr("Refresh now")
                enabled: !AppleBatteryStatus.refreshing && !AppleBatteryStatus.disconnecting
                onClicked: AppleBatteryStatus.refresh()
            }

            RippleButtonWithIcon {
                materialIcon: "logout"
                mainText: AppleBatteryStatus.disconnecting
                    ? Translation.tr("Disconnecting…")
                    : Translation.tr("Disconnect")
                enabled: AppleBatteryStatus.state !== "notConfigured"
                    && !AppleBatteryStatus.refreshing
                    && !AppleBatteryStatus.disconnecting
                onClicked: AppleBatteryStatus.disconnect()
            }
        }
    }

    ContentSubsection {
        Layout.fillWidth: true
        title: Translation.tr("Battery polling")

        ConfigSpinBox {
            icon: "schedule"
            text: Translation.tr("Polling interval (minutes)")
            value: Config.options.background.widgets.battery.applePollingMinutes
            from: 1
            to: 180
            stepSize: 1
            onValueChanged: Config.options.background.widgets.battery.applePollingMinutes = value
        }

        StyledText {
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            text: Translation.tr("15 minutes is the default. 5–15 minutes is recommended. Clicking the Battery desktop widget also performs an immediate refresh.")
            color: Appearance.colors.colSubtext
            font.pixelSize: Appearance.font.pixelSize.smaller
        }

        StyledText {
            Layout.fillWidth: true
            visible: Config.options.background.widgets.battery.applePollingMinutes < 5
            wrapMode: Text.Wrap
            text: Translation.tr("Frequent polling may increase Apple requests and wakeups without improving Find My freshness.")
            color: Appearance.colors.colError
            font.pixelSize: Appearance.font.pixelSize.smaller
        }
    }
}
