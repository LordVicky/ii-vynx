import QtQuick
import Quickshell.Io

// Session menu adapted from pinned k4 SessionPlugin. The lock-screen protocol
// itself is intentionally not ported: ii-vynx already owns it via Lock.qml.
K4Plugin {
    id: root

    name: "session"
    title: "Session"
    priority: 86
    application: true
    applicationGlyph: String.fromCodePoint(0xF0425)
    active: enabled && open
    viewLoaded: open
    grabKeyboard: open

    property bool open: false
    property int index: 0
    property int confirming: -1
    readonly property var actions: K4Session.actions
    readonly property int count: actions.length

    islandWidth: Math.min(760, 40 + count * 118)
    islandHeight: 200

    function openSession() {
        K4Panel.close()
        K4Notifications.dismissToast()
        index = 0
        confirming = -1
        open = true
    }
    function openApplication() {
        if (!enabled) return false
        openSession()
        return true
    }
    function close() { open = false; confirming = -1 }
    function toggle() { open ? close() : openSession() }
    function advance() { if (count > 0) { index = (index + 1) % count; confirming = -1 } }
    function retreat() { if (count > 0) { index = (index - 1 + count) % count; confirming = -1 } }
    function execute(i) {
        const action = actions[i]
        if (!action) return
        if (action.confirm && confirming !== i) {
            index = i
            confirming = i
            return
        }
        close()
        K4Session.run(action.key)
    }
    function choose() { execute(index) }

    onCountChanged: if (index >= count) index = Math.max(0, count - 1)

    IpcHandler {
        target: "k4.session"
        function toggle(): void { root.toggle() }
        function open(): void { root.openSession() }
        function close(): void { root.close() }
        function lock(): void { K4Session.run("lock") }
        function suspend(): void { K4Session.run("suspend") }
    }

    view: Component { K4SessionView { plugin: root } }
}
