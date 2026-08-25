# K4-10 — Remaining Bundled Features Review

Branch: `agent/k4-bar-port`

Ticket: `K4-10 — Remaining bundled k4 plugins/features`

Implementation base: `a9b0b5d54f6683f423e192b7de048f3ff1f04a5f` (K4-09 closure)

Final runtime review point: `ae6ed0a9706a0b4b134f952cfd99fb9530067171`

Final scope/doc review point: `4e6b6ba718261a56718ab8e45cf61fe32f063241`

Pinned k4 source: `48993812c88f0af5d0c5345cd273467043b889f1`

Authoritative plan: `docs/k4-bar-port/SPEC.md` + `docs/k4-bar-port/TICKETS.md` + `docs/k4-bar-port/K4-10-DESIGN.md`

## State

**Validated and closed on 2026-08-25.**

K4-10 was deliberately narrowed after inventorying the remaining pinned-upstream bundle under the project's no-bloat rule. The only approved feature is a lean Displays/Pantallas utility for monitor configuration. Ask, HyprTheme, Terminal, SSH, Agentes, Game and Digivice are explicit product rejections, not accidental parity gaps.

Workspace-to-monitor routing was initially explored, then explicitly removed because ii-vynx already owns workspace behavior through its dynamic workspace system. The final Displays implementation contains no workspace rules, workspace move dispatches, Workspaces tab, or second workspace configuration surface.

## Delivered surface

The K4 Applications grid includes a Displays application with:

- active monitors from the existing `HyprlandData.monitors` snapshot;
- current mode/resolution/refresh information;
- scale controls;
- 0/90/180/270-degree transform controls;
- current compositor position;
- relative Left/Right/Above/Below/Mirror placement controls for multi-monitor sessions;
- in-memory drafts that do not affect Hyprland until Apply;
- Refresh that discards draft state and reloads the existing live monitor snapshot;
- session-only Apply through a one-shot `hyprctl eval` process;
- visible apply errors while keeping the utility open.

No persistent monitor configuration is written by K4-10.

## Ownership and dependency boundary

No new monitor polling service or helper daemon was introduced.

- `HyprlandData` remains the monitor-state owner.
- Displays clones `HyprlandData.monitors` only into local in-memory draft objects.
- Apply invokes the already-installed `hyprctl` command as a short-lived process.
- Successful apply refreshes the existing `HyprlandData` monitor snapshot.
- No upstream `pantallas.py` helper is present.
- No Python service, new singleton, daemon, package dependency, config writer or generated monitor file was added.
- No `HyprlandData.workspaces`, `workspacerules`, `workspace_rule`, or workspace-move ownership exists in the final Displays plugin.

The final fixed-point compare from the K4-09 closure changes only the K4-10 design document, `K4BuiltinPlugins.qml`, the two K4 Displays files, the focused Displays test, and one K4 Capture test assertion relaxed from registry adjacency to membership.

## Source validation

The user ran the full accumulated `node --test tests/k4-*.test.js` suite after the final workspace-routing removal and reported that all tests passed.

The latest explicit count immediately before the removal was 113/113 with zero failures; the final change replaces the positive workspace-routing assertion with a negative ownership assertion rather than adding or removing a test case.

`tests/k4-displays.test.js` now covers both the monitor-only adapter contract and the invariant that Displays must not duplicate dynamic workspace ownership.

The existing Node `MODULE_TYPELESS_PACKAGE_JSON` reparsing warnings remain non-failing repository/test-runner warnings and are unrelated to K4-10 runtime behavior.

## Live validation — 2026-08-25

The available single-monitor live matrix passed:

1. Displays appears in Applications and opens normally.
2. Current monitor data is shown correctly.
3. Draft state is local until Apply.
4. Refresh discards local draft changes and restores live compositor state.
5. Apply works for session-only monitor configuration.
6. Safe mode/scale changes apply successfully.
7. No `pantallas.py`/`k4-displays` helper process remains running.
8. No upstream helper/config file is present in the deployed Quickshell tree.
9. After workspace routing was removed, the user reported the final regression/live checks all passed.

Actual cross-monitor Left/Right/Above/Below/Mirror compositor behavior could not be exercised because the validation machine currently has one connected monitor. The source contract and UI are present; real multi-monitor compositor validation is explicitly deferred to K4-12.

The supplied runtime logs contain pre-existing/shared warnings from FloatingActionButton/Revealer, ToolbarPairedFab/NotesWidget, portal startup, Persistent `popupRect`, translations/extensions, desktop-entry parsing, caffeine icons, QuickSliders and optional `khal`. No warning is attributed to `K4DisplaysPlugin.qml` or `K4DisplaysView.qml`, and the exercised Displays paths pass live.

## Standards review

No blocking findings at the final runtime review point.

- Displays is a narrow K4 presentation/controller over the existing monitor owner rather than a second Hyprland monitor service.
- Draft state is local to the plugin and only crosses the compositor boundary on explicit Apply.
- The one-shot process has a small interface: a generated `hl.monitor(...)` statement list sent through `hyprctl eval`.
- Refresh/error behavior remains inside the plugin instead of broadening `HyprlandData` APIs.
- The Standard bar, Liquid Glass surfaces, shared Hyprland services and user Hyprland configuration are unchanged.
- No heavyweight remaining upstream application was ported.
- The final negative workspace regression prevents a redundant K4 workspace-management surface from returning accidentally.

One non-code-history hygiene issue remains: the branch history still contains the temporary staging commit `accf236bf261fc406c20b07cb70df9978c0724bc` and the subsequently reverted workspace-routing exploration commits. Their content is absent from the final tree. Removing them would require a destructive history rewrite/force update and is therefore not performed without explicit user approval.

## Spec review

K4-10 satisfies the approved product interpretation recorded in `K4-10-DESIGN.md`:

- the remaining pinned-upstream bundle was inventoried before implementation;
- Pantallas/Displays is retained only as a useful desktop primitive;
- Displays reuses existing ii-vynx monitor state and does not introduce duplicate global ownership;
- monitor editing remains session-only and does not mutate the user's Hyprland config;
- Ask, HyprTheme, Terminal, SSH, Agentes, Game and Digivice are explicitly rejected;
- workspace routing remains with ii-vynx's existing dynamic workspace system;
- no new external dependency or helper service was introduced;
- full source regression and available real-shell validation are green;
- real multi-monitor compositor validation is deferred to the final K4-12 QA stage because the current validation machine has one monitor.

## Closure

K4-10 is closed.

Next ticket: `K4-11 — Plugin lifecycle/extensibility parity`.

K4-11 must begin with architecture/alignment rather than immediately replacing the static registry. The first task is to inspect pinned upstream plugin loading, failure isolation, dependency gating, settings/error semantics and external-plugin boundaries against the current `K4BuiltinPlugins` / `K4PluginController` seam. Any new filesystem watcher, plugin store, package manager, background daemon, or heavyweight installation mechanism remains subject to the project's no-bloat/new-dependency approval gate.
