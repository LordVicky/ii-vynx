# End4-pC Wallpaper Picker Coexistence Design

## Goal

Install the selector from `pctrade/end4-pC` beside the current ii-vynx selector for evaluation. The current selector remains the default and is not replaced.

## Isolation

- Vendor the End4-pC selector into `modules/ii/end4WallpaperSelector`.
- Keep `modules/ii/wallpaperSelector` and `services/Wallpapers.qml` byte-for-byte unchanged.
- Use independent state, namespace, IPC, configuration, and shortcut names prefixed with `end4WallpaperSelector`.
- Load both selectors from the ii panel family.
- Keep `Ctrl+Super+T` assigned to the current selector; the live Hyprland customization assigns `Ctrl+Super+Shift+T` to End4-pC.

## Features

The parallel picker retains End4-pC's Local, Wallhaven, Unsplash, and Pexels sources. Downloads are saved under `~/Pictures/Wallpapers` and applied through ii-vynx's existing `Wallpapers` service.

Wallhaven works without a key. Unsplash and Pexels use keys stored by the existing keyring service through `/unsplash KEY`, `/wallhaven KEY`, and `/pexels KEY` launcher actions.

Wallpaper preview, lock-wall targeting, and Settings entry points are intentionally not connected during coexistence testing.

## Safety

- Preserve current video, favourites, browser-extension, color-filter, and utility behavior by not editing the current picker or wallpaper service.
- Replace End4-pC's shell-interpolated downloader with an argument-safe, atomic helper.
- Preserve upstream attribution and its MIT license.
- Test independent naming and recheck hashes for the current picker and wallpaper service.
