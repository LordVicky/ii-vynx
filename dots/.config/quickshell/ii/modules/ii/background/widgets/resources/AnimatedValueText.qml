import QtQuick
import qs.modules.common
import qs.modules.common.widgets

Item {
    id: root

    property string text: ""
    property real pixelSize: Appearance.font.pixelSize.hugeass
    property int weight: Font.Bold
    property color textColor: Appearance.colors.colOnPrimaryContainer
    property real transitionOffset: 4

    property string visibleText: ""
    property string pendingText: ""
    property bool frontIsVisible: true
    property bool initialized: false
    property var outgoingItem: frontIsVisible ? frontText : backText
    property var incomingItem: frontIsVisible ? backText : frontText

    implicitWidth: Math.max(frontText.implicitWidth, backText.implicitWidth)
    implicitHeight: Math.max(frontText.implicitHeight, backText.implicitHeight)
    clip: true

    function startTransition() {
        if (!root.initialized || transition.running || root.pendingText === root.visibleText)
            return;

        root.incomingItem.text = root.pendingText;
        root.incomingItem.y = root.incomingItem.restingY + root.transitionOffset;
        root.incomingItem.opacity = 0;
        root.outgoingItem.y = root.outgoingItem.restingY;
        root.outgoingItem.opacity = 1;
        transition.start();
    }

    onTextChanged: {
        pendingText = text;
        startTransition();
    }

    Component.onCompleted: {
        visibleText = text;
        pendingText = text;
        frontText.text = text;
        frontText.opacity = 1;
        backText.opacity = 0;
        initialized = true;
    }

    component ValueLayer: StyledText {
        property real restingY: (root.height - implicitHeight) / 2
        x: 0
        font.pixelSize: root.pixelSize
        font.weight: root.weight
        color: root.textColor
        renderType: Text.QtRendering
    }

    ValueLayer {
        id: frontText
    }

    ValueLayer {
        id: backText
    }

    ParallelAnimation {
        id: transition

        NumberAnimation {
            target: root.outgoingItem
            property: "y"
            to: root.outgoingItem.restingY - root.transitionOffset
            duration: 140
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: root.outgoingItem
            property: "opacity"
            to: 0
            duration: 140
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: root.incomingItem
            property: "y"
            to: root.incomingItem.restingY
            duration: 140
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: root.incomingItem
            property: "opacity"
            to: 1
            duration: 140
            easing.type: Easing.OutCubic
        }

        onFinished: {
            root.visibleText = root.incomingItem.text;
            root.frontIsVisible = !root.frontIsVisible;
            Qt.callLater(root.startTransition);
        }
    }
}
