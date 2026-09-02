# End4-pC Wallpaper Picker Coexistence Implementation Plan

**Goal:** Add an isolated End4-pC wallpaper picker beside the current ii-vynx picker.

**Architecture:** Vendor the five upstream selector components into a new QML module, reuse ii-vynx common widgets and wallpaper application service without modifying the current picker, and add a dedicated online-provider singleton. Deploy the authoritative source tree to the live configuration after tests pass.

**Source revision:** `pctrade/end4-pC` main at `11cd535d3b6797972e5d82e7b39c7976b8fdff50`.

## Tasks

1. Add a failing static integration test covering preservation hashes, independent naming, loading, providers, configuration, and safe downloads.
2. Vendor and isolate the End4-pC selector; adapt only incompatible ii-vynx APIs and remove replacement-background/lock-screen coupling.
3. Add online-provider service, provider-key actions, separate defaults, attribution, and atomic download helper.
4. Load the parallel selector and deploy the tested source files to the live shell.
5. Add the live-only Hyprland shortcut and layer rule, reload both processes, and verify both selectors independently without applying a wallpaper.
