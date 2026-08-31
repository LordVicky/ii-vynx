import QtQuick
import Quickshell
import Quickshell.Io
import qs
import qs.modules.common

// K4-facing capture utility. Screenshot/recording ownership stays with the
// existing ii RegionSelector and record.sh paths; this plugin only presents
// those actions inside the island.
K4Plugin {
    id: root

    name: "capture"
    title: "Capture"
    priority: 84
    application: true
    applicationGlyph: String.fromCodePoint(0xF0379)
    active: enabled && open
    viewLoaded: open
    grabKeyboard: open

    property bool open: false
    property int selection: 0
    property bool ownsSuppression: false
    property var pendingCommand: []
    property string pendingRestore: ""

    readonly property bool recording: Persistent.states.screenRecord.active
    readonly property int recordingSeconds: Persistent.states.screenRecord.seconds
    readonly property string recordingDuration: {
        const seconds = Math.max(0, recordingSeconds)
        const minutes = Math.floor(seconds / 60)
        const remainder = seconds % 60
        return (minutes < 10 ? "0" : "") + minutes + ":"
            + (remainder < 10 ? "0" : "") + remainder
    }

    islandWidth: 520
    islandHeight: recording ? 258 : 220

    function openCapture() {
        K4Panel.close()
        K4Notifications.dismissToast()
        selection = 0
        open = true
    }

    function openApplication() {
        if (!enabled)
            return false
        openCapture()
        return true
    }

    function toggle() {
        if (open)
            close()
        else
            openCapture()
    }

    function close() {
        open = false
        selection = 0
    }

    function regionCommand(action) {
        return ["qs", "-p", Quickshell.shellPath(""),
            "ipc", "call", "region", action]
    }

    // Only release suppression that this plugin acquired. Capture can be
    // invoked while another owner has already hidden the island.
    function beginSuppression() {
        if (IslandState.hidden)
            return
        ownsSuppression = true
        IslandState.hidden = true
    }

    function releaseSuppression() {
        if (!ownsSuppression)
            return
        ownsSuppression = false
        IslandState.hidden = false
    }

    function launchSuppressed(command, restoreMode) {
        launchDelay.stop()
        regionRestore.stop()
        screenRestore.stop()
        releaseSuppression()
        beginSuppression()
        pendingCommand = command
        pendingRestore = restoreMode
        close()
        launchDelay.restart()
    }

    function screenshotRegion() {
        launchSuppressed(regionCommand("screenshot"), "region")
    }

    function screenshotScreen() {
        launchSuppressed(["bash", "-c", "grim - | wl-copy"], "screen")
    }

    function recordRegion() {
        if (recording)
            return
        close()
        Quickshell.execDetached(regionCommand("recordWithSound"))
    }

    function recordScreen() {
        if (recording)
            return
        close()
        Quickshell.execDetached([Directories.recordScriptPath,
            "--fullscreen", "--sound"])
    }

    function stopRecording() {
        if (!recording)
            return
        close()
        // record.sh owns wf-recorder lifecycle and treats a bare invocation as
        // stop when a recording is active.
        Quickshell.execDetached([Directories.recordScriptPath])
    }

    function trigger(index) {
        switch (index) {
        case 0: screenshotRegion(); break
        case 1: screenshotScreen(); break
        case 2: recordRegion(); break
        case 3: recordScreen(); break
        }
    }

    function move(dx, dy) {
        const next = selection + dx + dy * 2
        selection = Math.max(0, Math.min(3, next))
    }

    Timer {
        id: launchDelay
        interval: 90
        onTriggered: {
            if (root.pendingCommand.length === 0) {
                root.releaseSuppression()
                return
            }
            Quickshell.execDetached(root.pendingCommand)
            root.pendingCommand = []
            if (root.pendingRestore === "region")
                regionRestore.restart()
            else
                screenRestore.restart()
            root.pendingRestore = ""
        }
    }

    // RegionSelection freezes its own frame as it opens. Keep K4 hidden long
    // enough for that existing owner to take the frozen frame, then return the
    // island while the user is choosing the region.
    Timer {
        id: regionRestore
        interval: 900
        onTriggered: root.releaseSuppression()
    }

    Timer {
        id: screenRestore
        interval: 500
        onTriggered: root.releaseSuppression()
    }

    IpcHandler {
        target: "k4.capture"
        function toggle(): void { root.toggle() }
        function open(): void { root.openCapture() }
        function close(): void { root.close() }
        function screenshotRegion(): void { root.screenshotRegion() }
        function screenshotScreen(): void { root.screenshotScreen() }
        function recordRegion(): void { root.recordRegion() }
        function recordScreen(): void { root.recordScreen() }
        function stopRecording(): void { root.stopRecording() }
    }

    Component.onDestruction: releaseSuppression()

    view: Component { K4CaptureView { plugin: root } }
}
