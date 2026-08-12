import QtQuick
import qs.services
import qs.modules.common

QtObject {
    id: root

    readonly property bool laptopEnabled: Config.options.background.widgets.battery?.showLaptopBattery ?? true
    readonly property bool bluetoothEnabled: Config.options.background.widgets.battery?.showBluetoothBatteries ?? true
    readonly property bool appleEnabled: Config.options.background.widgets.battery?.showAppleBatteries ?? false

    function appleIcon(deviceClass) {
        switch (String(deviceClass ?? "").toLowerCase()) {
        case "iphone": return "smartphone";
        case "ipad": return "tablet_mac";
        case "watch": return "watch";
        case "mac": return "laptop_mac";
        case "airpods": return "headphones";
        default: return "devices";
        }
    }

    readonly property var devices: {
        const result = [];

        if (root.laptopEnabled && Battery.available) {
            result.push({
                id: "laptop",
                source: "laptop",
                name: Translation.tr("Laptop"),
                icon: "laptop",
                percentage: Math.max(0, Math.min(1, Battery.percentage)),
                charging: Battery.isCharging,
                chargingKnown: true,
                observedAt: Date.now()
            });
        }

        if (root.bluetoothEnabled) {
            const connected = BluetoothStatus.connectedDevices;
            for (let i = 0; i < connected.length; ++i) {
                const device = connected[i];
                if (!device.batteryAvailable)
                    continue;

                result.push({
                    id: `bluetooth:${device.address}`,
                    source: "bluetooth",
                    name: device.name || Translation.tr("Bluetooth device"),
                    icon: Icons.getBluetoothDeviceMaterialSymbol(device.icon || ""),
                    percentage: Math.max(0, Math.min(1, device.battery)),
                    charging: false,
                    chargingKnown: false,
                    observedAt: Date.now()
                });
            }
        }

        if (root.appleEnabled && AppleBatteryStatus.state === "connected") {
            const appleDevices = AppleBatteryStatus.devices;
            for (let i = 0; i < appleDevices.length; ++i) {
                const device = appleDevices[i];
                result.push({
                    id: device.id,
                    source: "icloud",
                    name: device.name || Translation.tr("Apple device"),
                    icon: root.appleIcon(device.deviceClass),
                    percentage: Math.max(0, Math.min(1, Number(device.percentage ?? 0))),
                    charging: device.charging ?? false,
                    chargingKnown: device.chargingKnown ?? false,
                    observedAt: device.observedAt ?? AppleBatteryStatus.lastRefresh
                });
            }
        }

        return result;
    }
}
