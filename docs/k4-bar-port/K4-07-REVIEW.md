# K4-07 — Launcher and Everyday Utilities Review

Branch: `agent/k4-bar-port`

Ticket: `K4-07 — Launcher and everyday utility plugins`

Implementation base: `865b0bc0b3e72fe83dc8fce4bcab4ea760548c66` (K4-06 close)

Fixed code-review point: `cd9162d33f89ef7d6f2e3f015392888bf58f0af7`

Pinned k4 source: `48993812c88f0af5d0c5345cd273467043b889f1`

## State

**Awaiting live validation. K4-07 is not closed.**

The fixed review point is 32 commits ahead of the K4-06 close and contains the complete K4-07 implementation surface plus review fixes.

## Delivered scope

- K4 desktop application launcher backed by ii-vynx `AppSearch` / `DesktopEntry` ownership.
- K4 package-search/install mode with pacman/yay work scoped to package mode.
- K4 Applications utility grid over the existing K4 plugin registry.
- Variant-local launcher routing so the existing search/Super shortcut targets Standard Overview in Standard mode and K4 Launcher in K4 mode without requiring user keybind changes.
- Fullscreen launcher routing for clients that inhibit normal shortcuts.
- K4 Clipboard over ii-vynx `Cliphist` ownership.
- K4 Files with on-demand search and no global indexer.
- K4 Windows over ii-vynx `HyprlandData`.
- K4 System monitor over ii-vynx resource/network services, sampled only while required by the utility lifecycle.
- K4 Session/power actions through ii-vynx session ownership.
- K4 shortcut viewer over ii-vynx Hyprland keybind state.
- K4 Weather over ii-vynx Weather ownership.
- K4 Tray over the existing tray/SystemTray ownership.

## Review fixes included

The implementation review found and fixed concrete runtime/fidelity defects before this gate:

- launcher ownership now releases immediately on close so the host can begin its collapse animation without a blank 320 ms ownership tail;
- Standard Overview and K4 launcher routing are mutually exclusive at the panel-family boundary;
- the existing search shortcut/IPC names are reused in K4 mode instead of introducing replacement user keybinds;
- stale Standard Overview state is forced closed while K4 owns the variant;
- lazy Files view now imports `Quickshell` before using `Quickshell.env(...)`;
- Files Ctrl+Enter/open-containing-folder metadata now resolves the parent directory consistently for both file and directory hits.

## Standards review

No blocking findings remain at the fixed review point.

- Global service ownership is preserved rather than duplicated: installed applications remain in `AppSearch`, clipboard history in `Cliphist`, windows in `HyprlandData`, weather in `Weather`, tray items in the existing tray/SystemTray seam, and system/session behavior in ii-vynx services.
- Expensive or external work is lifecycle-scoped: package work is launcher package-mode work; file search is on demand; system sampling follows the utility lifecycle.
- K4 owns K4 presentation and interaction. Standard Overview is not embedded or invoked as K4 UI.
- Variant routing is expressed at the family/backend boundary so user shortcut configuration does not need to change when switching bar variants.
- Everyday utilities participate in the existing K4 plugin/arbitration contract rather than creating independent floating ownership paths.
- The parity surface remains K4-styled; this ticket does not restyle K4 with Material/Liquid Glass.
- Upstream-derived plugin surfaces identify the pinned k4 source in source comments, and repository-level MIT attribution remains in `licenses/k4-NOTICE.txt` / `licenses/MIT.txt`.

## Spec review

The fixed review point implements every K4-07 ticket category:

- launcher/apps;
- clipboard;
- files;
- windows;
- system monitor;
- session/power;
- shortcut viewer;
- weather/tray;
- preservation of the existing launcher shortcut, including the fullscreen shortcut-inhibition path.

The remaining acceptance evidence is runtime behavior in the real shell. K4-07 must not be marked closed until that live matrix passes.

## Automated evidence

Repository source-regression tests exist for the K4-07 slices, including launcher, routing, fullscreen launcher, packages, apps, clipboard, files, windows, system, session, keys, weather and tray, plus the existing K4 singleton-import guard.

The connected GitHub environment reports no CI status checks for the fixed review point, and it cannot execute the repository's local Quickshell runtime. Therefore this review does **not** claim a new automated pass count or QML runtime pass.

## Live validation gate

Validate from the branch head containing this review artifact:

1. Standard mode: existing Super/search binding opens only the normal ii Overview; no K4 launcher appears.
2. K4 mode: the same Super/search binding opens only K4 Launcher; no ii Overview/workspace surface appears.
3. K4 Launcher closes with Escape/Super and the island begins collapsing immediately without a blank delayed ownership state.
4. `qs -c ii ipc call search toggle` targets the launcher selected by the current bar variant.
5. In a true fullscreen client, the existing launcher binding still reaches K4 Launcher without taking the client out of fullscreen.
6. Launcher desktop-app search and launch work; package mode searches and performs its intended pacman/yay flow without running package work during ordinary app search.
7. Applications grid opens utilities and returns cleanly through K4 arbitration.
8. Clipboard search/select/copy works and does not open Standard Overview.
9. Files search opens hits normally; Ctrl+Enter on both a file and a directory opens the containing parent directory.
10. Windows utility lists current clients and focuses the selected client.
11. System monitor shows live resource/network values while open and closes normally.
12. Session/power surface opens and its non-destructive actions can be exercised; do not trigger destructive power actions merely for validation.
13. Shortcut viewer shows current Hyprland keybindings.
14. Weather renders current ii-vynx weather state and its normal interaction path.
15. Tray renders current tray items and at least one item/menu can be interacted with.
16. Standard → K4 → Standard switching leaves no stale launcher/utility surface resurrected across the variant boundary.
17. Existing K4 panel, media, notifications and idle-island behavior still work after exercising the utilities.

After this matrix passes, update `STATUS.md` with the live evidence, close K4-07, and proceed to K4-08.
