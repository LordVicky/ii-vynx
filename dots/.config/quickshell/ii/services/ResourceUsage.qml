pragma Singleton
pragma ComponentBehavior: Bound

import qs.modules.common
import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Polled resource usage service with RAM, swap, CPU, disk, and temperature data.
 *
 * Recurring work is demand-driven. The desktop resource widget contributes
 * resourceWidgetInstances while it is loaded; the overlay resource widget
 * contributes overlayResourceWidgetInstances only while it is actually visible.
 * Config.options.resources.enable is the global master switch for all polling.
 */
Singleton {
    id: root

    property real memoryTotal: 1
    property real memoryFree: 0
    property real memoryUsed: memoryTotal - memoryFree
    property real memoryUsedPercentage: memoryUsed / memoryTotal
    property real swapTotal: 1
    property real swapFree: 0
    property real swapUsed: swapTotal - swapFree
    property real swapUsedPercentage: swapTotal > 0 ? (swapUsed / swapTotal) : 0
    property real diskTotal: 1
    property real diskUsed: 0
    property real diskUsedPercentage: diskTotal > 0 ? (diskUsed / diskTotal) : 0
    property real cpuUsage: 0
    property var previousCpuStats
    property string cpuModel: "Unknown CPU"
    property string cpuFreq: "-- MHz"
    property string cpuTemp: "--°C"

    // Desktop instances are managed by ResourcesWidget.qml. Overlay instances
    // are registered only while the overlay resource widget is visible/pinned.
    property int resourceWidgetInstances: 0
    property int overlayResourceWidgetInstances: 0
    readonly property bool serviceEnabled: Config.options.resources.enable
    readonly property bool pollingActive: root.serviceEnabled
        && (root.resourceWidgetInstances > 0 || root.overlayResourceWidgetInstances > 0)
    property bool _pollingStarted: false

    property string maxAvailableMemoryString: kbToGbString(root.memoryTotal)
    property string maxAvailableSwapString: kbToGbString(root.swapTotal)
    property string maxAvailableCpuString: "--"

    readonly property int historyLength: Config?.options.resources.historyLength ?? 60
    property list<real> cpuUsageHistory: []
    property list<real> memoryUsageHistory: []
    property list<real> swapUsageHistory: []

    function kbToGbString(kb) {
        return (kb / (1024 * 1024)).toFixed(1) + " GB";
    }

    function registerOverlayResourceConsumer() {
        root.overlayResourceWidgetInstances += 1;
    }

    function unregisterOverlayResourceConsumer() {
        root.overlayResourceWidgetInstances = Math.max(
            0, root.overlayResourceWidgetInstances - 1);
    }

    function updateMemoryUsageHistory() {
        memoryUsageHistory = [...memoryUsageHistory, memoryUsedPercentage];
        if (memoryUsageHistory.length > historyLength)
            memoryUsageHistory.shift();
    }

    function updateSwapUsageHistory() {
        swapUsageHistory = [...swapUsageHistory, swapUsedPercentage];
        if (swapUsageHistory.length > historyLength)
            swapUsageHistory.shift();
    }

    function updateCpuUsageHistory() {
        cpuUsageHistory = [...cpuUsageHistory, cpuUsage];
        if (cpuUsageHistory.length > historyLength)
            cpuUsageHistory.shift();
    }

    function updateHistories() {
        updateMemoryUsageHistory();
        updateSwapUsageHistory();
        updateCpuUsageHistory();
    }

    function sampleCoreResources(recordHistory = true) {
        if (!root.serviceEnabled)
            return;

        fileMeminfo.reload();
        fileStat.reload();

        const textMeminfo = fileMeminfo.text();
        memoryTotal = Number(textMeminfo.match(/MemTotal: *(\d+)/)?.[1] ?? 1);
        memoryFree = Number(textMeminfo.match(/MemAvailable: *(\d+)/)?.[1] ?? 0);
        swapTotal = Number(textMeminfo.match(/SwapTotal: *(\d+)/)?.[1] ?? 1);
        swapFree = Number(textMeminfo.match(/SwapFree: *(\d+)/)?.[1] ?? 0);

        const textStat = fileStat.text();
        const cpuLine = textStat.match(
            /^cpu\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)/);
        let cpuSampleReady = false;
        if (cpuLine) {
            const stats = cpuLine.slice(1).map(Number);
            const total = stats.reduce((a, b) => a + b, 0);
            const idle = stats[3];

            if (previousCpuStats) {
                const totalDiff = total - previousCpuStats.total;
                const idleDiff = idle - previousCpuStats.idle;
                cpuUsage = totalDiff > 0 ? (1 - idleDiff / totalDiff) : 0;
                cpuSampleReady = true;
            }
            previousCpuStats = { total, idle };
        }

        fileCpuInfo.reload();
        const textCpu = fileCpuInfo.text();
        if (root.cpuModel === "Unknown CPU" && textCpu.length > 0) {
            const modelMatch = textCpu.match(/model name\s+:\s+(.*)/);
            if (modelMatch) {
                root.cpuModel = modelMatch[1]
                    .replace(/\(.*?\)/g, "")
                    .replace(/with.*$/i, "")
                    .replace(/@\s*[\d.]+\s*GHz/i, "")
                    .replace(/\b\d+-Core\b/gi, "")
                    .replace(/\b\d+\s*Cores?\b/gi, "")
                    .replace(/\bCPU\b/gi, "")
                    .replace(/\bProcessor\b/gi, "")
                    .replace(/\s+/g, " ")
                    .trim();
            }
        }

        const freqMatch = textCpu.match(/cpu MHz\s+:\s+([\d.]+)/);
        if (freqMatch)
            root.cpuFreq = parseInt(freqMatch[1]) + " MHz";

        // Histories advance only after a valid CPU delta. This keeps all three
        // series aligned and avoids inserting a CPU average spanning suspension.
        if (recordHistory && cpuSampleReady)
            root.updateHistories();
    }

    function resumePolling() {
        if (root._pollingStarted || !root.pollingActive)
            return;

        root._pollingStarted = true;

        // A CPU delta across a long suspended interval would represent the
        // whole hidden period, not current usage. Seed a fresh baseline now and
        // take a short second sample before normal cadence resumes.
        root.previousCpuStats = undefined;
        root.sampleCoreResources(false);
        resumeCpuSampleTimer.restart();

        if (root.maxAvailableCpuString === "--" && !findCpuMaxFreqProc.running)
            findCpuMaxFreqProc.running = true;
        if (!diskProc.running)
            diskProc.running = true;
        if (!tempProc.running)
            tempProc.running = true;
    }

    function suspendPolling() {
        root._pollingStarted = false;
        resumeCpuSampleTimer.stop();
        root.previousCpuStats = undefined;
    }

    onPollingActiveChanged: {
        if (root.pollingActive)
            root.resumePolling();
        else
            root.suspendPolling();
    }

    Timer {
        id: resourceTimer
        interval: root.resourceWidgetInstances > 0
            ? (Config.options.background.widgets.resources.pollingInterval ?? 3000)
            : (Config.options?.resources?.updateInterval ?? 3000)
        running: root.pollingActive
        repeat: true
        onTriggered: root.sampleCoreResources(true)
    }

    Timer {
        id: resumeCpuSampleTimer
        interval: 250
        repeat: false
        onTriggered: {
            if (root.pollingActive)
                root.sampleCoreResources(true);
        }
    }

    FileView { id: fileMeminfo; path: "/proc/meminfo" }
    FileView { id: fileStat; path: "/proc/stat" }
    FileView { id: fileCpuInfo; path: "/proc/cpuinfo" }

    Process {
        id: findCpuMaxFreqProc
        environment: ({
            LANG: "C",
            LC_ALL: "C"
        })
        command: ["bash", "-c", "lscpu | grep 'CPU max MHz' | awk '{print $4}'"]
        stdout: StdioCollector {
            id: outputCollector
            onStreamFinished: {
                const maxMhz = parseFloat(outputCollector.text);
                if (Number.isFinite(maxMhz))
                    root.maxAvailableCpuString = (maxMhz / 1000).toFixed(0) + " GHz";
            }
        }
    }

    Process {
        id: diskProc
        command: ["bash", "-c", "df -k / | awk 'NR==2{print $2, $3}'"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.length > 0) {
                    const parts = text.trim().split(/\s+/);
                    if (parts.length === 2) {
                        root.diskTotal = parseInt(parts[0]);
                        root.diskUsed = parseInt(parts[1]);
                    }
                }
            }
        }
    }

    Timer {
        interval: 60000
        running: root.pollingActive
        repeat: true
        onTriggered: {
            if (!diskProc.running)
                diskProc.running = true;
        }
    }

    Process {
        id: tempProc
        command: ["bash", "-c", "sensors | awk '/Tctl:/ {print $2}; /Package id 0:/ {print $4}' | head -1 | tr -d '+' | cut -d'.' -f1"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.length > 0)
                    root.cpuTemp = text.trim() + "°C";
            }
        }
    }

    Timer {
        interval: 3000
        running: root.pollingActive
        repeat: true
        onTriggered: {
            if (!tempProc.running)
                tempProc.running = true;
        }
    }

    Component.onCompleted: {
        if (root.pollingActive)
            root.resumePolling();
    }
}
