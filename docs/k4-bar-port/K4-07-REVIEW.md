# K4-07 — Launcher and Everyday Utilities Review

Branch: `agent/k4-bar-port`

Ticket: `K4-07 — Launcher and everyday utility plugins`

Implementation base: `865b0bc0b3e72fe83dc8fce4bcab4ea760548c66` (K4-06 close)

Final code review point: `bae6ffdd52e663091cef642d0973225d45c462b7`

Pinned k4 source: `48993812c88f0af5d0c5345cd273467043b889f1`

Authoritative plan: `docs/k4-bar-port/SPEC.md` + `docs/k4-bar-port/TICKETS.md`

## State

**Validated and closed on 2026-08-24.**

The initial integrated live pass exposed blocking defects in fullscreen launcher presentation, clipboard presentation, weather glyph rendering, and tray discoverability. Those defects were remediated and the focused K4-07 live matrix is now fully passing. The final local source gate also passes 102/102 tests.

## Approved K4-07 scope

The ticket covers:

- launcher/apps;
- clipboard;
- files;
- windows;
- system monitor;
- session/power;
- shortcut viewer;
- weather/tray where not already completed;
- preservation of the existing Super launcher binding, including the fullscreen shortcut-inhibition path.

Each sub-slice reuses existing ii-vynx service ownership where practical and avoids broad unrelated service APIs.

### Scope correction

An Arch-specific pacman/yay package-search/install mode was temporarily carried into the launcher while following upstream launcher internals. That behavior is **not part of the approved K4-07 ticket or implementation sequence** and was removed.

K4 Launcher stays inside the Quickshell shell boundary: ii-vynx `AppSearch`/`DesktopEntry` owns application discovery and execution, while K4 owns the Spotlight-style launcher presentation and interaction. Package management is not a core bar responsibility.

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
- The K4 island temporarily lifts the Launcher owner from `WlrLayer.Top` to `WlrLayer.Overlay`, matching the already validated notification fullscreen seam, so a true fullscreen client cannot hide launcher presentation.
- The fullscreen application remains fullscreen while K4 Launcher opens above it.
- Lazy Files view imports the module it uses and Ctrl+Enter consistently resolves the containing directory.
- K4 Session delegates to the existing ii session owner.
- K4 Weather uses the live ii GPS longitude key.
- Weather glyphs use the Material Design Nerd Font range carried by the shell instead of unsupported E3xx weather glyphs.
- Clock hover restores the upstream tray entrypoint using live `TrayService` items; tray-in-collapsed-pill remains off by the upstream default.
- Clipboard presentation keeps ii `Cliphist` ownership but stabilizes the list layout/delegate path after live validation showed a valid history count with blank rows.
- Source regressions were corrected where tests had become stale or matched comments instead of executable ownership behavior.

## Automated evidence

Final local source gate on 2026-08-24:

- tests: 102
- pass: 102
- fail: 0
- cancelled: 0
- skipped: 0
- todo: 0

Coverage includes the K4-07 launcher, routing, fullscreen launcher, apps, clipboard, files, windows, system, session, keys, weather and tray seams, plus the existing K4 regression suite and singleton-import guard.

The Quickshell configuration also loaded successfully after deployment. The startup log still contains unrelated/pre-existing warnings from desktop widgets, portal startup, translation data, extension signal handlers and desktop-entry parsing, but no K4-07 QML load failure is present.

## Live validation — 2026-08-24

The focused K4-07 matrix is fully passing after remediation. The previously failing case now passes:

- in a true fullscreen client, Super opens K4 Launcher above the client;
- the focused application stays in fullscreen rather than being resized or forced out of fullscreen.

The other K4-07 live checks had already passed before this final retest and remained the accepted gate for launcher routing/application-only search, clipboard, weather/tray, and existing K4/Standard regression behavior.

## Outside-click behavior

Clicking outside an opened utility does not close it. This remains intentionally unchanged during parity work. The pinned K4 utility plugins expose explicit close/Escape behavior, while the island input mask is deliberately scoped to island geometry. Any desktop-wide outside-click dismissal needs upstream evidence or an explicit post-parity design decision; it must not be implemented by adding an invisible fullscreen input catcher.

## Standards review

No blocking findings at final code review point `bae6ffdd52e663091cef642d0973225d45c462b7`.

- Global facilities retain one owner; K4 uses narrow presentation adapters rather than competing service/process owners.
- K4-specific behavior remains behind the island plugin/controller boundary.
- Files and system-resource work stays demand-driven rather than adding persistent background ownership.
- Fullscreen launcher visibility is expressed through the existing layer-shell seam instead of compositor window hacks.
- Standard Overview and K4 Launcher remain mutually exclusive at the family boundary.
- User custom keybinds retain final ownership because the launcher rewrite runs before `custom.keybinds`.
- No Material/Liquid Glass restyle was introduced during parity work.
- Package-management behavior remains outside the launcher scope.
- The final fullscreen remediation is narrowly scoped to launcher z-order plus a regression test; unrelated edits found during review were reverted before closure.

## Spec review

K4-07 satisfies the approved ticket/spec boundary:

- launcher/apps are present with existing Super/search routing preserved;
- focused-client shortcut inhibition no longer blocks the selected launcher path;
- launcher presentation remains visible over true fullscreen content;
- clipboard, files, windows, system monitor, session/power, shortcut viewer, weather and tray are present as daily-driver utilities;
- existing ii-vynx owners are reused where global state already exists;
- the island remains K4-styled and does not absorb unrelated Standard/Liquid Glass behavior;
- available source checks pass and compositor-specific behavior has real-shell validation evidence.

The deferred K4-04 reverse workspace-pill animation issue remains explicitly non-blocking and is not part of K4-07.

## Closure

K4-07 is closed. Proceed to `K4-08 — k4 settings inside the island`.
