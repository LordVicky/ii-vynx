# K4 Control Center V2 — Prototype-Fidelity Specification

Status: implemented; live shell validation pending

## Goal

Replace the current K4 Control Center home layout with the supplied desktop-first prototype while preserving K4's existing island ownership, plugin arbitration, and one-owner service boundaries.

The supplied prototype is the visual contract. The QML implementation should stay as close as practical to its authored geometry, hierarchy, spacing, card proportions, and navigation depth rather than reinterpret it into a different dashboard.

## Fixed review point

- Original K4 base branch: `agent/k4-bar-port`
- Original K4 base commit: `ce62017970532525207f426d0bf2f2f270cca069`
- Implementation branch: `agent/k4-control-center-v2`
- Sizing/fix integration: `agent/k4-sizing-controls@3f7cf3546a56cd8881e3dc67169088f669822909`, merged into this branch as `87f9048956d2151b006d671eaa51e815fada4521`.
- Existing K4 scope remains governed by `docs/k4-bar-port/SPEC.md` and `docs/k4-bar-port/K4-V1-SYNC-DESIGN.md`.

## Product decisions

1. The old reorderable `K4ShortcutStrip` is replaced by the prototype's fixed desktop-focused home composition.
2. The home page contains six primary tool tiles: Capture, Record, Clipboard, Windows, Displays, Settings.
3. Record behavior is live-backed: when idle it opens the existing Capture plugin focused on recording choices; while recording it becomes Stop Recording and delegates to the existing capture/record owner.
4. Secondary desktop tools are Files, System, Weather, and Session, launched through their existing sibling K4 plugins.
5. Only data already exposed through existing K4/ii-vynx owners may be rendered. Prototype-only mock telemetry must not become placeholders, fabricated values, explanatory filler rows, or new background owners.
6. Wi-Fi, Bluetooth, Sound, and Notifications remain same-island detail views owned by `K4PanelPlugin`.

## Prototype geometry and hierarchy

The home controls state should target the prototype's compact desktop proportions:

- logical island content baseline: approximately 690 × 430 px before expanded-width scaling;
- `K4Settings.widthScale` may widen expanded K4 surfaces from the baseline without changing the Control Center's authored internal hierarchy;
- outer panel padding: 14 px top, 16 px sides/bottom;
- header: approximately 34 px high with an 11 px body gap;
- body: two columns at roughly 1.08 : 0.92 with a 10 px gutter;
- left stack: Connectivity (~84 px), Sound (~94 px), Tools (remaining height);
- right stack: Now Playing (~142 px), Desktop tools (remaining height);
- cards: ~18 px radius with quiet dark surfaces and subtle one-pixel boundaries;
- nested quick/tool tiles: ~13–14 px radius and prototype-like hover lift/state emphasis.

The home columns must size from the available panel width rather than from descendant implicit widths. Long device names, media metadata, or other live strings must elide/shrink within their pane and must never push the right-hand column outside the island clip.

The existing inverse-wing island host remains responsible for the external silhouette. This spec governs the panel contents, not a detached window.

## Header

Preserve the prototype's three-part header:

- left: Control Center title with a compact mark;
- center: current K4 workspace indicators;
- right: live clock, notification button/count state, collapse/close affordance.

For non-home detail tabs, retain a back affordance and title while keeping the same overall header visual language.

## Home — left column

### Connectivity card

Render Wi-Fi and Bluetooth as adjacent quick tiles.

Wi-Fi may show only existing live state from `K4Wifi`, including enabled/off and current network/status text. The circular state control toggles Wi-Fi without also opening the detail view. The rest of the tile opens the Wi-Fi detail.

Bluetooth may show only existing live state from `K4Bluetooth`. Prefer the first connected device name when present; otherwise show On/Off/No adapter. The circular state control toggles Bluetooth without also opening the detail view. The rest of the tile opens Bluetooth detail.

### Sound card

Match the prototype's compact primary-volume card:

- title and active output device name;
- mute control;
- live volume slider and percentage;
- live output summary;
- Change device action opening the Sound detail.

Do not duplicate PipeWire ownership.

### Primary tools card

Replace `K4ShortcutStrip` with a fixed 3 × 2 grid:

- Capture -> existing `capture` plugin;
- Record -> existing `capture` plugin focused on record actions, or Stop Recording when active;
- Clipboard -> `clipboard` plugin;
- Windows -> `windows` plugin;
- Displays -> `displays` plugin;
- Settings -> `settings` plugin.

Tiles launch through `K4PluginController` and close the panel before the sibling plugin takes island ownership.

## Home — right column

### Now Playing card

Match the prototype's larger media card using `K4Media` only:

- artwork when available, otherwise the existing music glyph fallback;
- NOW PLAYING eyebrow;
- live title and artist;
- live timeline only when the current player exposes one;
- previous/play-pause/next controls gated by player capabilities;
- elapsed / total time when timeline data exists.

