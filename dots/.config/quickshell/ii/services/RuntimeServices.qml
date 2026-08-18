pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

// References to optional runtime-owned services. Implementations stay behind
// LazyLoaders so disabled features leave only null references here.
Singleton {
    property var ai: null
    property var liquidGlass: null
}
