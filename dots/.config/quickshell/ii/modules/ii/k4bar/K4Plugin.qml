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
    property bool configurable: true
    property bool closeOnDisable: true
    property string loadError: ""
    property int priority: 50
    property bool transitorio: false

    // Upstream's Apps catalog is explicit: only plugins marked as applications
    // belong in the utility grid. Keep that metadata on the plugin contract so
    // future built-ins can opt in without creating a second registry.
    property bool application: false
    property string applicationGlyph: ""

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

    // A utility must opt into both the catalog and its activation behavior.
    // Do not assign active here: many concrete plugins bind active to their own
    // state, and an assignment would destroy that binding.
    function openApplication() {
        return false
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
            // Stateful plugins clear their owning open state through close().
            // Passive plugins with a bound active expression opt out so the
            // base close assignment cannot sever that binding.
            if (root.closeOnDisable)
                root.close()
            releasePlacement()
        }
    }

    Component.onDestruction: releasePlacement()
}