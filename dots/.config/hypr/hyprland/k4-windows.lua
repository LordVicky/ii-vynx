require("hyprland.lib")

-- K4 window switching stays inside the running Quickshell process. Hyprland
-- only forwards the Alt+Tab chord and modifier release to GlobalShortcut.
hl.bind("ALT + Tab", hl.dsp.global("quickshell:windowsSwitcherToggle"), {
    description = "Window: K4 switch windows",
})

hl.bind("ALT + SHIFT + Tab", hl.dsp.global("quickshell:windowsSwitcherPrevious"), {
    description = "Window: K4 switch windows backward",
})

-- Release binds intentionally ignore the current modifier state: by the time
-- ALT_L/ALT_R is released, Alt itself is no longer part of the active mods.
hl.bind("ALT_L", hl.dsp.global("quickshell:windowsSwitcherCommit"), {
    ignore_mods = true,
    transparent = true,
    release = true,
})

hl.bind("ALT_R", hl.dsp.global("quickshell:windowsSwitcherCommit"), {
    ignore_mods = true,
    transparent = true,
    release = true,
})
