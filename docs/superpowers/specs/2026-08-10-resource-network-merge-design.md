# Resource and Network Widget Merge

## Goal

Merge live network throughput into the existing Resource Monitor so CPU, RAM,
Battery/Disk, and Network appear as one consistent desktop widget. Remove the
standalone Network widget and its graph.

## Widget design

The Resource Monitor gains a fourth `StatCard` labeled `Network`. It uses the
same dimensions, typography, shape treatment, blur behavior, and color-token
pattern as the existing resource cards.

The existing layout toggle controls all four cards:

- Horizontal mode places the four cards in one row.
- Vertical mode places the four cards in one column.

The Network card displays exactly one formatted live throughput value. Its
label always remains `Network`; changing the metric does not change the label.
The icon reflects the selected metric where suitable.

## Configuration

The Resource Monitor widget configuration gains:

- `networkMode`: `download`, `upload`, or `total`; defaults to `total`.
- `pollingInterval`: the widget's polling interval in milliseconds, with the
  existing resource interval as the migration-compatible default.

Resource Monitor settings expose both options. The metric uses a three-choice
selector. The polling control uses safe bounds consistent with current service
settings.

`total` means current download throughput plus current upload throughput. It is
not cumulative transferred data.

## Runtime data flow

While the Resource Monitor exists, it activates `NetworkUsage` using the
service's existing active-instance mechanism. The Network card reads download,
upload, or their sum according to `networkMode`, then formats the result using
the existing B/s, KB/s, and MB/s conventions.

Resource polling and network sampling use the Resource Monitor's configured
polling interval. Other consumers retain their existing polling behavior.

## Removal and migration

The standalone Network widget loader and settings entry are removed. Existing
saved Network widget configuration may remain harmlessly in user JSON for
backward compatibility, but it is no longer presented or instantiated.

No unrelated widget styling or in-progress visual-tuning files are changed.

## Verification

- Confirm the fourth card renders in horizontal and vertical layouts.
- Confirm download, upload, and total modes choose the correct live value.
- Confirm the label remains `Network` in every mode.
- Confirm polling settings persist and affect Resource Monitor sampling.
- Confirm the standalone Network widget is absent from the background loader
  and settings UI.
- Run the narrowest available QML/static checks and inspect the focused diff.
