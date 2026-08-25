import QtQuick
import Quickshell.Io

// Utility-grid ownership adapted from k4ditano/k4 Apps at the pinned source
// commit. The grid consumes the existing K4 plugin registry instead of owning
// a second catalog; future utility plugins opt in through K4Plugin.application.
K4Plugin {
    id: root

    name: "apps"
    title: "Applications"
    priority: 72
    configurable: false
    active: enabled && open
    viewLoaded: open
    grabKeyboard: open

    property bool open: false
    property string query: ""
    property int selection: 0
    property var controller: null

    readonly property int columns: 5
    readonly property var applications: {
        const source = controller ? controller.applicationPlugins() : []
        const normalized = query.trim().toLowerCase()
        if (normalized.length === 0)
            return source
        return source.filter(candidate => {
            const name = String(candidate?.title ?? candidate?.name ?? "").toLowerCase()
            const id = String(candidate?.name ?? candidate?.name ?? "").toLowerCase()
            return name.indexOf(normalized) >= 0 || id.indexOf(normalized) >= 0
        })
    }

    islandWidth: 700
    islandHeight: 520

    onQueryChanged: selection = 0
    onApplicationsChanged: {
        if (applications.length === 0)
            selection = 0
        else
            selection = Math.max(0, Math.min(selection, applications.length - 1))
    }

    function openGrid() {
        K4Panel.close()
        K4Notifications.dismissToast()
        query = ""
        selection = 0
        open = true
    }

    function toggle() {
        if (open)
            close()
        else
            openGrid()
    }

    function close() {
        if (!open)
            return
        open = false
        query = ""
        selection = 0
    }

    // Close first so the selected application can win arbitration even when it
    // has a lower priority than this 72-priority Apps surface.
    function launch(id) {
        close()
        if (controller)
            controller.openApplication(id)
    }

    function launchSelected() {
        if (selection < 0 || selection >= applications.length)
            return
        launch(applications[selection].name)
    }

    function move(dx, dy) {
        if (applications.length === 0)
            return
        const next = selection + dx + dy * columns
        selection = Math.max(0, Math.min(applications.length - 1, next))
    }

    IpcHandler {
        target: "k4.apps"
        function toggle(): void { root.toggle() }
        function open(): void { root.openGrid() }
        function close(): void { root.close() }
    }

    view: Component {
        K4AppsView { plugin: root }
    }
}
