# k4 Dynamic Island Bar Port — Specification

Status: approved for implementation

## Source and review anchors

- Target repository: `LordVicky/ii-vynx`
- Working branch: `agent/k4-bar-port`
- Base branch: `agent/liquid-glass-stage1`
- Upstream source: `k4ditano/k4`
- Upstream snapshot inspected for this spec: `48993812c88f0af5d0c5345cd273467043b889f1` (2026-08-22)
- k4 license: MIT. Adapted/copied source must carry attribution and the repository license copy convention must be followed.

## Goal

Add the k4 Dynamic Island bar to the Illogical Impulse panel family as a second, mutually exclusive bar implementation. The current ii-vynx bar remains intact and is the default. A user can select the k4 bar in Settings; selecting it unloads the standard horizontal/vertical bar surfaces and loads the k4 island implementation instead.

The port is intentionally fidelity-first. Initial behavior should match k4 at the pinned upstream snapshot before ii-vynx-specific customization is introduced.

## Product decisions

1. **Scope:** full k4 bar experience, not only the collapsed pill. The target includes the island host and k4's built-in island views/features, progressively brought to parity.
2. **Coexistence:** the existing ii-vynx bar is not rewritten. Standard and k4 bars coexist in the codebase but only one owns the bar surface at runtime.
3. **Collapsed state:** reproduce k4 faithfully, including clock/workspace transition, media artwork/visualizer, indicators, symmetric side allocation, and k4 defaults.
4. **Interaction defaults:** preserve k4 defaults. Behavior customization is deferred until parity is established.
5. **k4 panel/control center:** preserve the k4 panel experience. Do not redirect island-background interactions to ii-vynx sidebars.
6. **Existing ii sidebars/control center:** remain available outside the k4 island through existing shell mechanisms such as screen-corner interactions. They are not embedded into the island.
7. **Notifications:** support k4's notification-to-island behavior, including transient arbitration/preemption semantics.
8. **Placement:** k4 mode supports top and bottom only. No vertical/left/right island variant in the parity phase.
9. **Settings ownership:** k4 position/alignment settings are independent from the standard bar so switching variants preserves each bar's configuration.
10. **Visual surface:** use k4's existing dark surface/colors for parity. Do not integrate Material or Liquid Glass surfaces yet.
11. **Geometry:** preserve k4's inverse wings and edge-attached silhouette pixel-faithfully.
12. **Exclusive zone:** preserve k4 behavior: reserve only the collapsed island height while expanded content overlays windows.
13. **Auto-hide:** do not port or adapt ii-vynx standard-bar auto-hide into k4 mode during parity work.
14. **Multi-monitor:** preserve k4 behavior: idle pill on each eligible screen; one expanded global action on the selected/active screen.
15. **Settings UX:** Bar Settings starts with a bar-variant selector. Standard-only controls are hidden when k4 mode is selected; k4-only controls are shown instead.

## Terminology

Use these names consistently in code and documentation:

- **bar variant** — mutually exclusive top-level bar implementation: `standard` or `k4`.
- **island host** — the `PanelWindow`/state-controller boundary that owns silhouette, geometry, keyboard policy, active-screen behavior, and plugin view loading.
- **island state** — shell-wide state analogous to upstream `services/Island.qml`: occupant, open state, active/requested screen, placement override, gestures, published geometry, and temporary hiding.
- **island plugin** — a k4-style view/controller unit with activation state, priority, dimensions, and optional keyboard/hover/transient semantics.
- **idle pill** — the always-available collapsed island plugin.
- **transient** — an island plugin such as a notification/toast that may activate spontaneously and must yield to an explicit user-opened view.
- **adapter** — a narrow boundary exposing ii-vynx shell services to ported k4 code where duplicate system ownership would be unsafe.

Do not call the existing `barGroupStyle === 1` feature the k4 island; that setting only changes group backgrounds in the standard bar.

## Architecture

### 1. Variant boundary

`Config.options.bar.variant` is the sole top-level selector:

```qml
property string variant: "standard" // "standard" | "k4"
```

`IllogicalImpulseFamily.qml` owns mutual exclusion:

- standard horizontal/vertical bar loaders and their Liquid Glass helper surfaces load only when `variant === "standard"`;
- the k4 island host loads only when `variant === "k4"`;
- unrelated ii modules (background, sidebars, dock, OSD, lock, overview, screen corners, etc.) remain unchanged unless a concrete conflict is demonstrated.

The standard bar's existing config is left intact.

### 2. k4-specific config

Create a dedicated nested object under `Config.options.bar`, initially containing parity-critical host settings only:

