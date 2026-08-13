pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.modules.common

Singleton {
    id: root

    property bool ready: false

    function ensure(path, value) {
        const keys = path.split(".");
        let current = Config.options;
        for (let i = 0; i < keys.length; ++i) {
            if (current?.[keys[i]] === undefined) {
                Config.setNestedValue(path, value);
                return;
            }
            current = current[keys[i]];
        }
    }

    Component.onCompleted: {
        // PR #3 added the Battery widget files without landing its stacked
        // config schema. Seed only missing values so existing user settings
        // always win. This shim is temporary until the stacked config lands.
        root.ensure("background.widgets.battery.enable", true);
        root.ensure("background.widgets.battery.placementStrategy", "free");
        root.ensure("background.widgets.battery.x", 100);
        root.ensure("background.widgets.battery.y", 400);
        root.ensure("background.widgets.battery.scale", 1);
        root.ensure("background.widgets.battery.layout", "list");
        root.ensure("background.widgets.battery.showLaptopBattery", true);
        root.ensure("background.widgets.battery.showBluetoothBatteries", true);
        root.ensure("background.widgets.battery.showAppleBatteries", true);
        root.ready = true;
    }
}
