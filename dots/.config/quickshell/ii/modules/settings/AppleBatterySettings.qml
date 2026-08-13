import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets

ContentSection {
    id: root

    icon: "devices"
    title: Translation.tr("Apple devices")

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
        title: Translation.tr("Battery polling")

        ConfigSpinBox {
            icon: "schedule"
            text: Translation.tr("Polling interval (minutes)")
            value: AppleBatteryStatus.pollingMinutes
            from: 5
            to: 180
            stepSize: 5
            onValueChanged: {
                if (value !== AppleBatteryStatus.pollingMinutes)
                    AppleBatteryStatus.setPollingMinutes(value);
            }
        }

        StyledText {
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            text: Translation.tr("15 minutes is recommended. Shorter intervals update faster but cause more Apple requests and wakeups. Clicking the Battery desktop widget also performs an immediate refresh.")
            color: Appearance.colors.colSubtext
            font.pixelSize: Appearance.font.pixelSize.smaller
        }
    }
}
