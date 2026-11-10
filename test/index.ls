# slopegraph 的 test case ( 用 @makechart/viewer 的 mctest 跑 ). 資料都由固定種子產生.

rnd = mctest.random 11

# rows: [[name, v0, v1, ...]]; cols: 欄名
table = (rows, cols, extra = {}) ->
  raw: rows.map (r) ->
    o = {name: r.0}
    cols.map (c, i) -> o[c] = r[i + 1]
    o
  binding: {name: {key: \name}, value: cols.map(-> {key: it})} <<< extra

two = -> table [
  ["Housing", 24.1, 29.4], ["Food", 17.3, 15.8], ["Transport", 12.6, 13.1], ["Utilities", 7.4, 8.9]
  ["Healthcare", 7.1, 9.8], ["Dining Out", 6.2, 5.1], ["Recreation", 5.9, 5.3], ["Clothing", 4.8, 3.2]
  ["Education", 4.2, 4.2], ["Travel", 3.6, 4.6]
], <[2015 2025]>

multi = -> table [
  ["Northern Region", 42, 48, 51, 49, 55], ["Southern Region", 31, 29, 33, 38, 41], ["Eastern Region", 25, 34, 30, 27, 22]
  ["Western Region", 18, 16, 20, 26, 30], ["Central Region", 12, 15, 14, 13, 9], ["Islands", 6, 8, 12, 11, 16]
], <[Q1 Q2 Q3 Q4 Q5]>

dense = (n = 30) ->
  rows = [0 til n].map (i) ->
    a = 50 + rnd! * 6
    ["Item #i", +a.toFixed(1), +(a + (rnd! - 0.5) * 8).toFixed(1)]
  table rows, <[before after]>

category = ->
  d = two!
  d.raw.map (r, i) -> r.group = if i < 5 => \Essentials else \Lifestyle
  d.binding.category = {key: \group}
  d

data =
  two: two!
  multi: multi!
  category: category!
  dense: dense 30
  many: dense 120
  # 負值
  negative: table [["Alpha", -12, 8], ["Beta", 5, -3], ["Gamma", -7, -2], ["Delta", 0, 6], ["Epsilon", 3, 3]], <[A B]>
  # 缺值: 兩端 / 中間 / 只有一個值
  missing: table [
    ["Complete", 10, 14, 18, 16], ["No first", '', 12, 11, 15], ["No last", 8, 9, 13, '']
    ["Hole", 5, '', 8, 12], ["Only middle", '', 7, '', ''], ["Blank", '', '', '', '']
  ], <[W X Y Z]>
  # 兩值相等 / 全部相同
  equal: table [["A", 5, 5], ["B", 5, 5], ["C", 5, 5]], <[then now]>
  # 只有 1 欄
  single: table [["A", 10], ["B", 30], ["C", 20]], <[only]>
  # 名次有並列
  tied: table [["A", 10, 20, 20], ["B", 10, 15, 30], ["C", 8, 15, 10], ["D", 5, 25, 25]], <[R1 R2 R3]>
  # 長名稱
  long: table [
    ["An extremely long item name that cannot fit anywhere", 120000, 230000]
    ["Another rather long name for an item", 95000, 80000], ["Short", 40000, 41000]
  ], ["A column with a long title", "Another long column title"]
  empty: {raw: [], binding: {name: {key: \name}, value: [{key: \a}, {key: \b}]}}

cases = []
for k in <[two multi category dense many negative missing equal single tied long empty]> =>
  cases.push {name: "data:#k", data: k}

