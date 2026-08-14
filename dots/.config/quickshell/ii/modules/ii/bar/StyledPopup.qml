import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland

LazyLoader {
    id: root
    property Item hoverTarget
    default property Item contentItem
    property Component lazyContent: null
    readonly property Item effectiveContentItem: contentItem ?? item?.lazyContentItem ?? null
    property real popupBackgroundMargin: 0
    property int popupRadius: Appearance.rounding.large
    property bool animate: true
    property bool stickyHover: false

    property bool _popupHovered: false
    property bool _stickyActive: false
    property bool _targetHovered: hoverTarget ? hoverTarget.containsMouse : false

    active: stickyHover ? _stickyActive : (hoverTarget && hoverTarget.containsMouse)

    // I have NO FUCKING IDEA why we cant use a normal timer here
    // Because if we do, we FUCKING cannot reference the timer from anywhere
    property QtObject _timers: QtObject {
        property Timer grace: Timer {
            interval: 100
            onTriggered: {
                root._popupHovered = false;
                root._stickyActive = false;
            }
        }
    }

    function _evaluateStickyState() {
        if (!stickyHover)
            return;

        if (_targetHovered || _popupHovered) {
            _stickyActive = true;
            _timers.grace.stop();
        } else if (_stickyActive && !_timers.grace.running) {
            _timers.grace.start();
        }
    }

    on_TargetHoveredChanged: _evaluateStickyState()

    onActiveChanged: {
        if (!active) {
            _popupHovered = false;
            _timers.grace.stop();
        }
    }

    component: PanelWindow {
        id: popupWindow
        property alias lazyContentItem: lazyContentLoader.item
        color: "transparent"

        function attachContentItem(content) {
            if (!content || !contentContainer)
                return;

            content.parent = contentContainer;
            content.anchors.centerIn = undefined;
            content.anchors.top = contentContainer.top;
            content.anchors.left = contentContainer.left;
            content.anchors.right = contentContainer.right;

            for (let i = 0; i < content.children.length; i++) {
                let child = content.children[i];

                child.opacity = Qt.binding(() => {
                    if (!root.animate)
                        return 1.0;
                    let normalizedDelay = child.y / popupBackground.targetHeight;
                    let progress = (popupWindow.animProgress - normalizedDelay) / (1.0 - normalizedDelay);
                    return Math.max(0, Math.min(1.0, progress));
                });

                child.scale = Qt.binding(() => {
                    if (!root.animate)
                        return 1.0;
                    let normalizedDelay = child.y / popupBackground.targetHeight;
                    let progress = (popupWindow.animProgress - normalizedDelay) / (1.0 - normalizedDelay);
                    return 0.85 + (0.15 * Math.max(0, Math.min(1.0, progress)));
                });
            }
        }

        Loader {
            id: lazyContentLoader
            active: root.lazyContent !== null
            sourceComponent: root.lazyContent
            onItemChanged: popupWindow.attachContentItem(item)
        }

        readonly property real screenWidth: popupWindow.screen?.width ?? 0
        readonly property real screenHeight: popupWindow.screen?.height ?? 0

        anchors.left: !Config.options.bar.vertical || (Config.options.bar.vertical && !Config.options.bar.bottom)
        anchors.right: Config.options.bar.vertical && Config.options.bar.bottom
        anchors.top: Config.options.bar.vertical || (!Config.options.bar.vertical && !Config.options.bar.bottom)
        anchors.bottom: !Config.options.bar.vertical && Config.options.bar.bottom

        implicitWidth: popupBackground.targetWidth + Appearance.sizes.elevationMargin * 2 + root.popupBackgroundMargin
        implicitHeight: popupBackground.targetHeight + Appearance.sizes.elevationMargin * 2 + root.popupBackgroundMargin

        mask: Region {
            item: popupBackground
        }

        exclusionMode: ExclusionMode.Ignore
        exclusiveZone: 0

        margins {
            left: {
                if (!Config.options.bar.vertical) {
                    if (!root.hoverTarget || !root.QsWindow)
                        return 0;
                    var targetPos = root.QsWindow.mapFromItem(root.hoverTarget, 0, 0);
                    var centeredX = targetPos.x + (root.hoverTarget.width - popupWindow.implicitWidth) / 2;
                    var minX = 0;
                    var maxX = screenWidth - popupWindow.implicitWidth;
                    return Math.max(minX, Math.min(maxX, centeredX));
                }
                return Appearance.sizes.verticalBarWidth;
            }

            top: {
                if (!Config.options.bar.vertical) {
                    return Appearance.sizes.barHeight;
                }
                if (!root.hoverTarget || !root.QsWindow)
                    return 0;
                var targetPos = root.QsWindow.mapFromItem(root.hoverTarget, 0, 0);
                var centeredY = targetPos.y + (root.hoverTarget.height - popupWindow.implicitHeight) / 2;
                var minY = 0;
                var maxY = screenHeight - popupWindow.implicitHeight;
                return Math.max(minY, Math.min(maxY, centeredY));
            }

            right: Appearance.sizes.verticalBarWidth
            bottom: Appearance.sizes.barHeight
        }

        WlrLayershell.namespace: "quickshell:popup"
        WlrLayershell.layer: WlrLayer.Overlay

        StyledRectangularShadow {
            target: popupBackground
        }

        property real animProgress: 0.0
        readonly property Item heroItem: {
            if (!root.effectiveContentItem)
                return null;
            for (let i = 0; i < root.effectiveContentItem.children.length; i++) {
                let child = root.effectiveContentItem.children[i];
                if (child.visible && child.width > 0)
                    return child;
            }
            return null;
        }
        readonly property real heroHeight: heroItem ? heroItem.implicitHeight : 0

        NumberAnimation on animProgress {
            id: openAnim
            from: 0
            to: 1
            running: true
            duration: Appearance.animation.elementMove.duration
            easing.type: Appearance.animation.elementMove.type
            easing.bezierCurve: Appearance.animation.elementMove.bezierCurve
        }

        Rectangle {
            id: popupBackground
            readonly property real margin: 10

            readonly property real targetWidth: (root.effectiveContentItem?.implicitWidth ?? 0) + margin * 2
            readonly property real targetHeight: (root.effectiveContentItem?.implicitHeight ?? 0) + margin * 2

            property bool isVertical: Config.options.bar.vertical
            property bool isBottom: Config.options.bar.bottom
            property int elevation: Appearance.sizes.elevationMargin

            // Debounced height — no auto-binding to targetHeight.
            // Batches rapid layout changes before triggering smooth animation.
            property real _commitHeight: 0
            // Delayed enable to avoid opening animation transition glitch
            property bool _heightReady: false

            Timer {
                id: heightCommit
                interval: 32
                repeat: false
                onTriggered: popupBackground._commitHeight = popupBackground.targetHeight
            }

            onTargetHeightChanged: {
                if (popupWindow.animProgress >= 1.0 && popupBackground._heightReady)
                    heightCommit.restart();
                else
                    _commitHeight = targetHeight;
            }

            Component.onCompleted: {
                _commitHeight = targetHeight;
                Qt.callLater(function () {
                    popupBackground._heightReady = true;
                });
            }

            Behavior on _commitHeight {
                enabled: popupBackground._heightReady
                SmoothedAnimation {
                    duration: 200
                    easing: Easing.OutQuad
                }
            }

            anchors {
                top: (!isVertical && !isBottom) ? parent.top : undefined
                bottom: (!isVertical && isBottom) ? parent.bottom : undefined
                left: (isVertical && !isBottom) ? parent.left : undefined
                right: (isVertical && isBottom) ? parent.right : undefined

                topMargin: top ? elevation : undefined
                bottomMargin: bottom ? elevation : undefined
                leftMargin: left ? elevation : undefined
                rightMargin: right ? elevation : undefined

                verticalCenter: isVertical ? parent.verticalCenter : undefined
                horizontalCenter: !isVertical ? parent.horizontalCenter : undefined
            }

            width: targetWidth
            height: {
                if (!root.animate || !root.effectiveContentItem || !heroItem || targetHeight <= heroHeight + margin * 2)
                    return _commitHeight;
                return (heroHeight + margin * 2) + (_commitHeight - (heroHeight + margin * 2)) * popupWindow.animProgress;
            }

            // Respect the shell transparency setting so Hyprland's layer blur can
            // remain visible behind popups.
            color: Appearance.colors.colBackgroundSurfaceContainer
            radius: root.popupRadius

            Item {
                id: contentContainer
                anchors.fill: parent
                anchors.margins: popupBackground.margin
                clip: true

                Component.onCompleted: popupWindow.attachContentItem(root.effectiveContentItem)
            }

            HoverHandler {
                id: popupHoverHandler
                onHoveredChanged: {
                    root._popupHovered = hovered;
                    root._evaluateStickyState();
                }
            }

            border.width: 1
            border.color: Appearance.colors.colLayer0Border
        }
    }
}
