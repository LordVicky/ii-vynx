pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import qs.services

// K4 system-tray presentation adapter. TrayService/SystemTray remain the sole
// host and item owners; K4 only orders and invokes the same live item objects.
Singleton {
    id: root

    readonly property var sorted: TrayService.pinnedItems.concat(TrayService.unpinnedItems)
    readonly property int count: sorted.length

    function label(item) {
        if (!item) return ""
        if (String(item.tooltipTitle || "").length) return item.tooltipTitle
        if (String(item.title || "").length) return item.title
        return item.id || "Tray item"
    }

    function detail(item) {
        if (!item) return ""
        if (String(item.tooltipDescription || "").length) return item.tooltipDescription
        return item.id || ""
    }

    function statusText(item) {
        if (!item) return ""
        if (item.status === Status.NeedsAttention) return "Needs attention"
        if (item.status === Status.Passive) return "Passive"
        return "Active"
    }

    function primary(item) {
        if (!item || item.onlyMenu) return false
        if (typeof item.activate === "function") item.activate()
        return true
    }

    function secondary(item) {
        if (item && typeof item.secondaryActivate === "function") item.secondaryActivate()
    }

    function scroll(item, delta) {
        if (item && typeof item.scroll === "function") item.scroll(delta, false)
    }

    function togglePin(item) {
        if (item) TrayService.togglePin(item.id)
    }
}
