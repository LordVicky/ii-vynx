# K4-11 — Built-in plugin lifecycle

Status: **withdrawn and reverted**

## Decision

The managed built-in lifecycle experiment is no longer part of the K4 port.

The port now keeps built-ins as ordinary declaratively owned QML objects in `K4BuiltinPlugins.qml`:

```text
K4BuiltinPlugins -> K4FooPlugin {}
```

The following experimental/product surface has been removed:

- `K4ManagedPlugin` stable proxies;
- Loader-owned enable/disable instantiation;
- persisted per-plugin disablement;
- plugin lifecycle status/Error/Retry UI;
- lifecycle fault-injection/debug IPC;
- lifecycle probe infrastructure and lifecycle-specific tests.

The actual K4 utility implementations and unrelated fixes remain in place.

## Why it was withdrawn

The declarative Loader prototype was technically viable, but the feature was not required for the requested K4 port and provided little user-facing benefit for thin adapters that already delegate desktop ownership to ii-vynx services. Extending it across the remaining higher-coupling plugins would add custom lifetime machinery and maintenance cost without improving K4 parity.

The earlier manual dynamic-object experiment remains useful negative evidence: `Qt.createComponent()`, `Component.createObject()` and manual `.destroy()` produced native Qt/QML lifetime failures on the target runtime. Reverting the managed lifecycle does **not** revive that approach. Built-ins remain statically/declaratively owned.

## Current invariants

- `K4PluginController` arbitrates directly owned built-ins.
- `K4Plugin.enabled` remains the normal arbitration field; there is no persisted user-facing per-plugin disabling feature.
- no K4 plugin lifetime path uses manual `Qt.createComponent()`, `createObject()` or `.destroy()`.
- external/user plugin directories, plugin store/registry, manifests/permissions and plugin package/update tooling remain out of scope.
- one-owner desktop-service boundaries remain unchanged.

## Historical evidence

The Loader/proxy validation and the earlier manual-lifetime crash investigation are retained in repository history only. They are not current architecture or acceptance criteria.
