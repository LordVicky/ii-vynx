pragma Singleton

import Quickshell
import qs.modules.common
import qs.modules.common.functions
import qs.services

// Thin presentation adapter for k4 launcher views. Installed-application
// ownership stays in ii-vynx's existing AppSearch pipeline.
Singleton {
    id: root

    readonly property int resultLimit: 40

    function search(query) {
        const normalized = String(query || "").trim()
        const source = normalized.length > 0
            ? AppSearch.fuzzyQuery(normalized)
            : Array.from(AppSearch.list)
        const visible = source.filter(entry => entry && !entry.noDisplay)

        if (normalized.length === 0) {
            visible.sort((a, b) => String(a.name || "").localeCompare(
                String(b.name || "")))
        }

        return visible.slice(0, resultLimit)
    }

    function launch(entry) {
        if (!entry)
            return

        // Reuse the same DesktopEntry launch semantics as ii's LauncherSearch.
        if (!entry.runInTerminal) {
            entry.execute()
            return
        }

        const command = entry.command ?? []
        Quickshell.execDetached([
            "bash",
            "-c",
            `${Config.options.apps.terminal} -e '${StringUtils.shellSingleQuoteEscape(command.join(" "))}'`
        ])
    }
}
