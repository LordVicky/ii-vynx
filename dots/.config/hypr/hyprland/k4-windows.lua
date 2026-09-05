require("hyprland.lib")

-- K4 Windows V2 is driven by Quickshell GlobalShortcut routes. These bindings
-- never execute a window-management script or hyprctl subprocess; Hyprland only
-- forwards the modifier chord into the already-running Quickshell process.
hl.bind("ALT + Tab", hl.dsp.global("quickshell:windowsSwitcherToggle"),
    { description = "Window: K4 switch windows" })
hl.bind("ALT + SHIFT + Tab", hl.dsp.global("quickshell:windowsSwitcherPrevious"),
    { description = "Window: K4 switch windows backward" })

-- The focused K4 surface is not guaranteed to receive Qt.Key_Alt when Hyprland
-- owns Alt+Tab. Bind the physical modifier itself to a GlobalShortcut so
-- Quickshell receives the compositor-level release event and can commit the
-- armed selection. The handler is a no-op unless an Alt+Tab session is active.
hl.bind("ALT + ALT_L", hl.dsp.global("quickshell:windowsSwitcherModifier"),
    { transparent = true, description = "Window: Commit K4 switcher on Alt release" })
hl.bind("ALT + ALT_R", hl.dsp.global("quickshell:windowsSwitcherModifier"),
    { transparent = true })
