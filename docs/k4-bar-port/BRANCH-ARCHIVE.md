# K4 Hover Branch Archive

This file records the branch refs retired after the 2026-09-02 K4 hover-branch audit. The commit SHAs below are the historical checkpoints to use if any retired experiment needs to be inspected after its remote branch ref is removed.

## Retired branch refs

| Branch | Archived tip | Reason |
| --- | --- | --- |
| `agent/k4-scroll-hover-staging` | `11a11084ab4cb432e3bc20a2f7ecd56bff6ada5e` | Validated Wi-Fi/Bluetooth viewport-hover baseline; accepted behavior is superseded by `agent/k4-bar-port`. |
| `agent/k4-scroll-hover-staging2` | `11a11084ab4cb432e3bc20a2f7ecd56bff6ada5e` | Exact duplicate of `agent/k4-scroll-hover-staging`; no unique history. |
| `agent/k4-apps-hover-tracer-20260829` | `c05794a796ebb2e16162dd47a4f9190ef1cf6064` | Incomplete/disproven Apps GridView tracer; later runtime evidence identified Launcher rather than Apps as the relevant lagging surface. |

These three branch refs are safe to delete after this record is present. Do not merge them into the current K4 implementation.

## Reference branches intentionally retained

| Branch | Tip at audit | Why it remains useful |
| --- | --- | --- |
| `agent/k4-scroll-hover-work` | `8df7b2a797f4502a99d6bc521c14deec4424debe` | Broad `K4ViewportPointer` experiment covering many scroll surfaces; useful as diagnostic/reference material even though it is not the selected production architecture. |
| `agent/k4-final-audit-harness-cleanup` | `90551f51d12c282893446a1ac7b9101de8199c49` | Historical source of the accepted stabilization conclusions, including Launcher viewport hover, K4 layer `no_anim`, and removal of temporary tracers/harnesses. |

## Authoritative implementation

`agent/k4-bar-port` is the authoritative consolidated K4 implementation. Accepted stationary-pointer behavior for Wi-Fi, Bluetooth and Launcher, along with the bottom-layer animation fix, is already present there. Historical branches should not be treated as alternative production lines.