```qml
property JsonObject k4: JsonObject {
    property string position: "top"      // "top" | "bottom"
    property int alignment: 50           // upstream defaults/options: 15 | 50 | 85
}
```

Additional k4 settings should be ported with the feature that consumes them, rather than creating disconnected switches in advance.

### 3. Island host as a deep module

Create a dedicated module under the ii family, expected root:

`modules/ii/k4bar/`

The island host must own:

- one `PanelWindow` per eligible screen;
- top/bottom anchoring;
- collapsed exclusive zone;
- surface growth/shrink policy;
- pixel-faithful body + inverse wings;
- per-screen input mask;
- active-screen selection;
- keyboard focus policy;
- active-plugin arbitration;
- transient dismissal when an explicit non-transient view wins;
- hover-exit coordination;
- island geometry publication;
- k4 physical gestures;
- temporary hiding for capture/system-dialog cases.

These responsibilities must not be distributed into individual plugin views.

### 4. Island state service

Port the semantics of upstream `services/Island.qml` into an ii-owned singleton in the k4bar module. Preserve the public concepts while using English/project-consistent names where practical.

Required state/behavior:

- `hovered`
- current `occupant`
- expanded/open state
- requested and active screen
- focused-screen fallback
- base placement and temporary owned placement override
- published island rectangles per screen
- gesture arbitration and cooldown
- temporary hidden state
- system-dialog counter / interaction suppression

The host writes authoritative occupant/open/geometry state. Plugins request behavior through the service.

### 5. Plugin boundary

Preserve k4's plugin arbitration model rather than converting every k4 view into a standard ii bar component.

A plugin interface should expose the equivalent of:

- id/name
- enabled/lifecycle state
- `active`
- `priority`
- `islandWidth`
- `islandHeight`
- view component
- keyboard policy
- background-tap policy
- hover-exit policy
- `transient`
- `open`/`close` behavior where applicable

The implementation may simplify upstream dynamic plugin discovery during the first tracer bullets, but the final parity target includes k4's built-in/plugin-host behavior. Broken/disabled plugins must not be able to prevent the island host from loading.

### 6. Service ownership and adapters

Do **not** blindly duplicate services that own a global desktop facility. k4 and ii-vynx both implement audio, media, networking/Bluetooth, notifications, clipboard, workspaces, app search, session actions, and related system integration.

For each ported plugin, classify its dependencies:

1. **Reuse/adapt ii service** when ii-vynx already owns the same global facility or duplicate ownership risks conflict.
2. **Port k4 service locally** when behavior is k4-specific and has no conflicting ii owner.
3. **Bridge narrowly** when k4's view requires a richer model than ii currently exposes.

Adapters should be thin and stable. Ported views should depend on the adapter contract rather than scattered direct references to unrelated ii modules.

Notification serving is a mandatory conflict check: only one notification server/owner may be active. The k4 toast/history UI must consume the chosen shared notification state rather than starting a competing server.

### 7. Existing ii surfaces

The k4 variant replaces only the bar surface. Existing ii-vynx modules remain available unless a demonstrated runtime ownership conflict requires gating.

In particular:

- screen corners remain active and may open ii sidebars/control surfaces;
- k4's own control center remains faithful inside the island;
- standard-bar-specific helper glass layers are disabled in k4 mode;
- standard bar auto-hide machinery is not reused in k4 mode;
- Liquid Glass integration is explicitly deferred.

## Fidelity requirements

### Silhouette

Match upstream k4 geometry:

- inverse edge wings;
- body radius behavior;
- top/bottom reflection semantics;
- antialiasing approach sufficient to preserve the wing shape;
- expanded geometry stays attached to the configured screen edge.

### Collapsed pill

Match upstream defaults:

- center clock when idle;
- temporary workspace indicator after workspace changes;
- media artwork + visualizer on the left while playing;
- right-side contextual indicators;
- symmetric left/right reservation so center content remains truly centered;
- default tray-in-pill behavior remains off unless the corresponding k4 setting is later ported/enabled.

### Expansion and arbitration

Match upstream behavior:

- highest-priority enabled active plugin wins;
- idle is fallback;
- explicitly opened non-transient view dismisses lower-priority transient views;
- expanded action is shown only on the active/requested screen;
- other eligible screens retain idle pills;
- active-screen selection uses the interaction origin when available and focused monitor otherwise;
- expanding does not increase the compositor exclusive zone beyond the collapsed bar height.

### Focus/input

Match upstream intent:

