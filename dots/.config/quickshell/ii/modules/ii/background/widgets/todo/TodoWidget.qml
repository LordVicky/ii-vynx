import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.ii.background.widgets

AbstractBackgroundWidget {
    id: root
    configEntryName: "todo"
    hoverEnabled: true

    property real dragScale: -1
    readonly property real widgetScale: dragScale >= 0 ? dragScale : (Config.options.background.widgets.todo.scale ?? 1)

    implicitWidth: card.implicitWidth
    implicitHeight: card.implicitHeight

    // Todo.list holds every task ever added; the widget is a glanceable view of
    // what's still open, so done items drop out. Indices into Todo.list are kept
    // alongside because markDone/deleteItem address the unfiltered list.
    readonly property var openTasks: {
        let res = [];
        for (let i = 0; i < Todo.list.length; i++) {
            if (!Todo.list[i].done)
                res.push({ index: i, content: Todo.list[i].content });
        }
        return res;
    }
    readonly property int doneCount: Todo.list.length - openTasks.length

    BackgroundWidgetCard {
        id: card
        host: root
        scaleFactor: root.widgetScale
        baseWidth: 288
        baseHeight: 264
        onRequestScale: v => root.dragScale = v
        onCommitScale: v => {
            Config.options.background.widgets.todo.scale = v;
            root.dragScale = -1;
        }

        ColumnLayout {
            anchors.fill: parent
            spacing: 8

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                MaterialSymbol {
                    text: "checklist"
                    iconSize: Appearance.font.pixelSize.large
                    color: Appearance.colors.colPrimary
                }
                StyledText {
                    Layout.fillWidth: true
                    text: Translation.tr("To-do")
                    font.pixelSize: Appearance.font.pixelSize.normal
                    font.weight: Font.DemiBold
                    color: Appearance.colors.colOnLayer0
                }
                StyledText {
                    text: `${root.openTasks.length}`
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colSubtext
                }
            }

            StyledListView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 2
                clip: true
                model: root.openTasks

                delegate: Item {
                    required property var modelData
                    width: ListView.view.width
                    implicitHeight: 26

                    RowLayout {
                        anchors.fill: parent
                        spacing: 6

                        MaterialSymbol {
                            text: "check_box_outline_blank"
                            iconSize: Appearance.font.pixelSize.normal
                            color: taskArea.containsMouse ? Appearance.colors.colPrimary : Appearance.colors.colSubtext
                        }
                        StyledText {
                            Layout.fillWidth: true
                            text: modelData.content
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colOnLayer0
                            elide: Text.ElideRight
                        }
                    }

                    MouseArea {
                        id: taskArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Todo.markDone(modelData.index)
                    }
                }
            }

            StyledText {
                Layout.fillWidth: true
                visible: root.openTasks.length === 0
                horizontalAlignment: Text.AlignHCenter
                text: Todo.list.length === 0 ? Translation.tr("No tasks yet") : Translation.tr("All done")
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colSubtext
            }

            StyledText {
                Layout.fillWidth: true
                visible: root.doneCount > 0
                text: Translation.tr("%1 completed").arg(root.doneCount)
                font.pixelSize: Appearance.font.pixelSize.smallest
                color: Appearance.colors.colSubtext
            }
        }
    }
}
