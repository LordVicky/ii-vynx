# Anime/Booru Lifecycle Notes

Date: 2026-08-16

## Scope

This note records the final state of issue #13 after extracting Anime/Booru from core and making the Booru backend destroyable with the extension.

Relevant Vynx commit:

- `c3dc4b2a3cacdaf5348971d1803f7822337d16d2` — `refactor(booru): make backend destroyable with extension`

## Lifecycle result

The validated same-process lifecycle for `BooruRuntime` was:

| State | Constructed | Destroyed |
|---|---:|---:|
| fresh installed-disabled | 0 | 0 |
| first enable | 1 | 0 |
| first disable | 1 | 1 |
| second enable | 2 | 1 |
| second disable | 2 | 2 |

Conclusion: the lightweight `Booru` compatibility facade may remain instantiated after first use, but the heavy provider/request runtime is zero-cost while disabled and is recreated fresh on every enable.

Do not rerun the full lifecycle validation unless Booru ownership/lifecycle code changes again.

## Provider availability caveat

Provider reachability is region/network dependent. In the environment used for validation:

- `yande.re` failed a direct anonymous API probe because the service is blocked/unreachable in the region.
- Konachan returned a valid anonymous API response from the same machine.
- A real Konachan search through the Anime extension and Vynx `BooruRuntime` succeeded.

Therefore, do not diagnose a Vynx request regression or missing API key from a yande.re failure alone. For a basic anonymous functional smoke test, use Konachan first.

## External extension compatibility caveat

As of this validation, upstream `ii-eve-anime-booru/src/Anime.qml` calls:

```qml
StringUtils.shellSingleQuoteEscape(...)
```

but does not import the module that exports `StringUtils` in Vynx. The required import is:

```qml
import qs.modules.common.functions
```

A local installed-extension patch was used to validate this fix. It is not part of the Vynx core commit and may be overwritten by an extension update until the upstream extension incorporates the import.

Do not add a Vynx core compatibility shim for this; the missing import belongs in the extension.

## Final status

- Anime extension page loads and unloads correctly.
- `BooruRuntime` is absent while the extension is disabled.
- Disabling after use destroys the runtime.
- Re-enabling creates a fresh runtime.
- Konachan anonymous search works through the new runtime.
- Issue #13 was closed as completed.
