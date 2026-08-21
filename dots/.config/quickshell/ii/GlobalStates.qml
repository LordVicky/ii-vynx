import qs.modules.common
import qs.services
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
pragma Singleton
pragma ComponentBehavior: Bound

Singleton {
    id: root

    property alias sidebarLeftOpen: root.policiesPanelOpen // Until all sidebars naming is fixed
    property alias sidebarRightOpen: root.dashboardPanelOpen // Until all sidebars naming is fixed

    property bool barOpen: true
    property var barAutoHideOffsets: ({})
    property bool verticalBarGlassSurfaceActive: false
    property bool unifiedBarGlassSegmentsEnabled: true
    property var barGlassSegments: ({})
    property var verticalBarGlassSegments: ({})
    property int barGlassSegmentOwnerCounter: 0
    property bool crosshairOpen: false
    property bool desktopWidgetKeyboardFocus: false // Suppresses global shortcuts while typing in a desktop widget (notes, world clock settings, ...)
    property bool mediaControlsOpen: false
    property bool osdBrightnessOpen: false
    property bool osdVolumeOpen: false
    property bool oskOpen: false
    property bool overlayOpen: false
    property bool overviewOpen: false
    property bool regionSelectorOpen: false
    property bool searchOpen: false
    property bool screenLocked: false
    property bool screenLockContainsCharacters: false
    property bool screenUnlockFailed: false
    property bool screenTranslatorOpen: false
    property bool sessionOpen: false
    property bool superDown: false
    property bool superReleaseMightTrigger: true
    property bool wallpaperSelectorOpen: false
    property bool workspaceShowNumbers: false

    property bool dashboardPanelOpen: false // formerly sidebarRightOpen
    property bool policiesPanelOpen: false  // formerly sidebarLeftOpen

    readonly property bool effectiveLeftOpen: {
        switch (Config.options.sidebar.position) {
            case "default":  return policiesPanelOpen;  
            case "inverted": return dashboardPanelOpen;  
            case "left":     return dashboardPanelOpen || policiesPanelOpen;
            case "right":    return false;
            default:         return policiesPanelOpen;
        }
    }
    readonly property bool effectiveRightOpen: {
        switch (Config.options.sidebar.position) {
            case "default":  return dashboardPanelOpen; 
            case "inverted": return policiesPanelOpen; 
            case "left":     return false;
            case "right":    return dashboardPanelOpen || policiesPanelOpen;
            default:         return dashboardPanelOpen;
        }
    }

    // helper properties
    readonly property bool policiesOnLeft: Config.options.sidebar.position === "default" || Config.options.sidebar.position === "left"
    readonly property bool dashboardOnLeft: Config.options.sidebar.position === "inverted" || Config.options.sidebar.position === "left"

    function setBarAutoHideOffset(screenName, offset) {
        if (!screenName)
            return;

        const numericOffset = Number(offset);
        const nextOffset = isFinite(numericOffset) ? numericOffset : 0;
        if (root.barAutoHideOffsets[screenName] === nextOffset)
            return;

        const nextOffsets = Object.assign({}, root.barAutoHideOffsets);
        nextOffsets[screenName] = nextOffset;
        root.barAutoHideOffsets = nextOffsets;
    }

    function clearBarAutoHideOffset(screenName) {
        if (!screenName || root.barAutoHideOffsets[screenName] === undefined)
            return;

        const nextOffsets = Object.assign({}, root.barAutoHideOffsets);
        delete nextOffsets[screenName];
        root.barAutoHideOffsets = nextOffsets;
    }

    function allocateBarGlassSegmentOwnerId() {
        root.barGlassSegmentOwnerCounter += 1;
        return root.barGlassSegmentOwnerCounter;
    }

    function setBarGlassSegment(vertical, screenName, key, segment, ownerId) {
        if (!screenName || !key || !segment || !ownerId)
            return;

        const store = vertical ? root.verticalBarGlassSegments : root.barGlassSegments;
        const screenSegments = Object.assign({}, store[screenName] ?? {});
        const previous = screenSegments[key];
        if (previous
                && previous.ownerId === ownerId
                && previous.position === segment.position
                && previous.extent === segment.extent
                && previous.startRadius === segment.startRadius
                && previous.endRadius === segment.endRadius)
            return;

        screenSegments[key] = Object.assign({}, segment, { ownerId: ownerId });
        const nextStore = Object.assign({}, store);
        nextStore[screenName] = screenSegments;
        if (vertical)
            root.verticalBarGlassSegments = nextStore;
        else
            root.barGlassSegments = nextStore;
    }

    function clearBarGlassSegment(vertical, screenName, key, ownerId) {
        if (!screenName || !key || !ownerId)
            return;

        const store = vertical ? root.verticalBarGlassSegments : root.barGlassSegments;
        const current = store[screenName]?.[key];
        if (current === undefined || current.ownerId !== ownerId)
            return;

        const screenSegments = Object.assign({}, store[screenName]);
        delete screenSegments[key];
        const nextStore = Object.assign({}, store);
        if (Object.keys(screenSegments).length > 0)
            nextStore[screenName] = screenSegments;
        else
            delete nextStore[screenName];

        if (vertical)
            root.verticalBarGlassSegments = nextStore;
        else
            root.barGlassSegments = nextStore;
    }

    function setLiveBarGlassSegment(vertical, screenName, key, segmentObject) {
        if (!screenName || !key || !segmentObject)
            return;

        const store = vertical ? root.verticalBarGlassSegments : root.barGlassSegments;
        const screenSegments = Object.assign({}, store[screenName] ?? {});
        if (screenSegments[key] === segmentObject)
            return;

        screenSegments[key] = segmentObject;
        const nextStore = Object.assign({}, store);
        nextStore[screenName] = screenSegments;
        if (vertical)
            root.verticalBarGlassSegments = nextStore;
        else
            root.barGlassSegments = nextStore;
    }

    function clearLiveBarGlassSegment(vertical, screenName, key, segmentObject) {
        if (!screenName || !key || !segmentObject)
            return;

        const store = vertical ? root.verticalBarGlassSegments : root.barGlassSegments;
        if (store[screenName]?.[key] !== segmentObject)
            return;

        const screenSegments = Object.assign({}, store[screenName]);
        delete screenSegments[key];
        const nextStore = Object.assign({}, store);
        if (Object.keys(screenSegments).length > 0)
            nextStore[screenName] = screenSegments;
        else
            delete nextStore[screenName];

        if (vertical)
            root.verticalBarGlassSegments = nextStore;
        else
            root.barGlassSegments = nextStore;
    }

    onPoliciesPanelOpenChanged: {
        if (policiesPanelOpen) {
            if (Config.options.sidebar.position == "right" || Config.options.sidebar.position == "left") {
                GlobalStates.dashboardPanelOpen = false
            }
        }
        
    }

    onDashboardPanelOpenChanged: {
        if (dashboardPanelOpen) {
            Notifications.timeoutAll();
            Notifications.markAllRead();
            if (Config.options.sidebar.position == "right" || Config.options.sidebar.position == "left") {
                GlobalStates.policiesPanelOpen = false
            }
        }
        
    }

    GlobalShortcut {
        name: "workspaceNumber"
        description: "Hold to show workspace numbers, release to show icons"
        onPressed: {
            root.superDown = true
        }
        onReleased: {
            root.superDown = false
        }
    }
}