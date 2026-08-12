import QtQuick
import qs.services
import qs.modules.common

QtObject {
    id: root

    readonly property bool laptopEnabled: Config.options.background.widgets.battery.showLaptopBattery
    readonly property bool bluetoothEnabled: Config.options.background.widgets.battery.showBluetoothBatteries

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
                chargingKnown: true
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
                    chargingKnown: false
                });
            }
        }

        return result;
    }
}
