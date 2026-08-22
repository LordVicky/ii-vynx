import QtQuick

// Base plugin contract adapted from k4ditano/k4 api/K4/Plugin.qml at the
// pinned source commit. Copyright (c) 2026 k4ditano — MIT,
// see licenses/k4-NOTICE.txt.
QtObject {
    id: root

    // Long-lived plugin services may be declared as direct children.
    default property list<QtObject> services

    required property string name
    property string title: name

    // Enabled means the plugin may participate. Active means it currently
    // requests the island. The host still decides whether it wins.
    property bool enabled: true
    property bool active: false
    property int priority: 50
    property bool transitorio: false

    property int islandWidth: 300
    property int islandHeight: 60
    property Component view: null
    property bool viewLoaded: true

    // Keyboard policies map directly to the upstream Wayland focus intent.
    property bool grabKeyboard: false
    property bool optionalKeyboard: false
    property bool keyboardOnHover: false

    property bool handlesBackgroundTap: false
    signal backgroundTapped()

    property bool closeOnHoverExit: false
    property int hoverExitDelay: 700
    signal hoverTimedOut()

    function open() {
        if (enabled)
            active = true
    }

    function close() {
        active = false
    }

    function requestPlacement(fraction, durationMs) {
        if (enabled)
            IslandState.requestPlacement(name, fraction, durationMs || 0)
    }

    function releasePlacement() {
        IslandState.releasePlacement(name)
    }

    function requestGesture(gestureName, strength) {
        if (enabled)
            IslandState.requestGesture(name, gestureName, strength)
    }

    onEnabledChanged: {
        if (!enabled) {
            active = false
            releasePlacement()
        }
    }

    Component.onDestruction: releasePlacement()
}
