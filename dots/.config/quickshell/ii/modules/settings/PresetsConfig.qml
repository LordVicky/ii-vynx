import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import qs.services
import qs.modules.common
import qs.modules.common.widgets

ContentPage {
    id: page

    baseWidth: 680
    bottomContentPadding: 40

    readonly property int index: 8
    property bool register: parent.register ?? false
    property string pendingReplaceInput: ""
    property string pendingInputSaveName: ""
    property string pendingDeleteName: ""
    property string operationMessage: ""

    function parsePresetInput(rawInput) {
        const raw = rawInput.trim();
        if (raw.length === 0)
            return null;

        const commaIndex = raw.indexOf(",");
        let name = raw;
        let description = "";

        if (commaIndex !== -1) {
            name = raw.substring(0, commaIndex).trim();
            description = raw.substring(commaIndex + 1).trim();
        }

        name = name.replace(/\s/g, "_");
        if (name.length === 0)
            return null;

        return { name, description };
    }

    function savePreset(rawInput) {
        const parsed = page.parsePresetInput(rawInput);
        if (!parsed)
            return;

        const replace = page.pendingReplaceInput === rawInput;
        page.pendingInputSaveName = parsed.name;
        if (!Presets.save(parsed.name, parsed.description, replace))
            page.pendingInputSaveName = "";
    }

    Connections {
        target: Presets

        function onOperationFinished(operation, presetName) {
            page.operationMessage = "";

            if (operation === "save") {
                page.pendingReplaceInput = "";
                if (page.pendingInputSaveName === presetName) {
                    presetNameField.text = "";
                    page.pendingInputSaveName = "";
                }
            } else if (operation === "remove" && page.pendingDeleteName === presetName) {
                page.pendingDeleteName = "";
            }
        }

        function onOperationFailed(operation, presetName, message) {
            if (operation === "save" && message.indexOf("preset already exists:") !== -1) {
                page.pendingReplaceInput = presetNameField.text;
                page.operationMessage = "Preset already exists. Press save again to replace it.";
                return;
            }

            if (operation === "save")
                page.pendingInputSaveName = "";
            if (operation === "remove")
                page.pendingDeleteName = "";

            page.operationMessage = message;
        }
    }

    ColumnLayout {
        id: mainLayout
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: 20

        ContentSection {
            icon: "wall_art"
            shape: MaterialShape.Shape.Pentagon
            title: Translation.tr("Presets")
            stringMap: [Translation.tr("preset"), Translation.tr("snapshot"), Translation.tr("configuration"), Translation.tr("apply"), Translation.tr("delete"), Translation.tr("restore")]

            ConfigRow {
                MaterialTextArea {
                    id: presetNameField
                    Layout.fillWidth: true
                    placeholderText: "Name, description (optional)"
                    wrapMode: TextEdit.NoWrap
                    enabled: !Presets.busy

                    onTextChanged: {
                        if (page.pendingReplaceInput !== text)
                            page.pendingReplaceInput = "";
                        page.operationMessage = "";
                    }
                }

                ToolbarPairedFab {
                    visible: presetNameField.text.trim() !== "" && !Presets.busy
                    iconText: page.pendingReplaceInput === presetNameField.text ? "warning" : "save"
                    onClicked: page.savePreset(presetNameField.text)
                }
            }

            StyledText {
                Layout.fillWidth: true
                visible: page.operationMessage.length > 0
                text: page.operationMessage
                color: Appearance.colors.colError
                font.pixelSize: Appearance.font.pixelSize.small
            }

            StyledText {
                Layout.fillWidth: true
                Layout.topMargin: 40
                visible: Presets.folderModel.count === 0
                horizontalAlignment: Text.AlignHCenter
                text: Translation.tr("No presets yet")
                color: Appearance.colors.colSubtext
                font.pixelSize: Appearance.font.pixelSize.normal
            }

            Flow {
                Layout.topMargin: 10
                Layout.fillWidth: true
                width: parent.width
                spacing: 12
                visible: Presets.folderModel.count > 0

                Repeater {
                    model: Presets.folderModel

                    delegate: PresetsCard {
                        id: presetDelegate
                        required property string fileName
                        required property string filePath

                        property string presetName: fileName.replace(".json", "")
                        property string presetWallpaper: ""
                        property string presetDescription: ""

                        enabled: !Presets.busy

                        FileView {
                            path: presetDelegate.filePath
                            onLoaded: {
                                try {
                                    const data = JSON.parse(text());
                                    const rawWallpaper = data?.background?.wallpaperPath ?? "";
                                    const isVideo = /\.(mp4|webm|mkv|avi|mov)$/i.test(rawWallpaper);
                                    presetDelegate.presetWallpaper = isVideo
                                        ? (data?.background?.thumbnailPath ?? "")
                                        : rawWallpaper;
                                    presetDelegate.presetDescription = data?._presetMeta?.description ?? "";
                                } catch (e) {
                                    console.log("Failed to parse preset:", e);
                                }
                            }
                        }

                        imageSource: presetDelegate.presetWallpaper
                        title: presetDelegate.presetName
                        description: page.pendingDeleteName === presetDelegate.presetName
                            ? "Press Remove again to confirm"
                            : (presetDelegate.presetDescription !== "" ? presetDelegate.presetDescription : Translation.tr("Saved preset"))
                        onSave: () => {
                            page.pendingInputSaveName = "";
                            page.pendingDeleteName = "";
                            Presets.save(presetDelegate.presetName, presetDelegate.presetDescription, true);
                        }
                        onApply: () => {
                            page.pendingDeleteName = "";
                            Presets.apply(presetDelegate.presetName);
                        }
                        onRemove: () => {
                            if (page.pendingDeleteName === presetDelegate.presetName) {
                                Presets.remove(presetDelegate.presetName);
                                page.pendingDeleteName = "";
                            } else {
                                page.pendingDeleteName = presetDelegate.presetName;
                            }
                        }
                    }
                }
            }
        }
    }
}
