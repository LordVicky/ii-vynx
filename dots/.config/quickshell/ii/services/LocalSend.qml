pragma Singleton
pragma ComponentBehavior: Bound

import qs.modules.common
import QtQuick
import Quickshell
import Quickshell.Io

/**
 * LocalSend service for receiving/sending files via localsend-cli.
 * Monitors incoming file transfers, scans for devices, and sends files.
 * 
 * Note for the process':
 * I have no idea why, but we have to use bash -lc and also set the PATH environment variable manually
 * Or else it cannot detect localsend-cli and cannot use it's functionalities. 
 * The stupid part is that when we run the shell from the terminal "qs -c ii", everything works perfectly fine without the need of "bash -lc" or setting the PATH. 
 * But it doesnt work when we run it from the keybind. So it may be the problem of the lua integration of hyprland or pip's installation path idk.
 */
Singleton {
    id: root

    readonly property bool serviceEnabled: Config.ready && (Config.options?.localsend?.enable ?? true)
    property bool available: false
    property bool serverRunning: receiveProc.running
    property bool autoStart: Config.options?.localsend?.autoStart ?? false
    property string downloadPath: Config.options?.localsend?.downloadPath
    property bool showNotifications: Config.options?.localsend?.showNotifications ?? true

    // Receive state
    property var currentTransfer: null
    property list<var> pendingTransfers: []

    // Send state
    property list<var> droppedFiles: []
    property list<var> discoveredDevices: []
    property bool sending: false

    signal transferRequested(var transfer)
    signal transferStarted(var transfer)
    signal transferCompleted(var transfer)
    signal transferCancelled(var transfer)
    signal serverStarted()
    signal serverStopped()
    signal sendCompleted()
    signal sendFailed(string message)

    function isReady(): bool {
        return Config.ready && root.serviceEnabled
    }

    function addDroppedFile(fileUrl: string): void {
        if (!root.serviceEnabled) return

        const cleanPath = fileUrl.toString().replace(/^file:\/\//, "")
        const name = cleanPath.split("/").pop() || "unknown"
        for (let i = 0; i < root.droppedFiles.length; i++) {
            if (root.droppedFiles[i].path === cleanPath) return
        }
        const newList = root.droppedFiles.slice()
        newList.push({ path: cleanPath, name: name, size: 0 })
        root.droppedFiles = newList
    }

    function removeDroppedFile(index: int): void {
        const newList = root.droppedFiles.slice()
        newList.splice(index, 1)
        root.droppedFiles = newList
    }

    function clearDroppedFiles(): void {
        root.droppedFiles = []
    }

    function formatFileSize(bytes: int): string {
        if (bytes < 1024) return bytes + " B"
        if (bytes < 1024 * 1024) return (bytes / 1024).toFixed(1) + " KB"
        return (bytes / (1024 * 1024)).toFixed(1) + " MB"
    }

    function sendToDevice(deviceIp: string): void {
        if (!root.serviceEnabled || !root.available || root.sending || root.droppedFiles.length === 0) return
        root.sending = true
        const filePaths = root.droppedFiles.map(f => f.path)
        sendProc.command = ["bash", "-lc",`localsend-cli send ${deviceIp} ${filePaths.join(" ")} --json`]
        sendProc.running = true
    }

    function cancelSend(): void {
        sendProc.running = false
        root.sending = false
    }

    onServiceEnabledChanged: {
        serverStartDelayTimer.stop()
        restartDelayTimer.stop()

        if (!root.serviceEnabled) {
            checkAvailabilityProc.running = false
            notificationProc.running = false
            sendProc.running = false
            receiveProc.running = false
            root.sending = false
            root.available = false
            root.currentTransfer = null
            root.pendingTransfers = []
            root.discoveredDevices = []
            return
        }

        checkAvailabilityProc.running = true
    }

    Component.onCompleted: {
        if (root.serviceEnabled && !checkAvailabilityProc.running)
            checkAvailabilityProc.running = true
    }

    // Check if localsend-cli is available
    Process {
        id: checkAvailabilityProc
        running: false
        command: ["bash", "-lc", "which localsend-cli"]
        environment: ({
            "PATH": Directories.home + "/.local/bin:/usr/local/bin:/usr/bin:/bin"
        })
        onExited: (exitCode, exitStatus) => {
            if (!root.serviceEnabled) {
                root.available = false
                return
            }

            root.available = (exitCode === 0)
            if (root.available && root.autoStart) {
                Qt.callLater(() => {
                    if (root.serviceEnabled) root.startServer()
                })
            }
        }
    }

    // Notification process for incoming transfers
    Process {
        id: notificationProc
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                if (!root.serviceEnabled || this.text === "") return
                const action = this.text.trim()
                console.log("[LocalSend] Notification action received:", action)
                if (action === "accept") {
                    root.acceptTransfer()
                } else if (action === "deny") {
                    root.denyTransfer()
                }
            }
        }
    }

    function showIncomingNotification(transfer: var): void {
        if (!root.serviceEnabled) return

        const fileNames = transfer.files.map(f => f.name).join(", ")
        const fileSizes = transfer.files.map(f => {
            const size = f.size || 0
            if (size < 1024) return size + " B"
            if (size < 1024 * 1024) return (size / 1024).toFixed(1) + " KB"
            return (size / (1024 * 1024)).toFixed(1) + " MB"
        }).join(", ")

        notificationProc.command = [
            "notify-send",
            Translation.tr("LocalSend: Incoming Transfer"),
            Translation.tr("From: %1\nCheck the clock widget popup on the bar for more information").arg(transfer.sender),
            "-A", `accept=${Translation.tr("Accept")}`,
            "-A", `deny=${Translation.tr("Deny")}`,
            "-a", "LocalSend",
        ]
        notificationProc.running = true
    }

    // Main receive server process
    Process {
        id: receiveProc
        running: false
        stdinEnabled: true

        environment: ({
            "PATH": Directories.home + "/.local/bin:/usr/local/bin:/usr/bin:/bin"
        })

        stdout: SplitParser {
            onRead: line => {
                if (!root.serviceEnabled || !line || line.trim().length === 0) return
                try {
                    const event = JSON.parse(line)
                    root.handleLocalSendEvent(event)
                } catch (e) {
                    console.error("[LocalSend] Failed to parse JSON:", line, e)
                }
            }
        }

        stderr: SplitParser {
            onRead: line => {
                if (root.serviceEnabled) console.log("[LocalSend] stderr:", line)
            }
        }

        onExited: (exitCode, exitStatus) => {
            console.log("[LocalSend] Server stopped with exit code:", exitCode)
            root.serverStopped()
        }
    }

    // Send process for sending files to a device
    Process {
        id: sendProc
        running: false

        environment: ({
            "PATH": Directories.home + "/.local/bin:/usr/local/bin:/usr/bin:/bin"
        })

        stdout: SplitParser {
            onRead: line => {
                if (!root.serviceEnabled || !line || line.trim().length === 0) return
                console.log("[LocalSend] Send progress:", line)
                try {
                    const event = JSON.parse(line)
                    if (event.event === "completed" || event.event === "saved" || event.event === "done") {
                        root.clearDroppedFiles()
                        root.sendCompleted()
                    } else if (event.event === "cancelled" || event.error) {
                        root.sendFailed(event.error || "Transfer cancelled")
                    }
                } catch (e) {
                    console.log("[LocalSend] Failed to parse send line:", line, e)
                }
            }
        }

        stderr: SplitParser {
            onRead: line => {
                if (root.serviceEnabled) console.log("[LocalSend] Send stderr:", line)
            }
        }

        onExited: (exitCode, exitStatus) => {
            root.sending = false
            if (root.serviceEnabled && exitCode !== 0) {
                root.sendFailed("Send process exited with code: " + exitCode)
            }
        }
    }

    function handleLocalSendEvent(event: var): void {
        if (!root.serviceEnabled || !event || !event.event) return
        console.log("[LocalSend] Event:", JSON.stringify(event))

        switch (event.event) {
            case "ready":
                root.serverStarted()
                break

            case "device":
                console.log("[LocalSend] Device registered:", event.alias, event.ip)
                if (event.ip) {
                    const newList = root.discoveredDevices.slice()
                    let found = false
                    for (let i = 0; i < newList.length; i++) {
                        if (newList[i].ip === event.ip) { found = true; break }
                    }
                    if (!found) {
                        newList.push({
                            ip: event.ip,
                            name: event.alias || event.name || "Unknown",
                            port: event.port || 53317
                        })
                        root.discoveredDevices = newList
                    }
                }
                break

            case "incoming":
                const transfer = {
                    sender: event.sender || "Unknown",
                    senderIp: event.ip || "",
                    files: event.files || [],
                    isText: event.is_text || false,
                    sessionId: ""
                }
                root.currentTransfer = transfer
                root.pendingTransfers.push(transfer)
                root.transferRequested(transfer)
                break

            case "prompt":
                console.log("[LocalSend] Prompt received, showing notification")
                if (root.currentTransfer && root.showNotifications) {
                    root.showIncomingNotification(root.currentTransfer)
                }
                break

            case "text":
                const textTransfer = {
                    sender: event.sender || "Unknown",
                    text: event.text || "",
                    timestamp: Date.now()
                }
                root.transferCompleted(textTransfer)
                if (root.showNotifications) {
                    Quickshell.execDetached([
                        "notify-send",
                        Translation.tr("LocalSend: Text Received"),
                        Translation.tr("From: %1\n%2").arg(event.sender || "Unknown").arg(event.text || ""),
                        "-a", "LocalSend",
                    ])
                }
                root.currentTransfer = null
                break

            case "saved":
                console.log("[LocalSend] File saved:", event.path || "unknown path")
                const fileTransfer = {
                    sender: event.sender || "Unknown",
                    fileName: event.name || "",
                    filePath: event.path || root.downloadPath + "/" + (event.name || ""),
                    fileSize: event.size || 0,
                    timestamp: Date.now()
                }
                root.transferCompleted(fileTransfer)
                if (root.showNotifications) {
                    Quickshell.execDetached([
                        "notify-send",
                        Translation.tr("LocalSend: File Received"),
                        Translation.tr("From: %1\nOutput path: %2").arg(event.sender || "Unknown").arg(event.path || "unknown path"),
                        "-a", "LocalSend",
                    ])
                }
                root.currentTransfer = null
                break

            case "cancelled":
                root.transferCancelled(event)
                root.currentTransfer = null
                break
        }
    }
    
    Timer {
        id: serverStartDelayTimer
        interval: 500
        onTriggered: {
            if (!root.serviceEnabled || !root.available) return
            receiveProc.command = ["bash", "-lc", `localsend-cli receive --interactive-json --output ${root.downloadPath}`]
            console.log("[LocalSend] Starting receive server with output dir:", root.downloadPath)
            receiveProc.running = true
        }
    }

    function startServer(): void {
        if (!root.serviceEnabled) {
            console.log("[LocalSend] Service disabled; refusing to start receiver")
            return
        }
        if (!root.available) {
            Quickshell.execDetached(["notify-send", Translation.tr("LocalSend Error"), Translation.tr("localsend-cli is not available. You can install it with <tt>pip install localsend-cli</tt>. Check the docs for further details."), "-a", "LocalSend"])
            console.warn("[LocalSend] localsend-cli is not available")
            return
        }
        if (receiveProc.running) {
            console.log("[LocalSend] Server is already running")
            return
        }

        serverStartDelayTimer.restart()
    }

    function stopServer(): void {
        serverStartDelayTimer.stop()
        restartDelayTimer.stop()
        console.log("[LocalSend] Stopping receive server...")
        receiveProc.running = false
    }

    function restartServer(): void {
        if (!root.serviceEnabled) {
            root.stopServer()
            return
        }

        if (receiveProc.running) {
            console.log("[LocalSend] Restarting server...")
            receiveProc.running = false
            // Wait for process to stop, then start again
            restartDelayTimer.restart()
        } else if (root.available) {
            root.startServer()
        }
    }

    Timer {
        id: restartDelayTimer
        interval: 2000 // 2 seconds delay
        repeat: false
        onTriggered: {
            if (!root.serviceEnabled) return
            console.log("[LocalSend] Restarting server after delay...")
            root.startServer()
        }
    }

    function acceptTransfer(): void {
        if (!root.serviceEnabled || !receiveProc.running) return
        console.log("[LocalSend] Accepting transfer...")
        receiveProc.write("y\n")
        root.currentTransfer = null
    }

    function denyTransfer(): void {
        if (!root.serviceEnabled || !receiveProc.running) return
        console.log("[LocalSend] Denying transfer...")
        root.currentTransfer = null
        receiveProc.write("n\n")
    }

    function getPendingTransfers(): list<var> {
        return root.pendingTransfers
    }

    function clearPendingTransfers(): void {
        root.pendingTransfers = []
    }

    onDownloadPathChanged: {
        // Restart server if download path changed while running
        if (root.serviceEnabled && receiveProc.running) {
            console.log("[LocalSend] Download path changed, restarting server...")
            root.restartServer()
        }
    }

    IpcHandler {
        target: "localsend"

        function start(): void {
            root.startServer()
        }

        function stop(): void {
            root.stopServer()
        }

        function status(): string {
            return JSON.stringify({
                enabled: root.serviceEnabled,
                available: root.available,
                running: root.serverRunning,
                downloadPath: root.downloadPath
            })
        }
    }
}
