import QtQuick

Item {
    id: root

    property string source: ""
    property color color: "white"
    readonly property string normalizedSource: source.toLowerCase()
    readonly property bool iphone: normalizedSource.includes("iphone")
    readonly property bool watch: normalizedSource.includes("watch")
    readonly property bool airpods: normalizedSource.includes("airpods")

    implicitWidth: 24
    implicitHeight: 24

    Item {
        anchors.fill: parent
        visible: root.iphone

        Rectangle {
            id: phoneBody
            anchors.centerIn: parent
            width: Math.round(root.width * 0.62)
            height: Math.round(root.height * 0.96)
            radius: Math.round(width * 0.22)
            color: "transparent"
            border.width: Math.max(2, Math.round(root.width * 0.1))
            border.color: root.color
            antialiasing: true
        }

        Rectangle {
            anchors.horizontalCenter: phoneBody.horizontalCenter
            y: phoneBody.y + phoneBody.border.width
            width: Math.round(root.width * 0.27)
            height: Math.max(2, Math.round(root.height * 0.07))
            radius: height / 2
            color: root.color
            antialiasing: true
        }
    }

    Item {
        anchors.fill: parent
        visible: root.watch

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 0
            width: Math.round(root.width * 0.34)
            height: Math.round(root.height * 0.28)
            radius: Math.round(width * 0.12)
            color: root.color
        }

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            width: Math.round(root.width * 0.34)
            height: Math.round(root.height * 0.28)
            radius: Math.round(width * 0.12)
            color: root.color
        }

        Rectangle {
            id: watchCase
            anchors.centerIn: parent
            width: Math.round(root.width * 0.72)
            height: Math.round(root.height * 0.68)
            radius: Math.round(width * 0.25)
            color: "transparent"
            border.width: Math.max(2, Math.round(root.width * 0.1))
            border.color: root.color
            antialiasing: true
        }

        Rectangle {
            x: watchCase.x + watchCase.width - 1
            anchors.verticalCenter: watchCase.verticalCenter
            width: Math.max(2, Math.round(root.width * 0.09))
            height: Math.round(root.height * 0.2)
            radius: width / 2
            color: root.color
        }
    }

    Item {
        anchors.fill: parent
        visible: root.airpods

        Rectangle {
            x: Math.round(root.width * 0.05)
            y: Math.round(root.height * 0.08)
            width: Math.round(root.width * 0.38)
            height: width
            radius: width / 2
            color: root.color
            antialiasing: true
        }

        Rectangle {
            x: Math.round(root.width * 0.3)
            y: Math.round(root.height * 0.3)
            width: Math.max(3, Math.round(root.width * 0.14))
            height: Math.round(root.height * 0.62)
            radius: width / 2
            color: root.color
        }

        Rectangle {
            anchors.right: parent.right
            anchors.rightMargin: Math.round(root.width * 0.05)
            y: Math.round(root.height * 0.08)
            width: Math.round(root.width * 0.38)
            height: width
            radius: width / 2
            color: root.color
            antialiasing: true
        }

        Rectangle {
            x: Math.round(root.width * 0.56)
            y: Math.round(root.height * 0.3)
            width: Math.max(3, Math.round(root.width * 0.14))
            height: Math.round(root.height * 0.62)
            radius: width / 2
            color: root.color
        }
    }
}
