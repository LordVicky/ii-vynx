pragma Singleton
pragma ComponentBehavior: Bound
import qs.modules.common
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

/**
 * Screensharing and mic activity.
 */
Singleton {
    id: root

    // These filter down to the matching link groups; the bools are whether any
    // survived. Mapping to .target and assigning the array straight to a bool
    // coerced by JS truthiness, and an empty array is truthy - so both read as
    // permanently active. Nothing consumed this service until the privacy
    // desktop widget, which is why it went unnoticed.
    readonly property var screenSharingTargets: Pipewire.linkGroups.values.filter(pwlg => pwlg.source.type === PwNodeType.VideoSource).map(pwlg => pwlg.target)
    readonly property var micTargets: Pipewire.linkGroups.values.filter(pwlg => pwlg.source.type === PwNodeType.AudioSource && pwlg.target.type === PwNodeType.AudioInStream).map(pwlg => pwlg.target)

    readonly property bool screenSharing: screenSharingTargets.length > 0
    readonly property bool micActive: micTargets.length > 0
}
