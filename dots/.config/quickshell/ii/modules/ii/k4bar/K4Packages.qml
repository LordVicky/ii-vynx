pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common
import qs.modules.common.functions

// K4 package-search adapter adapted from k4ditano/k4 Launcher at the pinned
// source commit. Search is on-demand; pacman/yay remain the package databases.
// Interactive mutations run in Config.options.apps.terminal, matching ii's
// existing terminal-launch convention instead of hard-coding a terminal.
Singleton {
    id: root

    property string query: ""
    property var repoResults: []
    property var aurResults: []
    property var installedPackages: ({})
    property bool repoSearching: false
    property bool aurSearching: false
    property string repoRunningQuery: ""
    property string aurRunningQuery: ""

    readonly property bool searching: repoSearching || aurSearching
    readonly property var matches: {
        const q = packageQuery().toLowerCase()
        const scored = []
        const all = repoResults.concat(aurResults)

        for (let i = 0; i < all.length; ++i) {
            const pkg = all[i]
            const name = String(pkg.name || "").toLowerCase()
            let score = 3
            if (name === q) score = 0
            else if (name.indexOf(q) === 0) score = 1
            else if (name.indexOf(q) !== -1) score = 2

            scored.push({
                repo: pkg.repo,
                name: pkg.name,
                version: pkg.version,
                description: pkg.description,
                installed: installedPackages[pkg.name] === true,
                score: score + (pkg.repo === "aur" ? 4 : 0),
                order: i
            })
        }

        scored.sort((a, b) => {
            if (a.score !== b.score) return a.score - b.score
            return a.order - b.order
        })

        const seen = ({})
        const unique = []
        for (let i = 0; i < scored.length; ++i) {
            const pkg = scored[i]
            if (seen[pkg.name] === true) continue
            seen[pkg.name] = true
            unique.push(pkg)
        }
        return unique.slice(0, 60)
    }

    function packageQuery() {
        return String(query || "").replace(/[^A-Za-z0-9 _.+-]/g, "").trim()
    }

    function parsePackages(text, onlyAur) {
        const lines = String(text || "").split("\n")
        const packages = []
        let current = null

        for (let i = 0; i < lines.length; ++i) {
            const line = lines[i]
            if (!line.length) continue

            if (line.charAt(0) === " " || line.charAt(0) === "\t") {
                if (current && current.description.length === 0)
                    current.description = line.trim()
                continue
            }

            const match = line.match(/^([^\s\/]+)\/(\S+)\s+(\S+)/)
            if (!match) {
                current = null
                continue
            }
            if (onlyAur && match[1] !== "aur") {
                current = null
                continue
            }

            current = {
                repo: match[1],
                name: match[2],
                version: match[3],
                description: ""
            }
            packages.push(current)
        }
        return packages
    }

    function open(initial = "") {
        query = String(initial || "")
        refreshInstalled()
        scheduleSearch()
    }

    function reset() {
        repoTimer.stop()
        aurTimer.stop()
        repoProcess.running = false
        aurProcess.running = false
        repoSearching = false
        aurSearching = false
        repoResults = []
        aurResults = []
        query = ""
    }

    function search(value) {
        query = String(value || "")
        scheduleSearch()
    }

    function scheduleSearch() {
        repoTimer.restart()
        aurTimer.restart()
    }

    function refreshInstalled() {
        installedProcess.running = false
        installedProcess.command = ["pacman", "-Qq"]
        installedProcess.running = true
    }

    function runRepoSearch() {
        const q = packageQuery()
        if (q.length < 2) {
            repoProcess.running = false
            repoSearching = false
            repoResults = []
            return
        }

        repoProcess.running = false
        repoRunningQuery = q
        repoProcess.command = ["pacman", "-Ss", "--"].concat(q.split(/\s+/))
        repoSearching = true
        repoProcess.running = true
    }

    function runAurSearch() {
        const q = packageQuery()
        if (q.length < 2) {
            aurProcess.running = false
            aurSearching = false
            aurResults = []
            return
        }

        aurProcess.running = false
        aurRunningQuery = q
        aurProcess.command = ["yay", "-Ss", "--aur", "--color=never", "--"].concat(q.split(/\s+/))
        aurSearching = true
        aurProcess.running = true
    }

    function shellArgument(value) {
        return "'" + StringUtils.shellSingleQuoteEscape(String(value || "")) + "'"
    }

    function runInTerminal(script) {
        const terminal = String(Config.options.apps.terminal || "").trim()
        if (!terminal.length) return
        const escaped = StringUtils.shellSingleQuoteEscape(script)
        Quickshell.execDetached(["bash", "-lc", `${terminal} -e sh -lc '${escaped}'`])
    }

    function install(pkg) {
        if (!pkg || !pkg.name) return
        const name = shellArgument(pkg.name)
        const script =
            `yay -S --needed -- ${name}; rc=$?; ` +
            `if [ $rc -eq 0 ]; then notify-send -a 'K4 Packages' ${name} 'Installed successfully'; ` +
            `else notify-send -a 'K4 Packages' -u critical ${name} 'Installation failed'; fi; ` +
            `printf '\nPress Enter to close…'; read -r _; exit $rc`
        runInTerminal(script)
    }

    function uninstall(pkg) {
        if (!pkg || !pkg.name || pkg.installed !== true) return
        const name = shellArgument(pkg.name)
        const script =
            `sudo pacman -Rns --confirm -- ${name}; rc=$?; ` +
            `if [ $rc -eq 0 ]; then notify-send -a 'K4 Packages' ${name} 'Removed successfully'; ` +
            `else notify-send -a 'K4 Packages' -u critical ${name} 'Removal failed'; fi; ` +
            `printf '\nPress Enter to close…'; read -r _; exit $rc`
        runInTerminal(script)
    }

    Timer {
        id: repoTimer
        interval: 180
        onTriggered: root.runRepoSearch()
    }

    Timer {
        id: aurTimer
        interval: 500
        onTriggered: root.runAurSearch()
    }

    Process {
        id: installedProcess
        stdout: StdioCollector {
            onStreamFinished: {
                const installed = ({})
                const names = this.text.split("\n")
                for (let i = 0; i < names.length; ++i) {
                    const name = names[i].trim()
                    if (name.length) installed[name] = true
                }
                root.installedPackages = installed
            }
        }
    }

    Process {
        id: repoProcess
        stdout: StdioCollector {
            onStreamFinished: {
                if (root.repoRunningQuery !== root.packageQuery()) return
                root.repoResults = root.parsePackages(this.text, false)
                root.repoSearching = false
            }
        }
        onExited: function(code) {
            if (code !== 0 && root.repoRunningQuery === root.packageQuery()) {
                root.repoResults = []
                root.repoSearching = false
            }
        }
    }

    Process {
        id: aurProcess
        stdout: StdioCollector {
            onStreamFinished: {
                if (root.aurRunningQuery !== root.packageQuery()) return
                root.aurResults = root.parsePackages(this.text, true)
                root.aurSearching = false
            }
        }
        onExited: function(code) {
            if (code !== 0 && root.aurRunningQuery === root.packageQuery()) {
                root.aurResults = []
                root.aurSearching = false
            }
        }
    }
}
