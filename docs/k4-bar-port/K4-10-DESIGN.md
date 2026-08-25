# K4-10 — Remaining bundled feature disposition

Status: approved for implementation

## Decision

K4-10 no longer targets literal parity with every bundled plugin at the pinned upstream snapshot. The remaining catalog was inspected feature-by-feature under the project's newer no-bloat rule: keep useful desktop primitives, reuse existing ii-vynx/Quickshell owners, and stop before introducing heavyweight applications, duplicate services, custom daemons, or new external dependencies.

Pinned upstream catalog: `k4ditano/k4@48993812c88f0af5d0c5345cd273467043b889f1`.

## Approved scope

### Pantallas / Displays

Port a lean K4 monitor-arrangement utility.

Architecture:

`K4 Displays UI -> existing HyprlandData monitor/workspace snapshots -> in-memory draft -> one-shot hyprctl apply adapter`

Rules:

- reuse `HyprlandData.monitors` and `HyprlandData.workspaces`; do not add a second monitor/workspace polling service;
- no upstream `pantallas.py` service/helper;
- no daemon;
- no new external dependency;
- edits remain in memory until Apply;
- K4-10 is session-only: do not write `hyprland.lua`, generated monitor Lua files, or other persistent compositor config;
- support active-monitor mode, scale, transform and position arrangement where the existing Hyprland snapshot provides the required data;
- support workspace-to-monitor assignment as a second vertical slice after the monitor-layout slice is live-validated;
- refresh the existing `HyprlandData` snapshots after a successful apply;
- failed apply must leave the utility open and expose an error rather than silently closing;
- keep the K4 plugin/application lifecycle consistent with existing K4 utilities.

Persistence is deliberately deferred. If persistent monitor layout/workspace routing is wanted later, design it around an ii-owned override seam instead of mutating the user's main Hyprland entry file.

## Explicitly rejected upstream features

The following pinned-upstream plugins are intentionally out of scope and must not be implemented under K4-10:

- Ask
- HyprTheme
- Terminal
- SSH
- Agentes
- Game
- Digivice

These are explicit product decisions, not accidental parity gaps.

### Rationale summary

- **Ask:** upstream is a Codex CLI frontend; ii-vynx already owns AI through its own runtime/UI. User rejected the feature rather than adding another K4-facing AI surface.
- **HyprTheme:** overlaps shell theme/wallpaper ownership and includes wallpaper-browser/daemon behavior. Rejected as bloat/duplicate ownership.
- **Terminal:** depends on the external `k4term` terminal stack. Rejected.
- **SSH:** upstream expands into host/config/password/tunnel management and k4term coupling. Rejected.
- **Agentes:** specialized Claude/Codex account-usage instrumentation and credential/session inspection. Rejected.
- **Game / Digivice:** persistent game subsystems rather than desktop primitives. Rejected.

## Staged delivery

### Slice 1 — monitor layout

- application entry and island UI;
- active monitors from `HyprlandData.monitors`;
- mode, scale, rotation and relative placement drafts;
- session-only Apply through `hyprctl eval`;
- refresh/error handling.

### Slice 2 — workspace assignment

- existing workspace state from `HyprlandData.workspaces`;
- in-memory workspace-to-monitor draft;
- session-only workspace routing through one-shot `hyprctl` commands;
- no generated workspace rules/config files;
- refresh/error handling through the same Displays ownership boundary.

## Acceptance checks

1. Displays appears in the K4 applications list and opens/closes normally.
2. Opening it shows the active monitors already known to `HyprlandData`.
3. Selecting a monitor exposes current mode, scale, transform and position.
4. Draft edits do not affect the compositor until Apply.
5. Apply uses a one-shot `hyprctl eval` path; no helper service/process remains running afterward.
6. Successful apply refreshes `HyprlandData` and updates the displayed live state.
7. Apply failure is visible in the utility and does not corrupt the draft or close the island.
8. Workspace assignment uses the existing workspace snapshot and session-only Hyprland commands.
9. No files under `~/.config/hypr` are written by this feature.
10. No new service singleton, Python helper, daemon or external dependency is introduced.
11. Existing Standard-bar and non-K4 monitor behavior remain untouched.

## Review boundary

K4-10 is complete when both Displays slices are live-validated and the rejected features remain absent. K4-11 may then address plugin lifecycle/extensibility independently.
