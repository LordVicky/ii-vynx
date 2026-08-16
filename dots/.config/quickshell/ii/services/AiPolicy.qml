pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.modules.common

// Semantic view over Config.options.policies.ai.
// The persisted integer remains the single source of truth; consumers should
// depend on capabilities so 0/1/2 is interpreted consistently everywhere.
Singleton {
    id: root

    readonly property int mode: Config.ready ? (Config.options?.policies?.ai ?? 0) : 0
    readonly property bool enabled: root.mode === 1 || root.mode === 2
    readonly property bool localOnly: root.mode === 2
    readonly property bool onlineAllowed: root.mode === 1
    readonly property bool localAllowed: root.enabled
}
