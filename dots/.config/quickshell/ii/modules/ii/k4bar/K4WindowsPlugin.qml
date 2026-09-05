import QtQuick
import Quickshell.Io

// Windows V2 keeps one native Wayland-backed surface with two entry modes:
// Super+Tab opens the workspace overview, while Alt+Tab opens a transient
// windows-only switcher. Client ownership remains in ii-vynx HyprlandData.
K4Plugin {
    id: root

    name: "windows"
    title: "Windows"
    priority: 83
    application: true
    applicationGlyph: String.fromCodePoint(0xF05B2)
    active: enabled && open
    viewLoaded: open
    grabKeyboard: open

    property bool open: false
    property string mode: "overview" // "overview" | "switcher"
    property int index: 0
    property int selectedWorkspaceId: -1
    // Session preference intentionally lives on the long-lived plugin so the
    // in-view toggle affects every subsequent Alt+Tab until Quickshell restarts.
    property bool altTabCurrentWorkspaceOnly: false

    readonly property bool showWorkspaces: mode === "overview"
    readonly property var entries: showWorkspaces
        ? K4Windows.windowsForWorkspace(selectedWorkspaceId)
        : K4Windows.switcherWindows(altTabCurrentWorkspaceOnly)
    readonly property var otherEntries: showWorkspaces
        ? K4Windows.windowsOutsideWorkspace(selectedWorkspaceId) : []
    readonly property int count: entries.length

    // Window previews are the primary content here, so give them substantially
    // more room than the first V2 pass. K4's global widthScale still applies on
    // top of these intrinsic dimensions.
    islandWidth: showWorkspaces
        ? 1120
        : Math.min(1120, Math.max(520, 80 + Math.min(count, 4) * 260))
    islandHeight: showWorkspaces ? 560 : 320

    function prepare() {
        K4Windows.refresh()
        K4Panel.close()
        K4Notifications.dismissToast()
    }

    function openOverview() {
        if (!enabled)
            return
        prepare()
        mode = "overview"
        selectedWorkspaceId = K4Workspaces.activeId > 0
            ? K4Workspaces.activeId
            : (K4Workspaces.list[0]?.id ?? -1)
        index = 0
        open = true
    }

    function occupiedWorkspaceIds() {
        return K4Workspaces.overviewList
            .map(workspace => Number(workspace?.id ?? -1))
            .filter(id => isFinite(id) && id > 0
                && K4Windows.windowCountForWorkspace(id) > 0)
    }

    function cycleOverviewWorkspace(direction = 1) {
        const ids = occupiedWorkspaceIds()
        if (ids.length === 0)
            return

        const step = direction < 0 ? -1 : 1
        const current = ids.indexOf(selectedWorkspaceId)
        if (current >= 0) {
            selectWorkspace(ids[(current + step + ids.length) % ids.length])
            return
        }

        if (step > 0) {
            for (let i = 0; i < ids.length; ++i) {
                if (ids[i] > selectedWorkspaceId) {
                    selectWorkspace(ids[i])
                    return
                }
            }
            selectWorkspace(ids[0])
            return
        }

        for (let i = ids.length - 1; i >= 0; --i) {
            if (ids[i] < selectedWorkspaceId) {
                selectWorkspace(ids[i])
                return
            }
        }
        selectWorkspace(ids[ids.length - 1])
    }

    function toggleOverview() {
        if (open && mode === "overview") {
            cycleOverviewWorkspace(1)
            return
        }
        openOverview()
    }

    function openSwitcher(direction = 1) {
        if (!enabled)
            return
        prepare()
        mode = "switcher"
        selectedWorkspaceId = K4Workspaces.activeId
        const rows = K4Windows.switcherWindows(altTabCurrentWorkspaceOnly)
        if (rows.length === 0) {
            open = false
            return
        }
        if (rows.length === 1)
            index = 0
        else
            index = direction < 0 ? rows.length - 1 : 1
        open = true
    }

    function triggerSwitcher(direction = 1) {
        if (!open || mode !== "switcher") {
            openSwitcher(direction)
            return
        }
        if (direction < 0)
            retreat()
        else
            advance()
    }

    function selectWorkspace(workspaceId) {
        const id = Number(workspaceId)
        if (!isFinite(id) || id <= 0)
            return
        selectedWorkspaceId = id
        index = 0
    }

    function setAltTabCurrentWorkspaceOnly(value) {
        altTabCurrentWorkspaceOnly = Boolean(value)
        index = Math.max(0, Math.min(index, count - 1))
    }

    function openApplication() {
        if (!enabled)
            return false
        openOverview()
        return open
    }

    function close() {
        open = false
    }

    function toggle() {
        toggleOverview()
    }

    function advance() {
        if (count > 0)
            index = (index + 1) % count
    }

    function retreat() {
        if (count > 0)
            index = (index - 1 + count) % count
    }

    function chooseWindow(row) {
        if (!row)
            return
        close()
        K4Windows.activate(row)
    }

    function choose() {
        chooseWindow(entries[index])
    }

    function closeCurrent() {
        const row = entries[index]
        if (!row)
            return
        K4Windows.close(row)
        index = Math.max(0, Math.min(index, count - 2))
    }

    onCountChanged: {
        if (mode === "switcher" && open && count === 0)
            close()
        else if (index >= count)
            index = Math.max(0, count - 1)
    }

    Component.onCompleted: K4Windows.plugin = root
    Component.onDestruction: {
        if (K4Windows.plugin === root)
            K4Windows.plugin = null
    }

    IpcHandler {
        target: "k4.windows"
        function toggle(): void { root.toggleOverview() }
        function open(): void { root.openOverview() }
        function overview(): void { root.openOverview() }
        function switcher(): void { root.openSwitcher(1) }
        function close(): void { root.close() }
        function next(): void { root.advance() }
        function previous(): void { root.retreat() }
        function focus(index: int): void {
            root.index = Math.max(0, Math.min(root.count - 1, index))
            root.choose()
        }
    }

    view: Component { K4WindowsView { plugin: root } }
}
