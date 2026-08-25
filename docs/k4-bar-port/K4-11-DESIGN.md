# K4-11 — Built-in plugin lifecycle

Status: approved for implementation

## Decision

K4-11 implements lifecycle resilience for the K4 plugins shipped inside ii-vynx. It does not implement upstream k4's external-plugin ecosystem.

Approved behavior:

- built-in plugins may be loaded independently through a host-owned dynamic component seam;
- a disabled managed plugin is not instantiated;
- enabling recreates the plugin from its built-in QML entry;
- one plugin component/load failure is recorded without preventing the rest of the K4 bar from loading;
- Settings continues to show disabled and failed plugins even when no live plugin instance exists;
- failed built-ins can be retried from the same Settings lifecycle seam;
- cross-plugin references are distributed by the host after lifecycle changes rather than depending on catalog order;
- persisted enablement remains in the existing `Config.options.bar.k4.disabledPlugins` setting.

Explicitly out of scope:

- user/external plugin directories;
- plugin manifests or permission declarations;
- public plugin API compatibility;
- plugin store/registry;
- install/update/remove tooling;
- Python plugin helpers;
- filesystem watchers;
- hot-reload staging directories;
- package management or background updater services.

These exclusions follow the project's no-bloat/no-new-service rule and are intentional product decisions rather than deferred K4-11 work.

## Architecture

The migration uses persistent host-owned **plugin descriptors/slots** separated from ephemeral **live plugin instances**.

A descriptor carries stable metadata needed by Apps and Settings even when its instance is absent: id/name, title, application metadata, configurable/protected status, entry path, enabled state and load error.

The lifecycle manager owns creation/destruction/retry for managed built-ins. The arbitration controller continues to operate on live plugin instances only.

## Tracer slice

Migrate `displays` first because it is a self-contained application plugin and does not own a global service.

Acceptance for the tracer:

1. `displays` is no longer statically instantiated in `K4BuiltinPlugins.qml`.
2. When enabled, the manager creates `K4DisplaysPlugin.qml` dynamically and publishes the live instance to arbitration.
3. Disabling Displays destroys the live instance but leaves a Settings/Apps descriptor visible and disabled.
4. Re-enabling creates a fresh live instance and Displays opens normally.
5. A forced bad entry records a load error without preventing the rest of the K4 registry from loading; retry can recreate it after the entry is corrected.
6. Existing static plugins remain unchanged during this tracer.

After this slice is live-validated, migrate the remaining discrete built-ins incrementally before touching the inline ambient plugins (`volume`, `clock`, `player`, `toast`).
