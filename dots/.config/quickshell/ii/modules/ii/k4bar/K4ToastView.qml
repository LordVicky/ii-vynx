import QtQuick

// The island host owns the morphing geometry and background click. This view
// only fades in the shared notification presentation and isolates its controls.
Item {
    id: root

    readonly property var notification: K4Notifications.latest

    opacity: 0
    Component.onCompleted: fadeIn.start()

    NumberAnimation {
        id: fadeIn
        target: root
        property: "opacity"
        from: 0
        to: 1
        duration: 180
        easing.type: Easing.OutCubic
    }

    K4NotificationCard {
        anchors.fill: parent
        notification: root.notification
        expanded: IslandState.hovered
        bandMode: false

        onDismissRequested: K4Notifications.dismissToast()
        onActionRequested: action => {
            K4Notifications.invokeAction(root.notification, action)
            K4Notifications.dismissToast()
        }
    }
}
