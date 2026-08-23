import QtQuick
import Quickshell.Io

// Weather utility adapted from k4ditano/k4 WeatherPlugin at the pinned source
// commit. Current weather/config/GPS ownership remains in ii-vynx Weather.
K4Plugin {
    id: root

    name: "weather"
    title: "Weather"
    priority: 62
    application: true
    applicationGlyph: String.fromCodePoint(0xF0595)
    active: enabled && open
    viewLoaded: open
    grabKeyboard: open

    property bool open: false
    property bool searchOpen: false
    property string query: ""

    islandWidth: 820
    islandHeight: 420

    handlesBackgroundTap: true
    onBackgroundTapped: {}
    closeOnHoverExit: true
    hoverExitDelay: 1000
    onHoverTimedOut: close()

    function openWeather() {
        K4Panel.close()
        K4Notifications.dismissToast()
        open = true
        searchOpen = false
        query = ""
        K4Weather.refresh()
    }

    function openApplication() {
        if (!enabled) return false
        openWeather()
        return true
    }

    function toggle() { open ? close() : openWeather() }

    function close() {
        open = false
        closeSearch()
    }

    function openSearch() {
        query = ""
        searchOpen = true
    }

    function closeSearch() {
        searchOpen = false
        query = ""
        K4Weather.matches = []
    }

    function choose(match) {
        K4Weather.choose(match)
        closeSearch()
    }

    IpcHandler {
        target: "k4.weather"
        function toggle(): void { root.toggle() }
        function open(): void { root.openWeather() }
        function close(): void { root.close() }
        function refresh(): void { K4Weather.refresh() }
        function place(city: string): void {
            root.openWeather()
            root.searchOpen = true
            root.query = city
            K4Weather.search(city)
        }
    }

    view: Component { K4WeatherView { plugin: root } }
}
