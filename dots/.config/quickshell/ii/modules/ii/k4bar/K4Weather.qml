pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common
import qs.services

// K4 weather presentation adapter. ii-vynx Weather remains the current-weather,
// GPS and persistent city owner. K4 only fetches the richer forecast/search
// data that its upstream view needs, and only on explicit K4 use.
Singleton {
    id: root

    property var hourly: []
    property var daily: []
    property var matches: []
    property bool loading: false
    property bool searching: false
    property string error: ""

    readonly property var current: Weather.data
    readonly property bool ready: String(current.temp || "").length > 0
    readonly property string place: String(current.city || Config.options.bar.weather.city || "")

    function target() {
        if (Weather.gpsActive && Weather.location.valid)
            return `${Weather.location.lat},${Weather.location.long}`
        return Weather.formatCityName(Config.options.bar.weather.city || "")
    }

    function temp(valueC, valueF) {
        return Weather.useUSCS ? `${valueF}°F` : `${valueC}°C`
    }

    function icon(code) {
        const n = Number(code)
        if (n === 113) return String.fromCodePoint(0xE30D)
        if (n === 116) return String.fromCodePoint(0xE302)
        if (n === 119 || n === 122) return String.fromCodePoint(0xE312)
        if (n === 143 || n === 248 || n === 260) return String.fromCodePoint(0xE303)
        if ([179, 182, 185, 227, 230, 323, 326, 329, 332, 335, 338, 368, 371].indexOf(n) >= 0)
            return String.fromCodePoint(0xE31A)
        if ([200, 386, 389, 392, 395].indexOf(n) >= 0) return String.fromCodePoint(0xE30F)
        if (n >= 176 && n <= 365) return String.fromCodePoint(0xE318)
        return String.fromCodePoint(0xE374)
    }

    function refresh() {
        Weather.getData()
        const destination = target()
        if (!destination.length) return
        loading = true
        error = ""
        forecast.command = ["curl", "-s", "--max-time", "15",
            `https://wttr.in/${destination}?format=j1`]
        forecast.running = true
    }

    function search(query) {
        const q = String(query || "").trim()
        if (q.length < 2) {
            matches = []
            searching = false
            return
        }
        searching = true
        geocode.command = ["curl", "-s", "--max-time", "12",
            `https://geocoding-api.open-meteo.com/v1/search?name=${encodeURIComponent(q)}&count=6&format=json`]
        geocode.running = true
    }

    function choose(match) {
        if (!match) return
        Config.options.bar.weather.enableGPS = false
        Config.options.bar.weather.city = match.name
        matches = []
        Weather.getData()
        refresh()
    }

    Process {
        id: forecast
        stdout: StdioCollector {
            onStreamFinished: {
                root.loading = false
                let data
                try { data = JSON.parse(this.text) }
                catch (e) {
                    root.error = "Could not read forecast"
                    root.hourly = []
                    root.daily = []
                    return
                }

                const days = data.weather || []
                const daily = []
                const hourly = []
                for (let i = 0; i < days.length && i < 6; ++i) {
                    const day = days[i]
                    const slots = day.hourly || []
                    const code = slots.length ? slots[Math.min(4, slots.length - 1)].weatherCode : "0"
                    daily.push({
                        date: day.date || "",
                        code: code,
                        description: Weather.getWeatherDescription(code),
                        max: root.temp(day.maxtempC || "0", day.maxtempF || "0"),
                        min: root.temp(day.mintempC || "0", day.mintempF || "0")
                    })
                    if (i === 0) {
                        for (let j = 0; j < slots.length && hourly.length < 8; ++j) {
                            const slot = slots[j]
                            const hour = String(slot.time || "0").padStart(4, "0")
                            hourly.push({
                                hour: `${hour.substring(0, 2)}:${hour.substring(2)}`,
                                code: slot.weatherCode || "0",
                                temp: root.temp(slot.tempC || "0", slot.tempF || "0"),
                                rain: Number(slot.chanceofrain || 0)
                            })
                        }
                    }
                }
                root.daily = daily
                root.hourly = hourly
                root.error = ""
            }
        }
        onExited: function(code) {
            root.loading = false
            if (code !== 0 && root.daily.length === 0)
                root.error = "Could not connect to forecast service"
        }
    }

    Process {
        id: geocode
        stdout: StdioCollector {
            onStreamFinished: {
                root.searching = false
                let data
                try { data = JSON.parse(this.text) }
                catch (e) { root.matches = []; return }
                root.matches = (data.results || []).map(result => ({
                    name: result.name || "",
                    region: [result.admin1, result.country].filter(value => !!value).join(" · "),
                    latitude: result.latitude,
                    longitude: result.longitude
                }))
            }
        }
        onExited: root.searching = false
    }
}
