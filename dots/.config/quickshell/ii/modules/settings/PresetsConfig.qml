import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import qs.services
import qs.modules.common
import qs.modules.common.widgets

ContentPage {
    id: page

    readonly property int index: 9
    property bool register: parent.register ?? false
    forceWidth: true

    property string statusMessage: ""
    property bool statusIsError: false
    property string pendingDeleteName: ""

    function presetNameFromFile(fileName) {
        return fileName.endsWith(".json") ? fileName.slice(0, -5) : fileName;
    }

    function saveCurrentPreset() {
        const name = presetNameField.text.trim();
        const description = presetDescriptionField.text.trim();
        if (Presets.save(name, description)) {
            page.statusMessage = Translation.tr("Saving preset…");
            page.statusIsError = false;
        }
    }

    Connections {
        target: Presets

        function onOperationFinished(operation, presetName) {
            page.statusIsError = false;

            if (operation === "save") {
                page.statusMessage = Translation.tr("Saved preset: %1").arg(presetName);
                presetNameField.text = "";
                presetDescriptionField.text = "";
            } else if (operation === "apply") {
                page.statusMessage = Translation.tr("Applied preset: %1").arg(presetName);
            } else if (operation === "remove") {
                page.statusMessage = Translation.tr("Deleted preset: %1").arg(presetName);
                if (page.pendingDeleteName === presetName)
                    page.pendingDeleteName = "";
            }
        }

        function onOperationFailed(operation, presetName, message) {
            page.statusMessage = message;
            page.statusIsError = true;
        }
    }

    ContentSection {
        icon: "bookmark_add"
        title: Translation.tr("Save current setup")
        stringMap: [Translation.tr("preset"), Translation.tr("snapshot"), Translation.tr("configuration")]

        NoticeBox {
            Layout.fillWidth: true
            materialIcon: "info"
            text: Translation.tr("Presets save the full current shell configuration. Applying one restores the values stored in that snapshot while preserving config keys that were added later.")
        }

        MaterialTextField {
            id: presetNameField
            Layout.fillWidth: true
            enabled: !Presets.busy
            placeholderText: Translation.tr("Preset name")
            maximumLength: 80
            onAccepted: page.saveCurrentPreset()
        }

        MaterialTextField {
            id: presetDescriptionField
            Layout.fillWidth: true
            enabled: !Presets.busy
            placeholderText: Translation.tr("Description (optional)")
            onAccepted: page.saveCurrentPreset()
        }

        RowLayout {
            Layout.fillWidth: true

            StyledText {
                Layout.fillWidth: true
                visible: page.statusMessage.length > 0
                text: page.statusMessage
                color: page.statusIsError ? Appearance.colors.colError : Appearance.colors.colOnLayer2
                wrapMode: Text.WordWrap
            }

            RippleButtonWithIcon {
                materialIcon: Presets.busy && Presets.currentOperation === "save" ? "hourglass_top" : "save"
                mainText: Presets.busy && Presets.currentOperation === "save" ? Translation.tr("Saving…") : Translation.tr("Save preset")
                enabled: !Presets.busy && presetNameField.text.trim().length > 0
                onClicked: page.saveCurrentPreset()
            }
        }
    }

    ContentSection {
        icon: "bookmarks"
        title: Translation.tr("Saved presets")
        stringMap: [Translation.tr("apply"), Translation.tr("delete"), Translation.tr("restore")]

        StyledText {
            Layout.fillWidth: true
            visible: Presets.model.count === 0
            text: Translation.tr("No presets saved yet.")
            color: Appearance.colors.colOnLayer2
            horizontalAlignment: Text.AlignHCenter
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 6

            Repeater {
                model: Presets.model

                delegate: Rectangle {
                    id: presetCard

                    required property string fileName
                    readonly property string presetName: page.presetNameFromFile(fileName)
                    property string description: ""

                    Layout.fillWidth: true
                    implicitHeight: presetCardContent.implicitHeight + 20
                    radius: Appearance.rounding.normal
                    color: Appearance.colors.colLayer1

                    function refreshMetadata() {
                        try {
                            const data = JSON.parse(metadataFile.text());
                            const value = data?._presetMeta?.description;
                            presetCard.description = typeof value === "string" ? value : "";
                        } catch (error) {
                            presetCard.description = "";
                        }
                    }

                    FileView {
                        id: metadataFile
                        path: `${Presets.presetDirectory}/${presetCard.fileName}`
                        watchChanges: true
                        printErrors: false
                        onLoaded: presetCard.refreshMetadata()
                        onFileChanged: reload()
                        onLoadFailed: presetCard.description = ""
                    }

                    ColumnLayout {
                        id: presetCardContent
                        anchors {
                            fill: parent
                            margins: 10
                        }
                        spacing: 8

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10

                            MaterialSymbol {
                                text: "bookmark"
                                fill: 1
                                iconSize: Appearance.font.pixelSize.hugeass
                                color: Appearance.colors.colOnLayer1
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1

                                StyledText {
                                    Layout.fillWidth: true
                                    text: presetCard.presetName
                                    color: Appearance.colors.colOnLayer1
                                    font.pixelSize: Appearance.font.pixelSize.normal
                                    font.weight: Font.Medium
                                    elide: Text.ElideRight
                                }

                                StyledText {
                                    Layout.fillWidth: true
                                    text: presetCard.description.length > 0
                                        ? presetCard.description
                                        : Translation.tr("Full configuration snapshot")
                                    color: Appearance.colors.colOnLayer2
                                    font.pixelSize: Appearance.font.pixelSize.small
                                    wrapMode: Text.WordWrap
                                }
                            }

                            RippleButtonWithIcon {
                                materialIcon: Presets.busy && Presets.currentOperation === "apply" ? "hourglass_top" : "restore"
                                mainText: Translation.tr("Apply")
                                enabled: !Presets.busy && page.pendingDeleteName.length === 0
                                onClicked: Presets.apply(presetCard.presetName)
                            }

                            RippleButtonWithIcon {
                                visible: page.pendingDeleteName !== presetCard.presetName
                                materialIcon: "delete"
                                mainText: Translation.tr("Delete")
                                enabled: !Presets.busy && page.pendingDeleteName.length === 0
                                onClicked: page.pendingDeleteName = presetCard.presetName
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            visible: page.pendingDeleteName === presetCard.presetName
                            spacing: 8

                            StyledText {
                                Layout.fillWidth: true
                                text: Translation.tr("Delete %1 permanently?").arg(presetCard.presetName)
                                color: Appearance.colors.colOnLayer1
                                wrapMode: Text.WordWrap
                            }

                            RippleButtonWithIcon {
                                materialIcon: "close"
                                mainText: Translation.tr("Cancel")
                                enabled: !Presets.busy
                                onClicked: page.pendingDeleteName = ""
                            }

                            RippleButtonWithIcon {
                                materialIcon: Presets.busy && Presets.currentOperation === "remove" ? "hourglass_top" : "delete_forever"
                                mainText: Translation.tr("Delete")
                                enabled: !Presets.busy
                                onClicked: Presets.remove(presetCard.presetName)
                            }
                        }
                    }
                }
            }
        }
    }
}
