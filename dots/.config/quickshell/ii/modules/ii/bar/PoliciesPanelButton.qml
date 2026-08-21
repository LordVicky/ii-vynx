import QtQuick
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets

RippleButton {
    id: leftSidebarButton

    property bool showPing: false
    property var sidebarExtensionPages: []
    readonly property bool animeBooruActive: sidebarExtensionPages.some(page => page.identifier === "anime-booru")

    property real buttonPadding: 5
    implicitWidth: distroIcon.width + buttonPadding * 2
    implicitHeight: distroIcon.height + buttonPadding * 2
    buttonRadius: Appearance.rounding.full
    colBackgroundHover: Appearance.colors.colLayer1Hover
    colRipple: Appearance.colors.colLayer1Active
    colBackgroundToggled: Appearance.colors.colSecondaryContainer
    colBackgroundToggledHover: Appearance.colors.colSecondaryContainerHover
    colRippleToggled: Appearance.colors.colSecondaryContainerActive
    toggled: GlobalStates.sidebarLeftOpen

    function refreshSidebarExtensionPages() {
        sidebarExtensionPages = ExtensionManager.ready
            ? ExtensionManager.getContributionPoint("sidebarLeftPages")
            : [];
    }

    Component.onCompleted: refreshSidebarExtensionPages()

    onPressed: {
        GlobalStates.sidebarLeftOpen = !GlobalStates.sidebarLeftOpen;
    }

    Connections {
        target: RuntimeServices.ai
        function onResponseFinished() {
            if (GlobalStates.sidebarLeftOpen) return;
            leftSidebarButton.showPing = true;
        }
    }

    Connections {
        target: ExtensionManager
        function onRefreshExtensions() { leftSidebarButton.refreshSidebarExtensionPages(); }
        function onExtensionInstalled() { leftSidebarButton.refreshSidebarExtensionPages(); }
        function onExtensionRemoved() { leftSidebarButton.refreshSidebarExtensionPages(); }
        function onExtensionToggled() { leftSidebarButton.refreshSidebarExtensionPages(); }
    }

    Loader {
        active: leftSidebarButton.animeBooruActive
        visible: false
        sourceComponent: Item {
            Connections {
                target: Booru
                function onResponseFinished() {
                    if (GlobalStates.sidebarLeftOpen) return;
                    leftSidebarButton.showPing = true;
                }
            }
        }
    }

    Connections {
        target: GlobalStates
        function onSidebarLeftOpenChanged() {
            leftSidebarButton.showPing = false;
        }
    }

    CustomIcon {
        id: distroIcon
        anchors.centerIn: parent
        width: 19.5
        height: 19.5
        source: Config.options.bar.topLeftIcon == 'distro' ? SystemInfo.distroIcon : `${Config.options.bar.topLeftIcon}-symbolic`
        colorize: true
        color: BarPalette.foreground(Appearance.colors.colOnLayer0)

        Rectangle {
            opacity: leftSidebarButton.showPing ? 1 : 0
            visible: opacity > 0
            anchors {
                bottom: parent.bottom
                right: parent.right
                bottomMargin: -2
                rightMargin: -2
            }
            implicitWidth: 8
            implicitHeight: 8
            radius: Appearance.rounding.full
            color: Appearance.colors.colTertiary

            Behavior on opacity {
                animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
            }
        }
    }
}
