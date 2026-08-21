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

    property var sourceItem: null
    property var coordinateRoot: null
    readonly property bool usesDirectGeometry: root.sourceItem !== null && root.coordinateRoot !== null
    readonly property real resolvedPosition: {
        if (!root.usesDirectGeometry)
            return root.position;

        let current = root.sourceItem;
        let offset = 0;
        while (current && current !== root.coordinateRoot) {
            offset += root.vertical ? Number(current.y) : Number(current.x);
            current = current.parent;
        }
        return current === root.coordinateRoot ? offset : root.position;
    }
    readonly property real resolvedExtent: root.usesDirectGeometry
        ? (root.vertical ? Number(root.sourceItem.height) : Number(root.sourceItem.width))
        : root.extent

    property bool registeredVertical: false
    property string registeredScreenName: ""
    property string registeredSegmentKey: ""

    function clearRegistered() {
        if (!root.registeredScreenName || !root.registeredSegmentKey)
            return;

        GlobalStates.clearLiveBarGlassSegment(
            root.registeredVertical,
            root.registeredScreenName,
            root.registeredSegmentKey,
            root
        );
        root.registeredScreenName = "";
        root.registeredSegmentKey = "";
    }

    function sync() {
        const screenName = root.targetScreen?.name ?? "";
        const shouldRegister = GlobalStates.unifiedBarGlassSegmentsEnabled
            && root.active
            && screenName.length > 0
            && root.resolvedExtent > 0;
        const registrationMatches = root.registeredScreenName.length > 0
            && root.registeredVertical === root.vertical
            && root.registeredScreenName === screenName
            && root.registeredSegmentKey === root.segmentKey;

        if (root.registeredScreenName && (!shouldRegister || !registrationMatches))
            root.clearRegistered();

        if (!shouldRegister || registrationMatches)
            return;

        GlobalStates.setLiveBarGlassSegment(
            root.vertical,
            screenName,
            root.segmentKey,
            root
        );
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
    onResolvedExtentChanged: root.sync()

    Connections {
        target: GlobalStates

        function onUnifiedBarGlassSegmentsEnabledChanged() {
            root.sync();
        }
    }
}