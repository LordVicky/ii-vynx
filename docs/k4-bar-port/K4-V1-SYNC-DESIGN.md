# K4 v1.0 Selected Upstream Sync — Design

Status: implemented

## Source anchors

- Existing port source pin: `k4ditano/k4@48993812c88f0af5d0c5345cd273467043b889f1` (2026-08-22).
- Reviewed release: `k4ditano/k4@adcf4216038f7881c4a589baafaaaec841377ad5` (`v1.0.0`, 2026-08-24).
- This document is a **selected sync**, not a new full-parity target. Later upstream `main` commits are not implicitly in scope.

## Product decisions

Approved:

- **U1** bar space/overlay modes.
- **U2** per-monitor fullscreen detection.
- **U3** hidden-edge reveal interaction.
- **U4** Player track-change peek.
- **U6** compact asymmetric Idle/Clock sizing.
- **U17** active-island-monitor plugin API.
- **U19** capture-only review if applicable to the ii-vynx adapter.

Reviewed then withdrawn:

- **U12** lifecycle/extensibility ideas. The managed Loader/proxy experiment was reverted and is not part of the selected port. Upstream manual QObject lifetime remains rejected.

Rejected:

- **U5** Dual mode/dock.
- **U7-U9** HyprTheme wallpaper/video/palette stack.
- **U10-U11** plugin store/public ecosystem.
- **U13** standalone K4 self-update status.
- **U14** K4 coding-agent skill installer.
- **U15** live window thumbnails.
- **U16** generalized auxiliary-window API expansion.
- **U18** upstream translation-system changes.
- **U20** upstream installer/docs polish as runtime scope.

These are explicit product decisions. Rejected/withdrawn items are not deferred parity debt.

## Space management (U1, U2, U3)

`Config.options.bar.k4.spaceMode` supports:

```qml
property string spaceMode: "reserve"
// "reserve" | "fullscreen" | "overlay" | "hidden"
```

Behavior:

- `reserve` keeps the collapsed K4 exclusive zone;
- `overlay` keeps the island visible with zero exclusive zone;
- `hidden` uses zero exclusive zone and withdraws idle presentation past the selected edge;
- `fullscreen` resolves to Hidden only on a monitor whose active workspace has fullscreen content.

Fullscreen state is queried through existing `HyprlandData` snapshots. K4 does not add a second workspace/monitor service or polling loop.

Hidden belongs to the host:

- idle withdrawal delay around 1600 ms;
- non-overshooting return/withdraw animation around 360 ms;
- top withdraws upward and bottom withdraws downward;
- an island-width 4 px reveal target, never a full monitor-edge catcher;
- returning/visible input remains host-owned;
- capture/system-dialog suppression removes island and reveal-target input;
- a non-idle plugin activation returns the island immediately;
- edge brush returns the collapsed pill first, with normal hover expansion after dwell.

## Player track-change peek (U4)

`playerPeekOnTrackChange` controls a short Player activation for real track changes.

Requirements:

- reuse `K4Media`; no second MPRIS owner;
- settle title + artist metadata before comparison;
- initial discovery, empty identity and unchanged identity do not peek;
- real track transitions activate Player briefly;
- explicit close/Escape ends the peek;
- ambient activation uses the existing focused-screen fallback;
- Hidden returns automatically for the active Player plugin.

## Asymmetric Idle/Clock sizing (U6)

Idle uses sequential measured zones:

```text
left media | center clock/workspaces | right indicators
```

Clock hover uses:

```text
date | gap | time | gap | contextual right
```

Each side consumes its own measured width rather than mirroring the wider side. Conservative first-frame estimates are acceptable; measured layout becomes authoritative after layout.

## Active-monitor contract (U17)

`IslandState.activeScreen` is the stable active-island monitor value.

- explicit actions may populate `requestedScreen`;
- controller selection consumes that request or falls back to focused screen;
- the expanded host publishes `activeScreen`;
- plugins use host state rather than adding monitor queries.

## Capture review (U19)

Upstream v1 capture changes were reviewed only against the existing thin K4 Capture adapter. The upstream editor/transcription/Python capture stack remains excluded because ii-vynx K4 Capture delegates to existing shell capture/record owners.

## Acceptance

The selected v1.0 sync is complete when:

- all four space modes behave correctly at top and bottom;
- fullscreen resolution is per monitor and reuses `HyprlandData`;
- Hidden uses an island-width reveal strip rather than a whole-edge catcher;
- Player initial discovery does not peek and a real track change produces at most one peek;
- Idle/Clock avoid mirrored empty reservation;
- `IslandState.activeScreen` remains the plugin-facing active-monitor contract;
- no rejected/withdrawn v1 feature is introduced through infrastructure;
- source checks and real-shell validation are accepted.
