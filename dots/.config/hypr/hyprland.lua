-- This file sources other files in `hyprland` and `custom` folders
-- You wanna add your stuff in files in `custom`

-- Internal stuff --
require("hyprland.lib")
require("hyprland.services")

-- Environment variables --
require("hyprland.env")
if is_file_exists(HOME .. "/.config/hypr/custom/env.lua") then
    require("custom.env")
end

-- Default configurations --
require("hyprland.execs")
require("hyprland.general")
require("hyprland.rules")
require("hyprland.colors")
require("hyprland.keybinds")
require("hyprland.k4-windows")
require("hyprland.launcher")

-- Custom configurations --
if is_file_exists(HOME .. "/.config/hypr/custom/execs.lua") then
    require("custom.execs")
end
if is_file_exists(HOME .. "/.config/hypr/custom/general.lua") then
    require("custom.general")
end
if is_file_exists(HOME .. "/.config/hypr/custom/rules.lua") then
    require("custom.rules")
end
if is_file_exists(HOME .. "/.config/hypr/custom/keybinds.lua") then
    require("custom.keybinds")
end

-- nwg-displays support: re-add the files if it updates later
-- require("workspaces")
-- require("monitors")

-- Shell overrides --
require("hyprland.shellOverrides.main")

-- K4 owns expansion/collapse motion inside QML. Do not let Hyprland animate
-- the resizing layer surface independently; compositor motion can invalidate
-- the stationary-pointer hover session during bottom expansion.
hl.layer_rule({
    match = { namespace = "quickshell:k4bar" },
    no_anim = true,
})
