pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Mpris

// k4 media contract adapted to ii-vynx's existing Quickshell MPRIS owner.
// Copyright (c) 2026 k4ditano — MIT, see licenses/k4-NOTICE.txt.
Singleton {
    id: root

    // Keep this direct and reactive. K4-02 runtime validation demonstrated that
    // MprisController.activePlayer can retain a stale player after the final
    // client exits, while the live MPRIS list has the lifecycle k4 expects.
    readonly property var activePlayer: {
        const players = Mpris.players.values
        for (let i = 0; i < players.length; ++i) {
            if (players[i].isPlaying)
                return players[i]
        }
        return players.length > 0 ? players[0] : null
    }

    readonly property bool hasPlayer: activePlayer !== null
    readonly property bool isPlaying: hasPlayer && activePlayer.isPlaying
    readonly property bool hasTimelineRaw: hasPlayer
        && activePlayer.lengthSupported
        && activePlayer.length > 0

    // Some browser players briefly publish length=0 during track changes. k4
    // holds the expanded timeline for 1.5s so the island does not jump height.
    property bool hasTimeline: false
    property int positionWatchers: 0

    onHasTimelineRawChanged: {
        if (hasTimelineRaw)
            hasTimeline = true
        else
            timelineDropTimer.restart()
    }

    Component.onCompleted: hasTimeline = hasTimelineRaw

    function watchPosition() {
        positionWatchers += 1
    }

    function unwatchPosition() {
        positionWatchers = Math.max(0, positionWatchers - 1)
    }

    function trackUrl(player) {
        if (!player || !player.metadata)
            return ""
        const url = player.metadata["xesam:url"]
        return url ? String(url) : ""
    }

    function coverFor(player) {
        if (!player)
            return ""

        if (player.trackArtUrl && player.trackArtUrl.length > 0)
            return player.trackArtUrl

        const url = trackUrl(player)
        if (url.length === 0)
            return ""

        const yt = url.match(/(?:youtube\.com\/(?:watch\?(?:.*&)?v=|embed\/|shorts\/|live\/)|youtu\.be\/)([A-Za-z0-9_-]{11})/)
        if (yt)
            return "https://i.ytimg.com/vi/" + yt[1] + "/mqdefault.jpg"

        const tw = url.match(/^https?:\/\/(?:www\.)?twitch\.tv\/([A-Za-z0-9_]+)\/?(?:\?.*)?$/)
        if (tw && ["videos", "directory", "settings", "downloads", "subscriptions", "u", "p"].indexOf(tw[1].toLowerCase()) === -1)
            return "https://static-cdn.jtvnw.net/previews-ttv/live_user_" + tw[1].toLowerCase() + "-440x248.jpg"

        return ""
    }

    function faviconFor(player) {
        const match = trackUrl(player).match(/^https?:\/\/([^\/]+)/)
        return match ? "https://" + match[1] + "/favicon.ico" : ""
    }

    function appIconFor(player) {
        return player && player.desktopEntry
            ? Quickshell.iconPath(player.desktopEntry, true) : ""
    }

    function formatTime(seconds) {
        if (!isFinite(seconds) || seconds < 0)
            seconds = 0

        const total = Math.floor(seconds)
        const mins = Math.floor(total / 60)
        const secs = total % 60
        return mins + ":" + (secs < 10 ? "0" + secs : secs)
    }

    function seekTo(fraction) {
        const player = activePlayer
        if (!player || !player.canSeek || !player.positionSupported
                || !(player.length > 0))
            return
        player.position = Math.max(0, Math.min(1, fraction)) * player.length
    }

    function previous() {
        if (activePlayer?.canGoPrevious)
            activePlayer.previous()
    }

    function next() {
        if (activePlayer?.canGoNext)
            activePlayer.next()
    }

    function togglePlaying() {
        if (activePlayer?.canTogglePlaying)
            activePlayer.togglePlaying()
    }

    Timer {
        interval: 500
        repeat: true
        running: root.isPlaying && root.positionWatchers > 0
        onTriggered: root.activePlayer?.positionChanged()
    }

    Timer {
        id: timelineDropTimer
        interval: 1500
        onTriggered: root.hasTimeline = root.hasTimelineRaw
    }
}
