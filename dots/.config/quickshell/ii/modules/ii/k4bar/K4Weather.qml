pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common
import qs.services

// K4 weather presentation adapter. ii-vynx Weather remains the current-weather,
// GPS and persistent city owner. K4 only fetches richer forecast/search/history
// data on explicit K4 use; it does not introduce a second periodic weather owner.
Singleton {
    id: root

    property var hourly: []
    property var daily: []
    property var history: []
    property var matches: []
    property bool loading: false
    property bool historyLoading: false
    property bool searching: false
    property string error: ""
    property string historyError: ""

    readonly property var current: Weather.data
    readonly property bool ready: String(current.temp || "").length > 0
    readonly property string place: String(current.city || Config.options.bar.weather.city || "")
    readonly property string summary: root.summaryText()
    readonly property string temperatureUnit: Weather.useUSCS ? "°F" : "°C"
    readonly property string precipitationUnit: Weather.useUSCS ? "in" : "mm"
    readonly property string windUnit: Weather.useUSCS ? "mph" : "km/h"

    function target() {
        if (Weather.gpsActive && Weather.location.valid)
            return `${Weather.location.lat},${Weather.location.long}`
        return Weather.formatCityName(Config.options.bar.weather.city || "")
    }

    function temp(valueC, valueF) {
        return Weather.useUSCS ? `${valueF}°F` : `${valueC}°C`
    }

    function numeric(value) {
        const match = String(value ?? "").match(/-?\d+(?:\.\d+)?/)
        return match ? Number(match[0]) : NaN
    }

    function temperatureValue(valueC) {
        const c = Number(valueC)
        if (!Number.isFinite(c)) return NaN
        return Weather.useUSCS ? c * 9 / 5 + 32 : c
    }

    function precipitationValue(valueMm) {
        const mm = Number(valueMm)
        if (!Number.isFinite(mm)) return 0
        return Weather.useUSCS ? mm / 25.4 : mm
    }

    function round(value, digits) {
        const factor = Math.pow(10, digits ?? 0)
        return Math.round(Number(value) * factor) / factor
    }

    function isoDay(offsetDays) {
        const date = new Date()
        date.setDate(date.getDate() + offsetDays)
        const year = date.getFullYear()
        const month = String(date.getMonth() + 1).padStart(2, "0")
        const day = String(date.getDate()).padStart(2, "0")
        return `${year}-${month}-${day}`
    }

    function historyLabel(iso) {
        const parts = String(iso || "").split("-")
        if (parts.length !== 3) return String(iso || "")
        const date = new Date(Number(parts[0]), Number(parts[1]) - 1, Number(parts[2]), 12, 0, 0)
        const days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        return `${days[date.getDay()]} ${date.getDate()}`
    }

    function conditionKind(code) {
        const n = Number(code)
        if ([200, 386, 389, 392, 395].indexOf(n) >= 0) return "storm"
        if ([179, 182, 185, 227, 230, 323, 326, 329, 332, 335, 338, 368, 371].indexOf(n) >= 0)
            return "snow"
        if (n >= 176 && n <= 365) return "rain"
        if (n === 143 || n === 248 || n === 260) return "fog"
        if (n === 119 || n === 122) return "cloudy"
        if (n === 116) return "partly"
        if (n === 113) return "clear"
        return "mixed"
    }

    function temperatureDescription() {
        const value = root.numeric(root.current.temp)
        if (!Number.isFinite(value)) return "mild"
        if (Weather.useUSCS) {
            if (value >= 95) return "very hot"
            if (value >= 82) return "warm"
            if (value <= 35) return "cold"
            if (value <= 52) return "cool"
            return "mild"
        }
        if (value >= 35) return "very hot"
        if (value >= 28) return "warm"
        if (value <= 2) return "cold"
        if (value <= 11) return "cool"
        return "mild"
    }

    function peakRainChance() {
        let peak = 0
        for (let i = 0; i < root.hourly.length; ++i)
            peak = Math.max(peak, Number(root.hourly[i].rain || 0))
        return peak
    }

    function humidityStatus(value) {
        const humidity = Number(value)
        if (!Number.isFinite(humidity)) return "Unavailable"
        if (humidity >= 75) return "Humid"
        if (humidity >= 55) return "Moderate"
        if (humidity >= 35) return "Comfortable"
        return "Dry"
    }

    function uvStatus(value) {
        const uv = Number(value)
        if (!Number.isFinite(uv)) return "Unavailable"
        if (uv >= 11) return "Extreme"
        if (uv >= 8) return "Very high"
        if (uv >= 6) return "High"
        if (uv >= 3) return "Moderate"
        return "Low"
    }

    function precipitationStatus() {
        const peak = root.peakRainChance()
        if (peak >= 70) return "Very likely"
        if (peak >= 40) return "Possible"
        if (peak >= 15) return "Slight chance"
        return "Dry"
    }

    function visibilityStatus(value) {
        const visible = root.numeric(value)
        if (!Number.isFinite(visible)) return "Unavailable"
        const km = Weather.useUSCS ? visible * 1.60934 : visible
        if (km >= 10) return "Clear"
        if (km >= 5) return "Moderate"
        return "Reduced"
    }

    function summaryText() {
        const kind = root.conditionKind(root.current.wCode)
        const temperature = root.temperatureDescription()
        let lead = "Mixed conditions right now."
        if (kind === "clear") lead = `Clear and ${temperature}.`
        else if (kind === "partly") lead = `Partly cloudy and ${temperature}.`
        else if (kind === "cloudy") lead = `Cloudy and ${temperature}.`
        else if (kind === "fog") lead = "Fog is reducing visibility."
        else if (kind === "rain") lead = "Rainy conditions are active."
        else if (kind === "storm") lead = "Thunderstorms are active nearby."
        else if (kind === "snow") lead = "Snowy conditions are active."

        const peak = root.peakRainChance()
        let outlook = "Forecast confidence is limited."
        if (peak >= 70) outlook = `Rain is very likely later today, peaking near ${peak}%.`
        else if (peak >= 40) outlook = `Rain is possible later today, peaking near ${peak}%.`
        else if (peak >= 15) outlook = `A small rain chance remains today, peaking near ${peak}%.`
        else if (root.hourly.length > 0) outlook = "No meaningful rain is expected today."

        return `${lead} ${outlook}`
    }

    // Upstream k4 uses the Nerd Fonts Weather Icons E3xx range. The ii-vynx
    // font install reliably carries Material Design Icons instead, so use the
    // equivalent MDI weather glyphs already used by the rest of this shell.
    function icon(code) {
        const n = Number(code)
        if (n === 113) return String.fromCodePoint(0xF0599) // sunny
        if (n === 116) return String.fromCodePoint(0xF0595) // partly cloudy
        if (n === 119 || n === 122) return String.fromCodePoint(0xF0590) // cloudy
        if (n === 143 || n === 248 || n === 260) return String.fromCodePoint(0xF0591) // fog
        if ([179, 182, 185, 227, 230, 323, 326, 329, 332, 335, 338, 368, 371].indexOf(n) >= 0)
            return String.fromCodePoint(0xF0598) // snow
        if ([200, 386, 389, 392, 395].indexOf(n) >= 0) return String.fromCodePoint(0xF067E) // lightning/rain
        if (n >= 176 && n <= 365) return String.fromCodePoint(0xF0597) // rain
        return String.fromCodePoint(0xF0595)
    }

    function refreshHistory(latitude, longitude) {
        const lat = Number(latitude)
        const lon = Number(longitude)
        if (!Number.isFinite(lat) || !Number.isFinite(lon)) return

        historyLoading = true
        historyError = ""
        const start = root.isoDay(-7)
        const end = root.isoDay(-1)
        historyFetch.command = ["curl", "-s", "--max-time", "15",
            `https://archive-api.open-meteo.com/v1/archive?latitude=${lat}&longitude=${lon}&start_date=${start}&end_date=${end}&daily=temperature_2m_max,temperature_2m_min,precipitation_sum,relative_humidity_2m_mean&timezone=auto`]
        historyFetch.running = true
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
                    let dailyRain = 0
                    for (let j = 0; j < slots.length; ++j)
                        dailyRain = Math.max(dailyRain, Number(slots[j].chanceofrain || 0))
                    daily.push({
                        date: day.date || "",
                        label: root.historyLabel(day.date || ""),
                        code: code,
                        description: Weather.getWeatherDescription(code),
                        max: root.temp(day.maxtempC || "0", day.maxtempF || "0"),
                        min: root.temp(day.mintempC || "0", day.mintempF || "0"),
                        maxValue: root.temperatureValue(day.maxtempC || "0"),
                        minValue: root.temperatureValue(day.mintempC || "0"),
                        rain: dailyRain
                    })
                    if (i === 0) {
                        for (let j = 0; j < slots.length && hourly.length < 8; ++j) {
                            const slot = slots[j]
                            const hour = String(slot.time || "0").padStart(4, "0")
                            hourly.push({
                                hour: `${hour.substring(0, 2)}:${hour.substring(2)}`,
                                code: slot.weatherCode || "0",
                                temp: root.temp(slot.tempC || "0", slot.tempF || "0"),
                                tempValue: root.temperatureValue(slot.tempC || "0"),
                                rain: Number(slot.chanceofrain || 0),
                                humidity: Number(slot.humidity || 0),
                                precip: root.precipitationValue(slot.precipMM || 0),
                                windValue: Number(Weather.useUSCS
                                    ? (slot.windspeedMiles || 0)
                                    : (slot.windspeedKmph || 0)),
                                uv: Number(slot.uvIndex || 0)
                            })
                        }
                    }
                }
                root.daily = daily
                root.hourly = hourly
                root.error = ""

                let latitude = NaN
                let longitude = NaN
                if (Weather.gpsActive && Weather.location.valid) {
                    latitude = Number(Weather.location.lat)
                    longitude = Number(Weather.location.long)
                } else {
                    const area = (data.nearest_area || [])[0] || {}
                    latitude = Number(area.latitude)
                    longitude = Number(area.longitude)
                }
                root.refreshHistory(latitude, longitude)
            }
        }
        onExited: function(code) {
            root.loading = false
            if (code !== 0 && root.daily.length === 0)
                root.error = "Could not connect to forecast service"
        }
    }

    Process {
        id: historyFetch
        stdout: StdioCollector {
            onStreamFinished: {
                root.historyLoading = false
                let data
                try { data = JSON.parse(this.text) }
                catch (e) {
                    root.history = []
                    root.historyError = "Could not read weather history"
                    return
                }

                const daily = data.daily || {}
                const dates = daily.time || []
                const highs = daily.temperature_2m_max || []
                const lows = daily.temperature_2m_min || []
                const rain = daily.precipitation_sum || []
                const humidity = daily.relative_humidity_2m_mean || []
                const result = []
                for (let i = 0; i < dates.length; ++i) {
                    const maxValue = root.temperatureValue(highs[i])
                    const minValue = root.temperatureValue(lows[i])
                    if (!Number.isFinite(maxValue) || !Number.isFinite(minValue)) continue
                    result.push({
                        date: dates[i],
                        label: root.historyLabel(dates[i]),
                        maxValue: root.round(maxValue, 1),
                        minValue: root.round(minValue, 1),
                        precip: root.round(root.precipitationValue(rain[i]), Weather.useUSCS ? 2 : 1),
                        humidity: root.round(Number(humidity[i] || 0), 0)
                    })
                }
                root.history = result
                root.historyError = result.length ? "" : "Weather history unavailable"
            }
        }
        onExited: function(code) {
            root.historyLoading = false
            if (code !== 0 && root.history.length === 0)
                root.historyError = "Could not connect to history service"
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
