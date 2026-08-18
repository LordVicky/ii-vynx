import QtQuick
import Quickshell.Io

QtObject {
    id: root

    property bool hyprGlassLoaded: false
    property bool probeComplete: false

    function probeHyprGlass() {
        if (hyprGlassProbe.running)
            return;

        root.probeComplete = false;
        hyprGlassProbe.running = true;
    }

    Component.onCompleted: root.probeHyprGlass()

    Process {
        id: hyprGlassProbe
        running: false
        command: ["hyprctl", "plugin", "list"]
        stdout: StdioCollector {
            id: hyprGlassOutput
        }
        onExited: (exitCode, exitStatus) => {
            root.hyprGlassLoaded = exitCode === 0
                && hyprGlassOutput.text.toLowerCase().includes("hyprglass");
            root.probeComplete = true;
        }
    }
}
