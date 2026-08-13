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
    function scaled(value) { return value * root.widgetScale; }

    implicitWidth: scaleWrapper.implicitWidth
    implicitHeight: scaleWrapper.implicitHeight

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
        implicitWidth: root.scaled(276)
        implicitHeight: root.scaled(252)
        width: implicitWidth
        height: implicitHeight
        Behavior on width { animation: Appearance.animation.elementResize.numberAnimation.createObject(this) }
        Behavior on height { animation: Appearance.animation.elementResize.numberAnimation.createObject(this) }

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

        StyledDropShadow {
            target: contentRect
            radius: root.scaled(8)
            samples: Math.max(1, Math.ceil(radius * 2 + 1))
        }

        Rectangle {
            id: contentRect
            anchors.fill: parent
            color: "transparent"
            radius: root.scaled(Appearance.rounding?.verylarge ?? 30)

            WidgetBlurBackground {
                contrastHost: root
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
                anchors { fill: parent; margins: root.scaled(12) }
                spacing: root.scaled(10)
                visible: root.mode === "list"

                RowLayout {
                    Layout.fillWidth: true
                    spacing: root.scaled(4)

                    StyledText {
                        Layout.topMargin: root.scaled(-4)
                        Layout.leftMargin: root.scaled(8)
                        font.pixelSize: root.scaled(Appearance.font.pixelSize.huge)
                        font.weight: Font.Medium
                        renderType: Text.QtRendering
                        color: Appearance.colors.colOnPrimaryContainer
                        text: "Notes"
                    }
                    Item { Layout.fillWidth: true }

                    ToolbarPairedFab {
                        Layout.rightMargin: root.scaled(4)
                        Layout.alignment: Qt.AlignVCenter
                        baseSize: root.scaled(38)
                        iconText: "add"
                        onClicked: root.openNewNote()
                    }
                }

                StyledListView {
                    id: notesListView
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    spacing: root.scaled(6)
                    model: Notes.list

                    delegate: SwipeDelegate {
                        id: noteCard
                        required property var modelData
                        required property int index

                        width: notesListView.width
                        implicitHeight: root.scaled(55)
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
                            radius: root.scaled(Appearance.rounding.normal)
                            color: noteCard.bg
                            width: parent.width - Math.abs(noteCard.swipe.position) * 6

                            StyledText {
                                anchors {
                                    left: parent.left; right: parent.right
                                    verticalCenter: parent.verticalCenter
                                    leftMargin: root.scaled(12); rightMargin: root.scaled(12)
                                }
                                font.pixelSize: root.scaled(Appearance.font.pixelSize.normal)
                                renderType: Text.QtRendering
                                color: noteCard.fg
                                text: noteCard.modelData.content
                                elide: Text.ElideRight
                                maximumLineCount: 1
                            }
                        }

                        swipe.right: Rectangle {
                            width: root.scaled(64)
                            anchors.right: parent.right
                            height: parent.height
                            radius: root.scaled(Appearance.rounding.normal)
                            color: Appearance.colors.colError

                            MaterialSymbol {
                                anchors.centerIn: parent
                                text: "delete"
                                iconSize: root.scaled(Appearance.font.pixelSize.larger)
                                renderType: Text.QtRendering
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
                anchors { fill: parent; margins: root.scaled(12) }
                spacing: root.scaled(10)
                visible: root.mode === "edit"

                RowLayout {
                    Layout.fillWidth: true
                    spacing: root.scaled(4)

                    Rectangle {
                        radius: Appearance.rounding.full
                        color: "transparent"
                        implicitWidth: root.scaled(28); implicitHeight: root.scaled(28)
                        MaterialSymbol {
                            anchors.centerIn: parent
                            iconSize: root.scaled(Appearance.font.pixelSize.normal)
                            renderType: Text.QtRendering
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
                        Layout.rightMargin: root.scaled(4)
                        Layout.alignment: Qt.AlignVCenter
                        baseSize: root.scaled(38)
                        iconText: "save"
                        onClicked: root.saveAndBack()
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: root.scaled(Appearance.rounding.normal)
                    color: Appearance.colors.colSurfaceContainerLow

                    TextArea {
                        id: editTextArea
                        anchors.fill: parent
                        anchors.margins: root.scaled(8)
                        text: root.editingText
                        wrapMode: TextArea.Wrap
                        placeholderText: "Type your note..."
                        color: Appearance.colors.colOnLayer0
                        font.family: Appearance.font.family.main
                        font.pixelSize: root.scaled(Appearance.font.pixelSize.normal)
                        renderType: Text.QtRendering
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
        baseSize: 276
        onRequestScale: (v) => root.dragScale = v
        onRequestCommit: (v) => { Config.options.background.widgets.notes.scale = v; root.dragScale = -1 }
    }
}
