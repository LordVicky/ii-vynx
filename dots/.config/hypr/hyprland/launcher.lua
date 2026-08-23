-- Keep the shell launcher reachable when a fullscreen application requests
-- shortcut inhibition. This rewrites only the two default Super-only launcher
-- binds; custom/keybinds.lua is sourced afterward and therefore retains final
-- ownership for users who intentionally override them.
local qsIpcCall = "qs -c $qsConfig ipc call"
local qsIsAlive = qsIpcCall .. " TEST_ALIVE"

hl.unbind("SUPER + SUPER_L")
hl.unbind("SUPER + SUPER_R")

hl.bind("SUPER + SUPER_L", hl.dsp.global("quickshell:searchToggleRelease"),
    { bypass = true, description = "Shell: Toggle search" })
hl.bind("SUPER + SUPER_R", hl.dsp.global("quickshell:searchToggleRelease"),
    { bypass = true })

hl.bind("SUPER + SUPER_L", hl.dsp.exec_cmd(qsIsAlive .. " || pkill fuzzel || fuzzel"),
    { bypass = true })
hl.bind("SUPER + SUPER_R", hl.dsp.exec_cmd(qsIsAlive .. " || pkill fuzzel || fuzzel"),
    { bypass = true })
