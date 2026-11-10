# @makechart/slopegraph

Slopegraph for makechart: a few vertical columns ( before / after, or more periods ), each item has a value
in every column and adjacent columns are joined by a line, to compare changes and ranks.


## Data

A flat table, one row per item:

 - `name` ( name ): the item. Rows with the same name stay separate lines.
 - `value` ( numeric, multiple ): one vertical column per bound field; the column title is the binding's `name` or `key`,
   and the binding's `unit` is appended to the values.
 - `category` ( category, optional ): used for tooltips and for `coloring.mode = category`.

Blank or non-numeric cells are treated as missing. `line.missing` decides whether the line breaks ( `gap` ) or
joins the neighbors ( `connect` ).


## Behavior

 - Item names and values are placed at both ends of the lines. When `label.dodge` is on, labels in a column are
   separated with a 1D dodge and tied to their point by leader lines ( `label.leader` ).
 - If a column cannot hold every label, labels of the emphasized items and the largest changes are kept; the
   rest are still reachable through the tooltip.
 - Trend is the change from the first to the last available value of an item, `trend.threshold` is the largest change that counts as flat.
 - `scale.mode = rank` plots competition ranks ( ties share a rank ), rank 1 on top. `scale.reverse` means lower values are better.
 - The legend collapses in very small charts.


## Development

    npm run build             # src -> dist
    npm test                  # run test/index.ls with @makechart/viewer and compare with test/snapshot
    npm run test:serve        # browse cases; /playground for trying settings and data

Use `test:dev` and `test:dev:serve` to link a local `../base` and `@plotdb/chart`.
