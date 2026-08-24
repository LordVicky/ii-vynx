pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.modules.common
import qs.services

// k4 notification presentation state backed by ii-vynx's existing
// Notifications singleton. This adapter never owns a NotificationServer.
Singleton {
    id: root

    property var latest: null
    property int count: 0
    property bool toastOpen: false
    property bool inBand: false
    property string previousOwner: ""

    readonly property bool presentationActive: Config.options.panelFamily === "ii"
        && Config.options.bar.variant === "k4"
    // Panel is an upstream exception to the explicit-owner band rule: a new
    // notification closes Panel and takes the island, so route it like the
    // passive owners to avoid signal-order races between the two listeners.
    readonly property var passiveToastOwners: ["", "toast", "idle", "clock", "player", "volume", "panel"]
    readonly property var recent: Notifications.list.slice().reverse()
    readonly property var history: recent

    onPresentationActiveChanged: {
        if (!presentationActive)
            dismissToast()
    }

    function stripHeight(max) {
        const n = Math.min(max, recent.length)
        return n === 0 ? 0 : 18 + n * 34 + (n - 1) * 4
    }

    function buttons(notification) {
        if (!notification)
            return []
        const actions = notification.actions ?? []
        return actions.filter(action => action.identifier !== "default")
    }

    function defaultAction(notification) {
        if (!notification)
            return null
        const actions = notification.actions ?? []
        for (let i = 0; i < actions.length; ++i) {
            if (actions[i].identifier === "default")
                return actions[i]
        }
        return null
    }

    function iconFor(notification) {
        if (!notification)
            return ""
        if (notification.image?.length > 0)
            return notification.image
        if (notification.appIcon?.length > 0)
            return Quickshell.iconPath(notification.appIcon, true)
        return ""
    }

    function canInvoke(notification) {
        return notification?.notification !== null
            && notification?.notification !== undefined
    }

    function activate(notification) {
        if (!canInvoke(notification))
            return
        const action = defaultAction(notification)
        if (action)
            Notifications.attemptInvokeAction(notification.notificationId, action.identifier)
    }

    function invokeAction(notification, action) {
        if (!canInvoke(notification) || !action)
            return
        Notifications.attemptInvokeAction(notification.notificationId, action.identifier)
    }

    function dismiss(notification) {
        if (!notification)
            return
        const wasLatest = latest?.notificationId === notification.notificationId
        Notifications.discardNotification(notification.notificationId)
        if (wasLatest)
            dismissToast()
    }

    function clear() {
        Notifications.discardAllNotifications()
        latest = null
        count = 0
        dismissToast()
    }

    function markRead() {
        count = 0
        Notifications.markAllRead()
    }

    // Match focused windows conservatively. Upstream only auto-dismisses on an
    // exact application-class match; fuzzy/title matching is reserved for an
    // explicit notification click because a false positive here destroys data.
    function normalizedClass(value) {
        return String(value ?? "").toLowerCase().replace(/\.desktop$/, "")
    }

    function classesFor(notification) {
        const result = []
        const add = function(value) {
            const normalized = root.normalizedClass(value)
            if (normalized.length > 0 && result.indexOf(normalized) < 0)
                result.push(normalized)
        }

        add(notification?.appName)
        add(notification?.notification?.desktopEntry)

        const appName = root.normalizedClass(notification?.appName)
        const desktopEntry = root.normalizedClass(notification?.notification?.desktopEntry)
        const applications = DesktopEntries.applications.values
        for (let i = 0; i < applications.length; ++i) {
            const application = applications[i]
            const id = root.normalizedClass(application?.id)
            const name = root.normalizedClass(application?.name)
            if ((desktopEntry.length > 0 && id === desktopEntry)
                    || (appName.length > 0 && name === appName)) {
                add(application?.startupClass)
                add(application?.id)
            }
        }
        return result
    }

    function belongsToToplevel(notification, toplevel) {
        const client = HyprlandData.clientForToplevel(toplevel)
        if (!client)
            return false
        const cls = normalizedClass(client.class)
        const initial = normalizedClass(client.initialClass)
        const candidates = classesFor(notification)
        return (cls.length > 0 && candidates.indexOf(cls) >= 0)
            || (initial.length > 0 && candidates.indexOf(initial) >= 0)
    }

    function dismissFocused(toplevel) {
        if (!K4Settings.dismissNotificationsOnFocus || !toplevel)
            return
        const candidates = history.slice()
        for (let i = 0; i < candidates.length; ++i) {
            if (belongsToToplevel(candidates[i], toplevel))
                dismiss(candidates[i])
        }
    }

    function routeToast() {
        const owner = IslandState.occupant === "toast" ? previousOwner : IslandState.occupant
        inBand = passiveToastOwners.indexOf(owner) < 0
    }

    function dismissToast() {
        toastTimer.stop()
        toastOpen = false
        inBand = false
    }

    function holdToast() {
        toastTimer.stop()
    }

    function resumeToast() {
        if (toastOpen)
            toastTimer.restart()
    }

    Connections {
        target: IslandState

        function onOccupantChanged() {
            if (IslandState.occupant !== "toast")
                root.previousOwner = IslandState.occupant
        }

        function onHoveredChanged() {
            if (IslandState.hovered)
                root.holdToast()
            else
                root.resumeToast()
        }
    }

    Connections {
        target: Hyprland
        function onActiveToplevelChanged() {
            root.dismissFocused(Hyprland.activeToplevel)
        }
    }

    Connections {
        target: Notifications

        function onNotify(notification) {
            if (!root.presentationActive)
                return
            root.latest = notification
            root.count += 1
            root.routeToast()
            root.toastOpen = true
            toastTimer.restart()
        }

        function onDiscard(id) {
            if (root.latest?.notificationId === id)
                root.dismissToast()
        }

        function onDiscardAll() {
            root.latest = null
            root.count = 0
            root.dismissToast()
        }
    }

    Timer {
        id: toastTimer
        interval: 5000
        onTriggered: root.dismissToast()
    }
}