- idle does not grab keyboard focus;
- text-entry views can request exclusive focus;
- optional/on-hover keyboard policies are supported where required;
- Escape closes the active plugin after nested controls have had a chance to consume it;
- when the island is temporarily hidden/apart, its input mask is removed so invisible UI cannot eat clicks.

## Settings behavior

Update Bar Settings with a top-level selector:

- **Standard**
- **k4 Dynamic Island**

When Standard is selected, preserve the current Bar Settings UI.

When k4 is selected:

- hide standard layout arrays;
- hide standard size controls;
- hide vertical left/right placement;
- hide standard corner/group/background styles;
- hide standard auto-hide controls;
- show k4 top/bottom position;
- show k4 alignment controls;
- add later k4 settings only when their consuming feature is implemented.

Switching variants must not overwrite either variant's saved settings.

## Licensing and attribution

k4 is MIT licensed. Before copied/adapted k4 implementation code lands:

- add a dedicated k4 MIT license copy/attribution entry under `licenses/` following the existing ii-vynx convention;
- files substantially copied from k4 must include an appropriate source/license notice;
- adapted source comments may be translated/cleaned up, but attribution must remain clear.

## Non-goals for parity phase

- no vertical/left/right Dynamic Island;
- no Liquid Glass or Material recoloring of the island;
- no ii standard-bar auto-hide integration;
- no custom hover/click behavior editor;
- no attempt to make standard `BarComponent` arrays arbitrarily embeddable in the island;
- no replacement of k4 control-center/panel views with ii sidebars;
- no broad refactor of unrelated ii-vynx services without a demonstrated adapter need.

## Implementation strategy

This feature is too large for one implementation unit. Use tracer bullets. Each ticket must deliver a runnable end-to-end behavior through the real shell boundary and preserve standard-bar behavior.

The initial sequence is:

1. variant/config/settings loader boundary + inert island host;
2. faithful silhouette + idle pill + multi-monitor ownership;
3. island state and active-plugin arbitration;
4. media/clock/volume views through adapters;
5. notifications/transients through the shared notification owner;
6. k4 panel/control center and core system views;
7. launcher/clipboard/files/windows/session/system/settings views;
8. capture/editor and other k4-specific tools that require their own services;
9. plugin lifecycle/extensibility parity and remaining bundled plugins;
10. parity review, performance review, and cleanup.

Tickets may be split further when a slice cannot be implemented/reviewed independently.

## Acceptance criteria

The parity effort is complete when all of the following are true:

1. `standard` remains the default and behaves as it did on `agent/liquid-glass-stage1`.
2. Settings can switch between Standard and k4 variants without restarting the shell beyond normal config-driven loader behavior.
3. Only the selected bar implementation owns a bar surface.
4. k4 supports top and bottom placement and independent alignment settings.
5. The island silhouette and inverse wings visually match upstream k4 at the pinned snapshot.
6. The collapsed idle pill matches upstream default content and interaction behavior.
7. Multi-monitor idle/expanded ownership matches upstream.
8. Expanded island content overlays windows while only the collapsed height is reserved.
9. k4 plugin priority/transient semantics work, including notification preemption.
10. k4's own panel/control center remains an island view; ii sidebars are not substituted for it.
11. Notification integration does not run a competing notification server.
12. All ported global facilities have an explicit ownership/adaptation decision.
13. Disabling or breaking one optional island plugin cannot remove the entire bar.
14. k4-derived source is attributed under the repository's license convention.
15. Available lint/tests/checks pass; hardware/compositor behaviors not testable automatically have an explicit manual validation checklist.
16. A final code review is performed against both repository standards and this specification.

## Manual validation matrix

At minimum validate on the real shell:

- Standard variant top and bottom (regression smoke test).
- k4 top/center and bottom/center.
- k4 left/center/right alignment presets along the top/bottom edge.
- one monitor and multiple monitors.
- no media / paused media / playing media.
- workspace change idle transition.
- notification arrival while idle.
- notification arrival while another island plugin is open.
- explicit plugin open while a transient is visible.
- keyboard-entry plugin + Escape behavior.
- screen capture/system dialog while island is visible.
- switching Standard → k4 → Standard while preserving both configurations.
- existing ii screen-corner sidebar interactions while k4 variant is active.

## Deferred customization frontier

After parity is accepted, start a new design phase before changing k4 behavior. Likely topics include:

- Material/Liquid Glass island surfaces;
- custom hover/click activation behavior;
- auto-hide;
- configurable collapsed-pill contents;
- deeper integration with ii sidebars or other shell modules;
- new island-only plugins built from ii-vynx features.
