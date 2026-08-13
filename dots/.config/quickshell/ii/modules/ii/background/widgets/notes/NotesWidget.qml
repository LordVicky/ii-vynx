import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.common.widgets.widgetCanvas
import qs.modules.ii.background.widgets

AbstractBackgroundWidget {
    id: root
    configEntryName: "notes"
    hoverEnabled: true

    // Live drag override. -1 means "not dragging", which lets widgetScale keep
    // its binding to the persisted config value; a plain assignment during drag
    // would break that binding permanently.
    property real dragScale: -1
    readonly property real widgetScale: dragScale >= 0 ? dragScale : (Config.options.background.widgets.notes.scale ?? 1)

    implicitWidth: scaleWrapper.implicitWidth * root.widgetScale
    implicitHeight: scaleWrapper.implicitHeight * root.widgetScale

    property string mode: "list" // "list" | "edit"
    property var pendingNoteId: null
    property string editingText: ""
    // Text input only actually happens once editTextArea has focus (see below);
    // entering/leaving edit mode just requests/releases that focus.
    onModeChanged: {
        if (mode === "edit") {
            editTextArea.forceActiveFocus()
        } else if (editTextArea.activeFocus) {
            editTextArea.focus = false
        }
    }

    function toggleFlip() { flipAnim.start() }

    function openNewNote() {
        root.pendingNoteId = null
        root.editingText = ""
        toggleFlip()
    }

    function openNote(note) {
        root.pendingNoteId = note.id
        root.editingText = note.content
        toggleFlip()
    }

    function saveAndBack() {
        if (root.editingText.length > 0) {
            if (root.pendingNoteId) {
                Notes.updateNote(root.pendingNoteId, root.editingText)
            } else {
                Notes.addNote(root.editingText)
            }
        }
        toggleFlip()
    }

    Item {
        id: scaleWrapper
        implicitWidth: 276
        implicitHeight: 252
        width: implicitWidth
        height: implicitHeight
        transformOrigin: Item.TopLeft
        scale: root.widgetScale
        Behavior on scale { animation: Appearance.animation.elementResize.numberAnimation.createObject(this) }

    Item {
        id: cardWrapper
        anchors.fill: parent

        transform: Scale {
            id: flipScale
            origin.x: cardWrapper.width  / 2
            origin.y: cardWrapper.height / 2
            xScale: 1
        }

        SequentialAnimation {
            id: flipAnim
            NumberAnimation {
                target: flipScale; property: "xScale"
                to: 0; duration: 150; easing.type: Easing.InQuad
            }
            ScriptAction {
                script: root.mode = (root.mode === "list" ? "edit" : "list")
            }
            NumberAnimation {
                target: flipScale; property: "xScale"
                to: 1; duration: 150; easing.type: Easing.OutQuad
            }
        }

        StyledDropShadow { target: contentRect }

        Rectangle {
            id: contentRect
            anchors.fill: parent
            color: "transparent"
            radius: Appearance.rounding?.verylarge ?? 30

            WidgetBlurBackground {
                anchors.fill: parent
                cornerRadius: contentRect.radius
                blur: root.blur
                wallpaperPath: root.wallpaperPath
                sourceWidth: root.scaledScreenWidth
                sourceHeight: root.scaledScreenHeight
                offsetX: root.x
                offsetY: root.y
                wallpaperRenderX: root.wallpaperRenderX
                wallpaperRenderY: root.wallpaperRenderY
                wallpaperRenderWidth: root.wallpaperRenderWidth
                wallpaperRenderHeight: root.wallpaperRenderHeight
                parallaxBackdrop: root.parallaxBackdrop
                wallpaperSourceItem: root.wallpaperSourceItem
                hostScale: root.widgetScale
            }

            // List
            ColumnLayout {
                id: listPage
                anchors { fill: parent; margins: 12 }
                spacing: 10
                visible: root.mode === "list"

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    StyledText {
                        Layout.topMargin: -4
                        Layout.leftMargin: 8
                        font.pixelSize: Appearance.font.pixelSize.huge
                        font.weight: Font.Medium
                        color: Appearance.colors.colOnPrimaryContainer
                        text: "Notes"
                    }
                    Item { Layout.fillWidth: true }

                    ToolbarPairedFab {
                        Layout.rightMargin: 4
                        Layout.alignment: Qt.AlignVCenter
                        baseSize: 38
                        iconText: "add"
                        onClicked: root.openNewNote()
                    }
                }

                StyledListView {
                    id: notesListView
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    spacing: 6
                    model: Notes.list

                    delegate: SwipeDelegate {
                        id: noteCard
                        required property var modelData
                        required property int index

                        width: notesListView.width
                        implicitHeight: 55
                        padding: 0
                        background: null
                        clip: true

                        property color bg: {
                            const cyclePos = index % 3
                            if (cyclePos === 0) return Appearance.colors.colPrimary
                            if (cyclePos === 1) return Appearance.colors.colSecondary
                            return Appearance.colors.colTertiary
                        }
                        property color fg: {
                            const cyclePos = index % 3
                            if (cyclePos === 0) return Appearance.colors.colOnPrimary
                            if (cyclePos === 1) return Appearance.colors.colOnSecondary
                            return Appearance.colors.colOnTertiary
                        }

                        onClicked: root.openNote(noteCard.modelData)

                        contentItem: Rectangle {
                            radius: Appearance.rounding.normal
                            color: noteCard.bg
                            width: parent.width - Math.abs(noteCard.swipe.position) * 6

                            StyledText {
                                anchors {
                                    left: parent.left; right: parent.right
                                    verticalCenter: parent.verticalCenter
                                    leftMargin: 12; rightMargin: 12
                                }
                                color: noteCard.fg
                                text: noteCard.modelData.content
                                elide: Text.ElideRight
                                maximumLineCount: 1
                            }
                        }

                        swipe.right: Rectangle {
                            width: 64
                            anchors.right: parent.right
                            height: parent.height
                            radius: Appearance.rounding.normal
                            color: Appearance.colors.colError

                            MaterialSymbol {
                                anchors.centerIn: parent
                                text: "delete"
                                iconSize: Appearance.font.pixelSize.larger
                                color: Appearance.colors.colOnError
                            }

                            SwipeDelegate.onClicked: Notes.deleteNote(noteCard.modelData.id)
                        }
                    }
                }
            }

            // Edit
            ColumnLayout {
                id: editPage
                anchors { fill: parent; margins: 12 }
                spacing: 10
                visible: root.mode === "edit"

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    Rectangle {
                        radius: Appearance.rounding.full
                        color: "transparent"
                        implicitWidth: 28; implicitHeight: 28
                        MaterialSymbol {
                            anchors.centerIn: parent
                            iconSize: Appearance.font.pixelSize.normal
                            text: "arrow_back"
                            color: Appearance.colors.colOnPrimaryContainer
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.toggleFlip()
                        }
                    }
                    Item { Layout.fillWidth: true }

                    ToolbarPairedFab {
                        Layout.rightMargin: 4
                        Layout.alignment: Qt.AlignVCenter
                        baseSize: 38
                        iconText: "save"
                        onClicked: root.saveAndBack()
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: Appearance.rounding.normal
                    color: Appearance.colors.colSurfaceContainerLow

                    TextArea {
                        id: editTextArea
                        anchors.fill: parent
                        anchors.margins: 8
                        text: root.editingText
                        wrapMode: TextArea.Wrap
                        placeholderText: "Type your note..."
                        color: Appearance.colors.colOnLayer0
                        background: null
                        onTextChanged: root.editingText = text
                        // Only suppress global shortcuts while this field actually has focus
                        onActiveFocusChanged: {
                            GlobalStates.desktopWidgetKeyboardFocus = activeFocus
                        }
                        Component.onDestruction: {
                            if (GlobalStates.desktopWidgetKeyboardFocus && editTextArea.activeFocus)
                                GlobalStates.desktopWidgetKeyboardFocus = false
                        }
                    }
                }
            }
        }
    }
    }

    WidgetResizeHandle {
        hostWidget: root
        currentScale: root.widgetScale
        baseSize: scaleWrapper.implicitWidth
        onRequestScale: (v) => root.dragScale = v
        onRequestCommit: (v) => { Config.options.background.widgets.notes.scale = v; root.dragScale = -1 }
    }
}