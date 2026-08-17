import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import qs.services
import qs.modules.common
import qs.modules.common.widgets

ContentPage {
    id: page

    readonly property int index: 8
    property bool register: parent.register ?? false
    forceWidth: true

    property string statusMessage: ""
    property bool statusIsError: false
    property string pendingReplaceName: ""
    property string pendingReplaceDescription: ""
    property string pendingDeleteName: ""

    function presetNameFromFile(fileName) {
        return fileName.endsWith(".json") ? fileName.slice(0, -5) : fileName;
    }

    function presetExists(name) {
        for (let i = 0; i < Presets.model.count; ++i) {
            if (Presets.model.get(i, "fileName") === `${name}.json`)
                return true;
        }
        return false;
    }

    function replacementPending() {
        return page.pendingReplaceName.length > 0
            && page.pendingReplaceName === presetNameField.text
            && page.pendingReplaceDescription === presetDescriptionField.text;
    }

    function clearReplaceConfirmation() {
        page.pendingReplaceName = "";
        page.pendingReplaceDescription = "";
    }

    function saveCurrentPreset(replace) {
        const name = presetNameField.text;
        const description = presetDescriptionField.text;

        if (name.length === 0) {
            page.statusMessage = Translation.tr("Preset name cannot be empty.");
            page.statusIsError = true;
            return;
        }
        if (name !== name.trim()) {
            page.statusMessage = Translation.tr("Preset names cannot start or end with whitespace.");
            page.statusIsError = true;
            return;
        }

        if (!replace && page.presetExists(name)) {
            page.pendingReplaceName = name;
            page.pendingReplaceDescription = description;
            page.statusMessage = Translation.tr("Preset %1 already exists. Press Replace preset to overwrite it.").arg(name);
            page.statusIsError = false;
            return;
        }

        if (Presets.save(name, description, replace)) {
            page.clearReplaceConfirmation();
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
                page.clearReplaceConfirmation();
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
            if (operation === "save" && message.indexOf("preset already exists:") !== -1) {
                page.pendingReplaceName = presetName;
                page.pendingReplaceDescription = presetDescriptionField.text;
                Presets.refreshModel();
                page.statusMessage = Translation.tr("Preset %1 already exists. Press Replace preset to overwrite it.").arg(presetName);
                page.statusIsError = false;
                return;
            }

            page.clearReplaceConfirmation();
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
            onTextChanged: page.clearReplaceConfirmation()
            onAccepted: page.saveCurrentPreset(false)
        }

        MaterialTextField {
            id: presetDescriptionField
            Layout.fillWidth: true
            enabled: !Presets.busy
            placeholderText: Translation.tr("Description (optional)")
            onTextChanged: page.clearReplaceConfirmation()
            onAccepted: page.saveCurrentPreset(false)
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
                readonly property bool replacing: page.replacementPending()

                materialIcon: Presets.busy && Presets.currentOperation === "save"
                    ? "hourglass_top"
                    : replacing
                        ? "warning"
                        : "save"
                mainText: Presets.busy && Presets.currentOperation === "save"
                    ? Translation.tr("Saving…")
                    : replacing
                        ? Translation.tr("Replace preset")
                        : Translation.tr("Save preset")
                enabled: !Presets.busy && presetNameField.text.length > 0
                onClicked: page.saveCurrentPreset(replacing)
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