cases ++= [
  * name: "size:small", data: \two, size: [300 300]
  * name: "size:small-multi", data: \multi, size: [300 300]
  * name: "size:tiny", data: \two, size: [160 140]
  * name: "size:small-dense", data: \dense, size: [300 300]
  * name: "scale:rank", data: \multi, config: {scale: {mode: \rank}}
  * name: "scale:rank-tied", data: \tied, config: {scale: {mode: \rank}, label: {rank: true}}
  * name: "scale:rank-reverse", data: \two, config: {scale: {mode: \rank, reverse: true}}
  * name: "scale:zero", data: \two, config: {scale: {include-zero: true}}
  * name: "color:palette", data: \multi, config: {coloring: {mode: \palette}}
  * name: "color:category", data: \category, config: {coloring: {mode: \category}}
  * name: "color:custom", data: \two, config: {trend: {increase: '#06c', decrease: '#c06', flat: '#999', threshold: 1}}
  * name: "line:curve", data: \multi, config: {line: {mode: \curve, stroke-width: 3, opacity: 0.6}}
  * name: "line:connect", data: \missing, config: {line: {missing: \connect}}
  * name: "dot:off", data: \two, config: {dot: {show: false}}
  * name: "dot:large", data: \two, config: {dot: {size: 7}}
  * name: "label:no-dodge", data: \dense, config: {label: {dodge: false}}
  * name: "label:no-leader", data: \two, config: {label: {leader: false}}
  * name: "label:name-only", data: \two, config: {label: {left: {show-value: false}, right: {show-value: false}}}
  * name: "label:right-only", data: \two, config: {label: {left: {show-name: false, show-value: false}}}
  * name: "label:no-middle", data: \multi, config: {label: {middle: false}}
  * name: "label:large", data: \two, config: {label: {size: 1.2}}
  * name: "label:format", data: \two, config: {label: {format: \.0f, color: \line}}
  * name: "header:off", data: \two, config: {header: {show: false}}
  * name: "baseline:off", data: \two, config: {baseline: {show: false}}
  * name: "legend:right", data: \two, config: {legend: {position: \right}}
  * name: "legend:selectable", data: \two, config: {legend: {selectable: true}}
  * name: "legend:off", data: \two, config: {legend: {enabled: false}}
  * name: "emphasis:names", data: \two, config: {emphasis: {mode: \names, names: "Housing, Clothing"}}
  * name: "emphasis:largest", data: \multi, config: {emphasis: {mode: \largest, count: 2}}
  * name: "emphasis:decrease", data: \two, config: {emphasis: {mode: \decrease}}

  # 圖表自己的 sample ( 含 unit 與 category binding )
  * name: "data:sample", data: \two
    steps: [(c) -> d = c.mod.sample!; c.set-raw d.raw, d.binding]

  # hover: 只留一個項目, tip 顯示各欄的值與變化量
  * name: "hover:item", data: \two
    steps: [(c, ctx) ->
      n = ctx.root.querySelector '.s-hit path'
      b = n.getBoundingClientRect!
      opt = {bubbles: true, clientX: b.x + b.width / 2, clientY: b.y + b.height / 2}
      n.dispatchEvent new MouseEvent(\mouseover, opt)
      n.dispatchEvent new MouseEvent(\mousemove, opt)
    ]

  # 換資料: 項目增減, 舊的淡出、新的長出來
  * name: "update:items", data: \two
    steps: [(c) ->
      d = two!
      d.raw.splice 3, 3
      d.raw.push {name: "New item", "2015": 20, "2025": 11}
      c.set-raw d.raw, d.binding
    ]
  * name: "update:columns", data: \two
    steps: [(c) -> d = multi!; c.set-raw d.raw, d.binding]
  * name: "update:config", data: \two
    steps: [(c) ->
      c.config {scale: {mode: \rank}, line: {mode: \curve}}
      c.parse!; c.bind!; c.resize!; c.render!
    ]
  # legend 關掉上升的項目 ( shrink, 重新算 domain )
  * name: "update:legend", data: \two, config: {legend: {selectable: true}}
    steps: [(c) ->
      c.legend.select <[decrease flat]>
      c.bind!; c.resize!; c.render!
    ]
  # 逐格: 補間中間的樣子 ( step 同步寫 DOM, capture 不 flush )
  * name: "anim:frames", data: \two
    steps: [(c, ctx) ->
      d = multi!
      c.set-raw d.raw, d.binding
      c.anim.step 100
      ctx.capture \t100
      c.anim.step 100
      ctx.capture \t200
    ]
  # 關掉動畫: 不留補間
  * name: "anim:off", data: \two, config: {animation: {enabled: false}}
    steps: [(c) -> d = dense 10; c.set-raw d.raw, d.binding]
]

mctest.suite {data, cases, size: [560 380]}
