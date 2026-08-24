# K4-07 — Launcher and Everyday Utilities Review

Branch: `agent/k4-bar-port`

Ticket: `K4-07 — Launcher and everyday utility plugins`

Implementation base: `865b0bc0b3e72fe83dc8fce4bcab4ea760548c66` (K4-06 close)

Pinned k4 source: `48993812c88f0af5d0c5345cd273467043b889f1`

Authoritative plan: `docs/k4-bar-port/SPEC.md` + `docs/k4-bar-port/TICKETS.md`

## State

**Live validation remediation in progress. K4-07 is not closed.**

The first integrated live pass found blocking runtime defects in fullscreen launcher routing, clipboard presentation, weather glyph rendering, and tray discoverability. Those findings are being fixed and revalidated before ticket closure.

## Approved K4-07 scope

The ticket explicitly covers:

- launcher/apps;
- clipboard;
- files;
- windows;
- system monitor;
- session/power;
- shortcut viewer;
- weather/tray where not already completed;
- preservation of the existing Super launcher binding, including the fullscreen shortcut-inhibition path.

Each sub-slice must reuse existing ii-vynx service ownership where practical and avoid broad unrelated service APIs.

### Scope correction

An Arch-specific pacman/yay package-search/install mode was temporarily carried into the launcher while following upstream launcher internals. That behavior is **not part of the approved K4-07 ticket or implementation sequence** and has been removed.

K4 Launcher now stays inside the Quickshell shell boundary: ii-vynx `AppSearch`/`DesktopEntry` owns application discovery and execution, while K4 owns the Spotlight-style launcher presentation and interaction. Package management is not a core bar responsibility.

## Delivered ownership seams

- Desktop applications: ii-vynx `AppSearch` / `DesktopEntry`.
- Clipboard history: ii-vynx `Cliphist`.
- Windows: ii-vynx `HyprlandData`.
- System metrics: ii-vynx resource/network services, requested only while the utility needs them.
- Session/power actions: ii-vynx `Session`.
- Shortcut viewer: ii-vynx Hyprland keybind state.
- Weather current state/GPS/config: ii-vynx `Weather`; K4 owns its richer forecast/search presentation.
- Tray: existing `TrayService` / Quickshell SystemTray objects; no competing tray owner.

## Review and live-remediation fixes

- Launcher ownership releases immediately on close so island collapse starts without a blank ownership tail.
- Standard Overview and K4 launcher routing are mutually exclusive at the family boundary.
- Existing search/Super shortcut and IPC names are reused rather than replacing user keybinds.
- Existing Super+V clipboard route targets K4 Clipboard in K4 mode.
- Fullscreen Super binding uses Hyprland shortcut-inhibition bypass semantics through `dont_inhibit`.
- Lazy Files view imports the module it uses and Ctrl+Enter consistently resolves the containing directory.
- K4 Session delegates to the existing ii session owner.
- K4 Weather uses the live ii GPS longitude key.
- Weather glyphs use the Material Design Nerd Font range carried by the shell instead of unsupported E3xx weather glyphs.
- Clock hover restores the upstream tray entrypoint using live `TrayService` items; tray-in-collapsed-pill remains off by the upstream default.
- Clipboard presentation keeps ii `Cliphist` ownership but stabilizes the list layout/delegate path after live validation showed a valid history count with blank rows.
- Source regressions were corrected where tests had become stale or matched comments instead of executable ownership behavior.

## Standards review

The target architecture remains the one defined by the spec:

- one owner for each global desktop facility;
- narrow K4 presentation adapters;
- K4-specific UI behind the island plugin boundary;
- no Material/Liquid Glass restyle during parity work;
- no unrelated distro/package-management subsystem inside the launcher;
- no broad refactor of unrelated ii services without demonstrated adapter need.

## Outside-click behavior

The live pass reported that clicking outside an opened utility does not close it. This is not being changed speculatively during K4-07. The pinned K4 utility plugins expose explicit close/Escape behavior, while the island input mask is deliberately scoped to island geometry. Any change to desktop-wide outside-click dismissal needs upstream evidence or an explicit post-parity behavior decision; it must not be implemented by adding an invisible fullscreen input catcher.

## Automated evidence

Repository source-regression tests cover the K4-07 launcher, routing, fullscreen launcher, apps, clipboard, files, windows, system, session, keys, weather and tray seams, plus the existing singleton-import guard.

The connected GitHub environment cannot execute the repository's Quickshell runtime or local Node suite, so this document does not claim a fresh automated pass. The next real-shell validation must run the source suite locally.

## Focused live revalidation gate

Before closing K4-07, validate the remediated paths on the real shell:

1. Standard mode: existing Super/search opens only Standard Overview.
2. K4 mode: the same Super/search opens only K4 Launcher.
3. In a true fullscreen client, Super reaches K4 Launcher without taking the client out of fullscreen.
4. Launcher searches and launches desktop applications only; no package/AUR/install mode is present.
5. Clipboard displays real history rows, filters them, and Enter copies the selected row; Delete and Ctrl+P remain usable.
6. Weather condition icons render as real glyphs rather than missing-character boxes.
7. Hover the K4 Clock: current tray icons appear there when tray applications exist; exercise at least one normal activation or menu path.
8. Existing K4 panel/media/notifications and Standard → K4 → Standard switching remain intact.

After this focused gate passes, record the runtime evidence in `STATUS.md`, close K4-07, and proceed to K4-08.
