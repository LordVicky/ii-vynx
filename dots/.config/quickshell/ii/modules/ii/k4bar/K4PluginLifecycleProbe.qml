import QtQuick

// Throwaway K4-11 lifecycle probe. It deliberately owns no services, IPC,
// registry metadata or persisted state; the host only uses it to test whether
// Qt-owned Loader lifetime is safe for a non-visual K4Plugin QObject.
K4Plugin {
    id: root

    name: "lifecycle-probe"
    title: "Lifecycle probe"
    configurable: false
    application: false
    active: false

    readonly property double createdAt: Date.now()

    Component.onCompleted: console.info("[k4-probe] created", root.createdAt)
    Component.onDestruction: console.info("[k4-probe] released", root.createdAt)
}
