# Change Logs

## v0.0.1

 - init release: slopegraph on the lite base ( no d3 ), tweens go through `chart.anim`
 - flat table: a `name` dimension and a multiple numeric `value` dimension ( one vertical column per field ),
   plus an optional `category`
 - labels sit directly at both ends of the lines; overlaps are resolved by a 1D dodge ( least-squares ), with
   leader lines to the original position, and low-priority labels are dropped when a column cannot hold them
 - config: coloring ( trend / palette / category ), trend colors and threshold, line ( width, opacity, linear / curve,
   missing value handling ), dot, label ( per-side name / value, inner columns, size, format, dodge, leader, color,
   rank ), column header, baseline, scale ( linear / rank, include zero, reverse ), hover, emphasis, legend, tip, animation
 - zh-TW i18n for the settings
