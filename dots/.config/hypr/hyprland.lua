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

-- Dedicated Liquid Glass layers own their compositor blur. This namespace is
-- never used by the Material dashboard, so the override is safe at all times.
-- Use the compositor's native slide animation so the visual glass surface
-- follows the interactive dashboard on the exact same layer animation clock.
hl.layer_rule({
    match = { namespace = "quickshell:sidebar-dashboard-glass" },
    blur = false,
    blur_popups = false,
    animation = "slide",
    order = 1,
})

-- Policy glass uses side-specific namespaces so its visual layer follows the
-- exact same compositor direction as the interactive policy sidebar.
hl.layer_rule({
    match = { namespace = "quickshell:sidebar-policies-glass-left" },
    blur = false,
    blur_popups = false,
    animation = "slide left",
    order = 1,
})
hl.layer_rule({
    match = { namespace = "quickshell:sidebar-policies-glass-right" },
    blur = false,
    blur_popups = false,
    animation = "slide right",
    order = 1,
})

-- Optional runtime overrides are created only while Liquid Glass is active.
-- Use dofile instead of require so a Hyprland reload always re-reads the
-- generated fragment rather than retaining Lua's module cache.
local liquidGlassOverride = HOME .. "/.config/hypr/hyprland/shellOverrides/liquid-glass.lua"
if is_file_exists(liquidGlassOverride) then
    dofile(liquidGlassOverride)

    -- The generated runtime fragment defines the vynx preset first. Register
    -- the policy-only namespaces afterward so detached Material windows remain
    -- outside the HyprGlass layer path.
    if hl.plugin.hyprglass then
        local hg = hl.plugin.hyprglass
        hg.layer("quickshell:sidebar-policies-glass-left", { preset = "vynx", mask_threshold = 0.0025 })
        hg.layer("quickshell:sidebar-policies-glass-right", { preset = "vynx", mask_threshold = 0.0025 })
    end
end
