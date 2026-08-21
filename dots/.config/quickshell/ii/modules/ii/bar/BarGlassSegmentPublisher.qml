import QtQuick
import qs

Item {
    id: root

    width: 0
    height: 0
    visible: false

    required property bool vertical
    required property var targetScreen
    required property string segmentKey
    required property bool active
    required property real position
    required property real extent
    required property real startRadius
    required property real endRadius

    property bool registeredVertical: false
    property string registeredScreenName: ""
    property string registeredSegmentKey: ""

    function clearRegistered() {
        if (!root.registeredScreenName || !root.registeredSegmentKey)
            return;

        GlobalStates.clearBarGlassSegment(
            root.registeredVertical,
            root.registeredScreenName,
            root.registeredSegmentKey
        );
        root.registeredScreenName = "";
        root.registeredSegmentKey = "";
    }

    function sync() {
        const screenName = root.targetScreen?.name ?? "";
        const shouldRegister = GlobalStates.unifiedBarGlassSegmentsEnabled
            && root.active
            && screenName.length > 0
            && root.extent > 0;

        if (root.registeredScreenName
                && (!shouldRegister
                    || root.registeredVertical !== root.vertical
                    || root.registeredScreenName !== screenName
                    || root.registeredSegmentKey !== root.segmentKey))
            root.clearRegistered();

        if (!shouldRegister)
            return;

        GlobalStates.setBarGlassSegment(root.vertical, screenName, root.segmentKey, {
            position: Number(root.position),
            extent: Number(root.extent),
            startRadius: Number(root.startRadius),
            endRadius: Number(root.endRadius)
        });
        root.registeredVertical = root.vertical;
        root.registeredScreenName = screenName;
        root.registeredSegmentKey = root.segmentKey;
    }

    Component.onCompleted: root.sync()
    Component.onDestruction: root.clearRegistered()

    onVerticalChanged: root.sync()
    onTargetScreenChanged: root.sync()
    onSegmentKeyChanged: root.sync()
    onActiveChanged: root.sync()
    onPositionChanged: root.sync()
    onExtentChanged: root.sync()
    onStartRadiusChanged: root.sync()
    onEndRadiusChanged: root.sync()

    Connections {
        target: GlobalStates

        function onUnifiedBarGlassSegmentsEnabledChanged() {
            root.sync();
        }
    }
}
