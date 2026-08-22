import QtQuick

Item {
    id: root

    width: 0
    height: 0
    visible: false

    required property bool vertical
    property var targetScreen: null
    property string segmentKey: ""
    property bool active: false
    required property real position
    required property real extent
    property real startRadius: 0
    property real endRadius: 0

    property var sourceItem: null
    property var coordinateRoot: null
    property int geometryRevision: 0
    readonly property bool usesDirectGeometry: root.sourceItem !== null && root.coordinateRoot !== null
    readonly property real resolvedPosition: {
        root.geometryRevision;
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
    readonly property real resolvedExtent: {
        root.geometryRevision;
        return root.usesDirectGeometry
            ? (root.vertical ? Number(root.sourceItem.height) : Number(root.sourceItem.width))
            : root.extent;
    }

    onPositionChanged: root.geometryRevision += 1
    onExtentChanged: root.geometryRevision += 1
}