When no player exists, keep the card present but show the existing truthful Nothing playing state rather than mock track metadata.

### Desktop tools card

Render a 2 × 2 grid launching existing sibling plugins:

- Files;
- System;
- Weather;
- Session.

Subtitles must be truthful and live-backed where useful. Static descriptive labels such as "Recent locations" or "Lock · logout · power" are allowed because they describe the action surface; dynamic values must come from existing services. Weather may show current temperature/description only when `K4Weather.current` actually supplies it.

## Detail views

### Wi-Fi

Keep the existing password flow, scanning, connect/disconnect, saved-state, forget, and captive-portal behavior. Restyle toward the prototype's two-pane composition only with data already exposed by `K4Wifi`; do not fabricate speed, IP address, Wi-Fi generation, network throughput, or explanatory placeholder rows for unavailable telemetry.

### Bluetooth

Use live `K4Bluetooth.devices`. The prototype's My devices / Nearby split may be implemented by grouping paired/connected devices separately from unpaired available devices. Battery percentages may be shown only when `batteryAvailable` is true. Do not add explanatory filler when a live battery value is unavailable.

### Sound

Present Output and Input as two side-by-side panes when space allows. Continue using scoped `PwObjectTracker` observation and `K4AudioDevices` for selection, mute, and per-device volume.

### Notifications

Retain the existing live notification history/actions and clear behavior. Do not add the prototype's Do Not Disturb control unless an existing K4/ii-vynx notification owner already exposes a real DND state/action at implementation time.

## Sizing integration

The Control Center must coexist with the K4 sizing-controls contract:

- `K4Settings.idleWidthScale` affects only the collapsed pill;
- `K4Settings.widthScale` affects expanded plugin surfaces, including Control Center;
- the Control Center keeps a 690 px logical baseline at scale 1.0;
- internal home/detail panes remain shrinkable and consume the actual available content width at every supported expanded-width scale;
- no Control Center-specific second scaling system is introduced.

## Architecture constraints

- `K4PanelPlugin` remains priority-60 panel state/navigation owner.
- `K4PanelView` remains the main composition surface.
- `K4PluginController` remains the registry/arbitration seam for sibling utility launches.
- Built-ins remain statically/declaratively owned by `K4BuiltinPlugins.qml`.
- No new daemon, polling loop, MPRIS owner, PipeWire owner, NetworkManager owner, Bluetooth owner, notification owner, capture owner, workspace owner, or monitor owner.
- Preserve current active-screen routing, focus policy, background-tap policy, Escape behavior, hover-close behavior, suppression behavior, K4 sizing controls, and K4 dark visual language.

## Source changes expected

Primary:

- `K4PanelPlugin.qml`
- `K4PanelView.qml`
- `K4PanelWifiView.qml`
- `K4PanelBluetoothView.qml`
- `K4PanelAudioView.qml`
- `K4CapturePlugin.qml` for a narrow record-focused open entry point
- `tests/k4-panel.test.js`
- capture regression tests if the new record-focused entry point warrants them

`K4ShortcutStrip.qml` and `K4ShortcutSettings.qml` may remain for compatibility/history if referenced elsewhere, but the Control Center V2 home must not render the old shortcut strip.

## Acceptance

The implementation is accepted when:

1. The home layout is recognizably faithful to the supplied prototype in baseline size, two-column proportions, card order, tool-grid placement, and hierarchy.
2. At the 690 px / widthScale 1.0 baseline, both home columns are visible and no live text or descendant implicit width can push Now Playing/Desktop Tools outside the island clip.
3. Supported `K4Settings.widthScale` values widen the expanded island without introducing a second Control Center scaling mechanism.
4. The old visible shortcut strip is gone.
5. All ten home tool entries launch their existing K4 owners without duplicating service ownership.
6. Record opens Capture focused on recording choices when idle and becomes Stop Recording when recording is active.
7. Wi-Fi, Bluetooth, Sound, media, weather, notification, clock, workspace, and recording values are live-backed; no prototype mock telemetry or explanatory placeholder rows are hard-coded as if they belong in the live surface.
8. Wi-Fi/Bluetooth nested toggle controls do not also trigger detail navigation.
9. Detail views preserve existing functional behavior while adopting the prototype's layout where live data supports it, and two-pane detail layouts remain shrinkable inside the host.
10. Existing K4 owner/arbitration/focus/active-screen/sizing tests remain valid.
11. Source regression coverage explicitly protects prototype home composition, sibling-plugin routing, record semantics, sizing/clipping behavior, and the no-placeholder/no-duplicate-owner constraints.
12. Final review is performed on both Standards and Spec axes against the original K4 base plus the sizing sync merge point recorded above.
