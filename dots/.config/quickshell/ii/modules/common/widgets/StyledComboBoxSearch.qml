import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets

/**
 * A dropdown similar to StyledComboBox, but with a search field to filter
 * long lists (e.g. IANA timezone names) client-side.
 * model: list of objects exposing at least the given textRole (and optionally "icon").
 * onActivated(index): index into the ORIGINAL (unfiltered) model.
 */
Item {
    id: root

    property var model: []
    property string textRole: "label"
    property int currentIndex: -1
    property color colBackground: Appearance.colors.colSecondaryContainer
    property color colBackgroundHover: Appearance.colors.colSecondaryContainerHover
    property color colBackgroundActive: Appearance.colors.colSecondaryContainerActive

    signal activated(int index)

    property string displayText: (root.currentIndex >= 0 && root.currentIndex < root.model.length)
        ? (root.model[root.currentIndex][root.textRole] ?? "")
        : ""

    implicitHeight: 40
    Layout.fillWidth: true

    Rectangle {
        id: button
        anchors.fill: parent
        radius: Appearance.rounding.full
        color: mouseArea.pressed ? root.colBackgroundActive : mouseArea.containsMouse ? root.colBackgroundHover : root.colBackground

        Behavior on color {
            animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            spacing: 8

            StyledText {
                Layout.fillWidth: true
                color: Appearance.colors.colOnSecondaryContainer
                text: root.displayText
                elide: Text.ElideRight
                verticalAlignment: Text.AlignVCenter
            }

            MaterialSymbol {
                text: "keyboard_arrow_down"
                iconSize: Appearance.font.pixelSize.larger
                color: Appearance.colors.colOnSecondaryContainer
                rotation: popup.visible ? 180 : 0
                Behavior on rotation {
                    animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                }
            }
        }

        MouseArea {
            id: mouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                popup.visible = !popup.visible
                if (popup.visible) searchField.forceActiveFocus()
            }
        }
    }

    Popup {
        id: popup
        y: button.height + 4
        width: button.width
        height: Math.min(320, searchColumn.implicitHeight + topPadding + bottomPadding)
        padding: 8
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent

        onVisibleChanged: {
            if (!visible) {
                searchField.text = ""
                if (searchField.activeFocus)
                    searchField.focus = false
            }
        }

        background: Item {
            StyledRectangularShadow {
                target: popupBackground
            }
            Rectangle {
                id: popupBackground
                anchors.fill: parent
                radius: Appearance.rounding.normal
                color: Appearance.m3colors.m3surfaceContainerHigh
            }
        }

        contentItem: ColumnLayout {
            id: searchColumn
            spacing: 6

            TextField {
                id: searchField
                Layout.fillWidth: true
                placeholderText: Translation.tr("Search…")
                color: Appearance.colors.colOnLayer0
                background: Rectangle {
                    radius: Appearance.rounding.small
                    color: Appearance.colors.colLayer1
                }
                // Only suppress global shortcuts while this search field actually has focus
                onActiveFocusChanged: {
                    GlobalStates.desktopWidgetKeyboardFocus = activeFocus
                }
                Component.onDestruction: {
                    if (GlobalStates.desktopWidgetKeyboardFocus && searchField.activeFocus)
                        GlobalStates.desktopWidgetKeyboardFocus = false
                }
            }

            StyledListView {
                id: listView
                Layout.fillWidth: true
                Layout.preferredHeight: 260
                clip: true
                spacing: 2

                property var filteredIndices: {
                    const query = searchField.text.trim().toLowerCase()
                    let indices = []
                    for (let i = 0; i < root.model.length; i++) {
                        const entry = root.model[i]
                        const label = (entry?.[root.textRole] ?? "").toString().toLowerCase()
                        if (query === "" || label.includes(query))
                            indices.push(i)
                    }
                    return indices
                }

                model: listView.filteredIndices

                delegate: ItemDelegate {
                    id: itemDelegate
                    required property int modelData
                    width: listView.width
                    implicitHeight: 36

                    property var entry: root.model[modelData]
                    property color colText: (root.currentIndex === modelData) ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colOnLayer3

                    background: Rectangle {
                        anchors.fill: parent
                        radius: Appearance.rounding.small
                        color: root.currentIndex === itemDelegate.modelData
                            ? Appearance.colors.colSecondaryContainer
                            : itemDelegate.hovered ? Appearance.colors.colLayer3Hover : "transparent"

                        Behavior on color {
                            animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
                        }
                    }

                    contentItem: RowLayout {
                        spacing: 8
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10

                        Loader {
                            Layout.alignment: Qt.AlignVCenter
                            active: (itemDelegate.entry?.icon ?? "").length > 0
                            visible: active
                            sourceComponent: MaterialSymbol {
                                text: itemDelegate.entry?.icon ?? ""
                                iconSize: Appearance.font.pixelSize.larger
                                color: itemDelegate.colText
                            }
                        }

                        StyledText {
                            Layout.fillWidth: true
                            color: itemDelegate.colText
                            text: itemDelegate.entry?.[root.textRole] ?? ""
                            elide: Text.ElideRight
                            verticalAlignment: Text.AlignVCenter
                        }
                    }

                    onClicked: {
                        root.activated(itemDelegate.modelData)
                        popup.visible = false
                    }
                }
            }
        }
    }
}
