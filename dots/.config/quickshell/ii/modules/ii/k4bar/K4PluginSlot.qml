import QtQuick

// Persistent host-owned metadata for a dynamically managed built-in plugin.
// The slot survives while its live plugin instance is disabled, failed or
// being recreated so Apps and Settings never depend on a dangling QObject.
QtObject {
    required property string name
    property string title: name
    required property string entry
    property bool configurable: true
    property bool application: false
    property string applicationGlyph: ""

    property bool enabled: true
    property string loadError: ""
    property var instance: null
}
