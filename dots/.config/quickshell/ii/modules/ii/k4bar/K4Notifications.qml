pragma Singleton

import QtQuick
import Quickshell
import qs.services

// k4 notification presentation state backed by ii-vynx's existing
// Notifications singleton. This adapter never owns a NotificationServer.
Singleton {
    id: root

    property var latest: null
    property int count: 0
    property bool toastOpen: false

    readonly property var recent: Notifications.list.slice().reverse()

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

    function dismissToast() {
        toastTimer.stop()
        toastOpen = false
    }

    function holdToast() {
        toastTimer.stop()
    }

    function resumeToast() {
        if (toastOpen)
            toastTimer.restart()
    }

    Connections {
        target: Notifications

        function onNotify(notification) {
            root.latest = notification
            root.count += 1
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
