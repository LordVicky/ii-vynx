import QtQuick
import qs.services
import qs.modules.common

QtObject {
    id: root

    readonly property bool laptopEnabled: Config.options.background.widgets.battery?.showLaptopBattery ?? true
    readonly property bool bluetoothEnabled: Config.options.background.widgets.battery?.showBluetoothBatteries ?? true

    function appleIcon(deviceClass) {
        const kind = String(deviceClass ?? "").toLowerCase();
        if (kind === "iphone" || kind.startsWith("iphone"))
            return "smartphone";
        if (kind === "ipad" || kind.startsWith("ipad"))
            return "tablet_mac";
        if (kind === "watch" || kind.startsWith("watch"))
            return "watch";
        if (kind === "mac" || kind.startsWith("macbook") || kind.startsWith("imac") || kind.startsWith("macmini") || kind.startsWith("macpro"))
            return "laptop_mac";
        if (kind === "airpods" || kind.startsWith("airpods"))
            return "headphones";
        return "devices";
    }

    readonly property var devices: {
        // lastAttempt is intentionally referenced so stale/expired remote
        // snapshots are recalculated after every low-frequency Apple poll.
        const appleClock = AppleBatteryStatus.lastAttempt;
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
                observedAt: Date.now(),
                stale: false
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
                    observedAt: Date.now(),
                    stale: false
                });
            }
        }

        const appleDevices = AppleBatteryStatus.devices;
        for (let i = 0; i < appleDevices.length; ++i) {
            const device = appleDevices[i];
            if (AppleBatteryStatus.isExpired(device))
                continue;

            result.push({
                id: device.id,
                source: "icloud",
                name: device.name || Translation.tr("Apple device"),
                icon: root.appleIcon(device.deviceClass),
                percentage: Math.max(0, Math.min(1, Number(device.percentage ?? 0))),
                charging: device.charging ?? false,
                chargingKnown: device.chargingKnown ?? false,
                observedAt: device.observedAt ?? AppleBatteryStatus.lastRefresh,
                stale: AppleBatteryStatus.isStale(device)
            });
        }

        return result;
    }
}
