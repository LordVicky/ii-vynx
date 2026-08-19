pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common

Singleton {
    id: root

    property string filePath: `${Directories.shellConfig}/liquid-glass.json`
    property alias options: settingsAdapter
    property bool ready: false
    property int readWriteDelay: 75

    Timer {
        id: reloadTimer
        interval: root.readWriteDelay
        repeat: false
        onTriggered: settingsFile.reload()
    }

    Timer {
        id: writeTimer
        interval: root.readWriteDelay
        repeat: false
        onTriggered: settingsFile.writeAdapter()
    }

    FileView {
        id: settingsFile
        path: root.filePath
        watchChanges: true
        onFileChanged: if (!reloadTimer.running) reloadTimer.start()
        onAdapterUpdated: if (!writeTimer.running) writeTimer.start()
        onLoaded: root.ready = true
        onLoadFailed: error => {
            if (error == FileViewError.FileNotFound)
                writeAdapter();
        }

        JsonAdapter {
            id: settingsAdapter

            // QML surface treatment. These do not reconfigure HyprGlass.
            property real shellTint: 0
            property real brightness: 0

            // HyprGlass v0.7.0 default material values. blurStrength is exposed
            // directly as the compositor-side Glass blur control (2.0 = 100%).
            // refractionStrength backs the main Glass intensity slider: 0.6 =
            // 100%, and its ratio scales the independently adjustable optics.
            property real blurStrength: 2.0
            property real refractionStrength: 0.6
            property real chromaticAberration: 0.5
            property real fresnelStrength: 0.6
            property real specularStrength: 0.8
            property real edgeThickness: 0.06
            property real lensDistortion: 0.5
        }
    }
}
