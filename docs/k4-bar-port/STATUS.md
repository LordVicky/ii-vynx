# k4 Dynamic Island Port — Status

Working branch: `agent/k4-bar-port`
Source spec: `docs/k4-bar-port/SPEC.md`
Tickets: `docs/k4-bar-port/TICKETS.md`

## Current phase

`K4-01 — Variant ownership seam`: implementation complete, source review complete, real-shell validation pending.

Do not start dependent ticket K4-02 until the K4-01 compositor/settings smoke test passes or any discovered issue is fixed and re-reviewed.

## K4-01 implemented

- `Config.options.bar.variant` defaults to `standard`.
- `Config.options.bar.k4.position` and `.alignment` are independent of Standard bar placement.
- `IllogicalImpulseFamily.qml` explicitly gates Standard and k4 bar ownership.
- Standard horizontal, vertical, and Liquid Glass helper bar surfaces are Standard-only.
- `modules/ii/k4bar/K4Bar.qml` supplies the inert k4 host for the first tracer bullet.
- k4 host uses every Quickshell screen, top/bottom placement, 15/50/85 alignment, a 34px exclusive zone, and its own layer-shell namespace.
- k4 host yields surface ownership while ii-vynx is locked.
- Bar Settings exposes the variant selector and k4 host settings; Standard-only sections are hidden in k4 mode.
- `tests/k4-bar-variant.test.js` locks the source-level ownership contract.

## Source review

### Standards

- No changes were made inside `modules/ii/bar/Bar.qml`, `BarContent.qml`, or the vertical bar implementation.
- Variant branching is concentrated at the panel-family loader seam.
- k4-specific host code lives under `modules/ii/k4bar/`.
- Configuration uses the existing central Config schema.
- No duplicated system service or functional k4 plugin has been introduced in K4-01.

### Spec

K4-01 matches the approved spec/ticket for:

- Standard default and coexistence;
- explicit mutually exclusive ownership;
- independent k4 position/alignment;
- top/bottom-only k4 placement;
- upstream all-screen coverage;
- 34px collapsed reservation;
- Standard-only settings hidden in k4 mode.

The inert capsule is intentionally not the final k4 silhouette. Inverse wings, idle content, animation, and pixel-fidelity belong to K4-02.

## Automated checks

- Added: `node --test tests/k4-bar-variant.test.js` source-contract test.
- Not executed by the implementation environment: there is no writable/runnable checkout connected to the GitHub write API and no branch CI run was produced.
- Quickshell/QML runtime checks therefore require the real shell environment.

## Required K4-01 manual validation

1. Pull/sync `agent/k4-bar-port` into the live ii configuration and restart Quickshell.
2. Confirm the shell starts with **Standard** selected and the existing bar looks/behaves unchanged.
3. Open Bar Settings. Confirm **Bar variant** offers Standard and **k4 Dynamic Island**.
4. Select k4. Confirm the Standard bar disappears and one black inert 176x34 capsule appears on every monitor.
5. Confirm Standard-only Bar Settings sections disappear and only k4 Position/Alignment controls remain below the variant selector.
6. Change k4 Position Top ↔ Bottom and verify the capsule changes edge.
7. Change Alignment Left / Center / Right and verify placement changes along the edge.
8. Lock/unlock ii-vynx and verify the k4 host does not cover/intercept the lock surface and returns after unlock.
9. Switch back to Standard. Confirm the previous Standard bar position/layout/settings are preserved.
10. Switch to k4 again. Confirm the previous k4 position/alignment are preserved.
11. On multi-monitor, confirm an inert capsule exists on each monitor.
12. Run `node --test tests/k4-bar-variant.test.js` from the repository root and record the result.

## Next action after validation

Start `K4-02 — Faithful island shell and idle pill`: add k4 attribution/license, inverse wings, edge-reflection geometry, growth/shrink surface behavior, mask fidelity, and the faithful idle pill.
