# OpenRGB Effects Widget Design

## Goal

Extend the OpenRGB desktop widget with discovery and activation of effect profiles provided by the OpenRGB Effects Plugin, while preserving the existing standard OpenRGB profile controls.

## Architecture

`OpenRgb.qml` remains the single backend for the widget. It will discover the running OpenRGB StatusNotifierItem through the session D-Bus, read its `com.canonical.dbusmenu` layout, locate `Effects` → `Profiles`, and convert each child menu item into an effect record containing its label and current D-Bus menu ID.

The D-Bus service name and menu IDs are runtime values and must never be persisted. Every refresh resolves the current OpenRGB tray item and menu layout again. This guarantees that effect profiles created, installed, renamed, or removed since the previous refresh are reflected immediately.

## State and Behavior

- Add an in-memory `effects` collection and a persisted `activeEffect` name.
- Persist `activeKind` as `profile` or `effect` only after the corresponding Apply action succeeds. Power behavior follows this last successfully applied item, never the staged browser selection.
- Extend refresh accounting to include effect discovery alongside OpenRGB availability, device discovery, and `.orp` profile discovery.
- If OpenRGB or the Effects Plugin menu is unavailable, keep standard profile controls functional and expose a concise effect-specific unavailable state.
- Apply an effect by resolving its current menu ID and sending the standard D-Bus menu `clicked` event—the same action triggered by the OpenRGB tray menu.
- Re-resolve the menu on every refresh and before activation if the cached runtime menu identity is stale.
- On successful activation, persist `activeEffect`, mark lights enabled, and clear the last effect error.
- Never edit `EffectSettings.json` or effect-profile files.

## Scoped Power Control

Before powering off, poll the current OpenRGB device list and resolve the devices assigned to the last successfully applied item. Effects Plugin profiles expose exact `ControllerZones`; match their name, description, serial, and location against current devices, including E1.31-backed WLED devices. Standard `.orp` profiles embed device identities; match those identities against the same live device list.

When the applied item is an effect, invoke the plugin's current `Stop all effects` action first. Then apply `000000` only to the resolved OpenRGB device indices. If no assigned devices can be matched, report an error and leave devices unchanged rather than falling back to all devices.

Power-on reapplies the last successfully applied item: `activeEffect` when `activeKind` is `effect`, or `activeProfile` when `activeKind` is `profile`. Turning off does not erase the active item or its kind.

## Widget UI

Use the approved Mode Switch layout. A two-option `Profiles`/`Effects` switch chooses which collection the single central selector browses. Previous and next controls only change a staged selection; browsing must never apply a profile or effect. A dedicated `Apply profile` or `Apply effect` button activates the staged item, and a separate label identifies the currently active item.

Refresh rediscovers both collections and preserves the staged selection by name when it still exists, otherwise selecting the active item or first available item. The widget remains compact and continues using its existing adaptive colors, scale controls, shared buttons, and busy-state handling.

## Error Handling

D-Bus discovery and activation errors are collected from the backend process and shown through the widget's existing status/error presentation. Missing effect support does not make OpenRGB itself unavailable. Activation is disabled while discovery or another OpenRGB action is active.

## Verification

- Confirm a fresh refresh returns the same effect-profile labels shown under the live tray menu's `Effects` → `Profiles` submenu.
- Add or rename an effect profile, refresh, and confirm the in-memory/widget list changes without a Quickshell restart.
- Activate a known effect and confirm the D-Bus call succeeds and the active effect updates.
- Confirm standard `.orp` profile selection and lights on/off still work.
- Confirm an effect containing WLED resolves the corresponding live E1.31 device and scopes black output to the effect's assigned devices.
- Confirm power-on reapplies the selected effect after effect-scoped power-off and the selected profile after profile-scoped power-off.
- Confirm unresolved scope fails without issuing an all-device color command.
- Run `git diff --check`, reload `qs -c ii`, and inspect fresh logs for OpenRGB QML errors.
