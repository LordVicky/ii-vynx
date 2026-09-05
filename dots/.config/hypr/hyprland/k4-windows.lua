require("hyprland.lib")

-- K4 Windows V2 is driven by Quickshell GlobalShortcut routes. These bindings
-- never execute a window-management script or hyprctl subprocess; Hyprland only
-- forwards the modifier chord into the already-running Quickshell process.
hl.bind("ALT + Tab", hl.dsp.global("quickshell:windowsSwitcherToggle"),
    { description = "Window: K4 switch windows" })
hl.bind("ALT + SHIFT + Tab", hl.dsp.global("quickshell:windowsSwitcherPrevious"),
    { description = "Window: K4 switch windows backward" })
