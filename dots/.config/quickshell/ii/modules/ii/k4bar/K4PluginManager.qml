import QtQuick
import Quickshell.Io

// Lean built-in lifecycle manager. It deliberately manages only plugins that
// ship inside ii-vynx; external plugin discovery/install/update machinery is
// outside the approved K4-11 scope.
QtObject {
    id: root

    property var controller: null
    property var instances: []
    property var debugEntryOverrides: ({})

    property QtObject displaysSlot: K4PluginSlot {
        name: "displays"
        title: "Displays"
        entry: "K4DisplaysPlugin.qml"
        application: true
        applicationGlyph: String.fromCodePoint(0xF037A)
    }

    readonly property var descriptors: [displaysSlot]

    function descriptor(name) {
        const id = String(name)
        for (let i = 0; i < descriptors.length; ++i)
            if (descriptors[i].name === id)
                return descriptors[i]
        return null
    }

    function owns(name) {
        return descriptor(name) !== null
    }

    function instance(name) {
        return descriptor(name)?.instance ?? null
    }

    function effectiveEntry(slot) {
        return String(debugEntryOverrides[slot.name] ?? slot.entry)
    }

    function publish() {
        const live = []
        for (let i = 0; i < descriptors.length; ++i)
            if (descriptors[i].instance)
                live.push(descriptors[i].instance)
        instances = live
    }

    function injectHostReferences(obj) {
        if (!obj)
            return
        if ("controller" in obj)
            obj.controller = controller
    }

    function create(slot) {
        if (!slot || slot.instance || !slot.enabled)
            return slot?.instance ?? null

        const comp = Qt.createComponent(Qt.resolvedUrl(effectiveEntry(slot)))
        if (comp.status !== Component.Ready) {
            slot.loadError = comp.errorString() || "Component failed to load"
            publish()
            return null
        }

        let obj = null
        try {
            obj = comp.createObject(root)
        } catch (error) {
            slot.loadError = String(error)
            publish()
            return null
        }

        if (!obj) {
            slot.loadError = comp.errorString() || "createObject returned null"
            publish()
            return null
        }

        slot.instance = obj
        slot.loadError = ""
        injectHostReferences(obj)
        publish()
        return obj
    }

    function disableIpcHandlers(obj) {
        const services = obj?.services ?? []
        for (let i = 0; i < services.length; ++i) {
            const h = services[i]
            if (h && ("target" in h) && ("enabled" in h)) {
                try { h.enabled = false } catch (error) { }
            }
        }
    }

    function destroy(slot) {
        const obj = slot?.instance
        if (!obj)
            return

        if (typeof obj.close === "function") {
            try { obj.close() } catch (error) { }
        }
        try { obj.enabled = false } catch (error) { }
        disableIpcHandlers(obj)

        slot.instance = null
        publish()
        obj.destroy()
    }

    function sync(slot) {
        if (!slot)
            return
        const wanted = K4Settings.pluginEnabled(slot.name)
        slot.enabled = wanted
        if (!wanted) {
            destroy(slot)
            return
        }
        if (!slot.instance && slot.loadError.length === 0)
            create(slot)
    }

    function syncAll() {
        for (let i = 0; i < descriptors.length; ++i)
            sync(descriptors[i])
    }

    function setEnabled(name, wanted) {
        const slot = descriptor(name)
        if (!slot)
            return false

        const target = Boolean(wanted)
        K4Settings.setPluginEnabled(slot.name, target)
        slot.enabled = target

        if (target) {
            slot.loadError = ""
            if (!slot.instance)
                Qt.callLater(function() {
                    if (slot.enabled && !slot.instance)
                        root.create(slot)
                })
        } else {
            destroy(slot)
        }
        return true
    }

    function retry(name) {
        const slot = descriptor(name)
        if (!slot || !slot.enabled || slot.instance)
            return false
        slot.loadError = ""
        return create(slot) !== null
    }

    function shutdown() {
        for (let i = 0; i < descriptors.length; ++i)
            destroy(descriptors[i])
    }

    onControllerChanged: {
        for (let i = 0; i < instances.length; ++i)
            injectHostReferences(instances[i])
    }

    property var settingsConnections: Connections {
        target: K4Settings
        function onDisabledPluginsChanged() { root.syncAll() }
    }

    // Temporary K4-11 validation seam. It only swaps the in-memory entry used
    // for the managed built-in; it does not touch files or install anything.
    property var debugIpc: IpcHandler {
        target: "k4.pluginLifecycleDebug"

        function fail(id: string): void {
            const slot = root.descriptor(id)
            if (!slot)
                return
            root.destroy(slot)
            const next = Object.assign({}, root.debugEntryOverrides)
            next[slot.name] = "__missing_k4_plugin__.qml"
            root.debugEntryOverrides = next
            slot.loadError = ""
            root.create(slot)
        }

        function restore(id: string): void {
            const slot = root.descriptor(id)
            if (!slot)
                return
            root.destroy(slot)
            const next = Object.assign({}, root.debugEntryOverrides)
            delete next[slot.name]
            root.debugEntryOverrides = next
            slot.loadError = ""
            if (slot.enabled)
                root.create(slot)
        }

        function retry(id: string): void { root.retry(id) }

        function status(): string {
            return JSON.stringify(root.descriptors.map(function(slot) {
                return {
                    id: slot.name,
                    enabled: slot.enabled,
                    loaded: slot.instance !== null,
                    error: slot.loadError
                }
            }))
        }
    }

    Component.onCompleted: syncAll()
    Component.onDestruction: shutdown()
}
