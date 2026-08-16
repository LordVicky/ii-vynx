pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

// References to optional runtime-owned services. This singleton intentionally
// contains no AI implementation; under policies.ai == No, `ai` is literally null.
Singleton {
    property var ai: null
}
