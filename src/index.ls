svgns = "http://www.w3.org/2000/svg"

# ---------------------------------------------------------------- i18n
# 設定的顯示名稱: [ en, zh-TW ]. 一律以設定的 key 當索引 ( 同名的 key 在各群組意思相同 )
labels =
  # 群組
  coloring: <[coloring 著色]>
  trend: ["trend", "增減"]
  line: <[line 線條]>
  dot: <[dot 資料點]>
  label: <[label 標籤]>
  left: ["left", "左側"]
  right: ["right", "右側"]
  header: ["column header", "欄標題"]
  baseline: <[baseline 基準線]>
  scale: ["scale", "比例"]
  hover: ["hover", "滑過"]
  emphasis: ["emphasis", "強調"]
  animation: ["animation", "動畫"]
  # 欄位
  mode: <[mode 模式]>
  increase: ["increase", "上升"]
  decrease: ["decrease", "下降"]
  flat: ["no change", "持平"]
  threshold: ["flat threshold", "持平門檻"]
  strokeWidth: ["stroke width", "粗細"]
  opacity: <[opacity 透明度]>
  missing: ["missing value", "缺值處理"]
  show: <[show 顯示]>
  size: ["size", "大小"]
  showName: ["show name", "顯示名稱"]
  showValue: ["show value", "顯示數值"]
  middle: ["values on inner columns", "中間欄顯示數值"]
  format: ["format", "格式"]
  dodge: ["avoid overlap", "標籤避讓"]
  leader: ["leader lines", "引線"]
  padding: ["padding", "間距"]
  rank: ["show rank instead of value", "名次取代數值"]
  color: <[color 顏色]>
  width: <[width 寬度]>
  includeZero: ["include zero", "包含 0"]
  reverse: ["reverse", "反向"]
  enabled: ["enabled", "啟用"]
  dim: ["dim others to", "其他項目淡化至"]
  names: ["names ( comma separated )", "項目名稱 ( 逗號分隔 )"]
  count: ["count", "數量"]
  duration: ["duration ( ms )", "時長 ( 毫秒 )"]
# 選項值
values =
  palette: ["palette", "調色盤"]
  category: <[category 分類]>
  linear: ["linear", "線性"]
  curve: <[curve 曲線]>
  gap: ["gap", "斷開"]
  connect: ["connect", "連接"]
  text: ["text color", "文字色"]
  largest: ["largest change", "變化最大"]
  none: ["none", "無"]

i18n-zh = do ->
  ret = {}
  for k, v of labels => ret[k] = v.1; ret[v.0] = v.1
  for k, v of values => ret[k] = v.1; ret[v.0] = v.1
  ret
function i18n-all
  {} <<< i18n-zh <<< {
    # 資料維度
    "name": "名稱", "value": "數值", "category": "分類"
    # 圖上的文字
    "increase": "上升", "decrease": "下降", "no change": "持平"
  }

# 替自訂的設定欄位補上顯示名稱與翻譯 ( 同 line 的 dot.fill 寫法 )
localize = (o) ->
  for k, v of o
    if !v or typeof(v) != \object => continue
    if !v.type =>
      localize v
      continue
    if labels[k] => v.name = labels[k].0
    zh = {}
    if labels[k] => zh[labels[k].0] = labels[k].1
    (v.values or []).map -> if zh-v = i18n-zh[it] => zh[it] = zh-v
    v.i18n = {"zh-TW": zh}
  o

module.exports =
  pkg:
    name: 'slopegraph', version: '0.0.1'
    # lite: 不帶 d3 的 base. 補間走 chart.anim, 可以逐格錄影
    extend: {name: "@makechart/base", path: "lite/index.html"}
    dependencies: []
    i18n:
      "zh-TW": i18n-all!
  init: ({root, context, t, pubsub}) ->
    pubsub.fire \init, mod: mod({context, t})

# ---------------------------------------------------------------- 工具
# 1D 避讓: 把排好序的 list 依 y 分開, 相鄰至少差 gap, 位移的平方和最小.
# 轉成 t = y - i * gap 之後就是保序迴歸 ( pool adjacent violators ), 上下界直接夾 t 就好.
dodge = (list, gap, lo, hi) ->
  n = list.length
  if !n => return
  if n > 1 and (n - 1) * gap > hi - lo => gap = (hi - lo) / (n - 1)
  blocks = []
  list.map (d, i) ->
    blocks.push {sum: d.ty - i * gap, n: 1}
    while blocks.length > 1 and
    blocks[* - 2].sum / blocks[* - 2].n > blocks[* - 1].sum / blocks[* - 1].n
      b = blocks.pop!
      blocks[* - 1].sum += b.sum
      blocks[* - 1].n += b.n
  [i, top] = [0, hi - (n - 1) * gap]
  for b in blocks
    m = (b.sum / b.n) >? lo <? (top >? lo)
    for k from 0 til b.n
      list[i].y = m + i * gap
      i++

# 超過 maxw 就截斷加上省略號
trunc = (s, maxw, measure) ->
  if measure(s) <= maxw => return s
  c = Array.from s
  [lo, hi] = [0, c.length]
  while lo < hi
    m = Math.ceil((lo + hi) / 2)
    if measure(c.slice(0, m).join('') + '…') <= maxw => lo = m else hi = m - 1
  if lo => c.slice(0, lo).join('') + '…' else ''

# 往上找第一個不透明的背景, 中間欄標籤的底色與點的外框要用
bg-of = (n) ->
  while n and n.nodeType == 1
    c = getComputedStyle(n).backgroundColor
    if c and c != \transparent and !/,\s*0\)$/.exec(c) => return c
    n = n.parentNode
  '#fff'

num = (v) -> typeof(v) == \number and isFinite(v)

# ---------------------------------------------------------------- mod
mod = ({context, t}) ->
  {chart} = context
  {format, scale: Scale, anim: {join}} = chart.utils
  sample: ->
    # household budget share ( % ) in 2015 and 2025, illustrative
    rows = [
      ["Housing", "Essentials", 24.1, 29.4], ["Food", "Essentials", 17.3, 15.8]
      ["Transport", "Essentials", 12.6, 13.1], ["Utilities", "Essentials", 7.4, 8.9]
      ["Healthcare", "Essentials", 7.1, 9.8], ["Dining Out", "Lifestyle", 6.2, 5.1]
      ["Recreation", "Lifestyle", 5.9, 5.3], ["Clothing", "Lifestyle", 4.8, 3.2]
      ["Education", "Lifestyle", 4.2, 4.2], ["Travel", "Lifestyle", 3.6, 4.6]
    ]
    raw: rows.map -> {item: it.0, group: it.1, "2015": it.2, "2025": it.3}
    binding:
      name: {key: \item}
      value: [{key: \2015, unit: \%}, {key: \2025, unit: \%}]
      category: {key: \group}
  config: do ->
    c = chart.utils.config.from {preset: \default, legend: \legend, tip: \tip}
    c.legend.position.default = \bottom
    # 兩端已經直接標名字, 預設不開「全選 / 全不選」與點選
    c.legend.selectable.default = false
    c.tip.format.default = \.3~s
    own =
      coloring:
        mode: type: \choice, values: <[trend palette category]>, default: \trend
      trend:
        increase: type: \color, default: '#0f9d76'
        decrease: type: \color, default: '#e4572e'
        flat: type: \color, default: '#7a8792'
        threshold: type: \number, default: 0, min: 0, step: 0.01
      line:
        mode: type: \choice, values: <[linear curve]>, default: \linear
        stroke-width: type: \number, default: 2, min: 0.25, max: 20, step: 0.25
        opacity: type: \number, default: 0.85, min: 0, max: 1, step: 0.05
        missing: type: \choice, values: <[gap connect]>, default: \gap
      dot:
        show: type: \boolean, default: true
        size: type: \number, default: 3.5, min: 0.5, max: 30, step: 0.5
      label:
        # 不用 name / value 當 key: konfig 把 name 當群組的顯示名稱讀
        left:
          show-name: type: \boolean, default: true
          show-value: type: \boolean, default: true
        right:
          show-name: type: \boolean, default: true
          show-value: type: \boolean, default: true
        middle: type: \boolean, default: true
        size: type: \number, default: 0.8, min: 0.3, max: 4, step: 0.05
        format: type: \format, default: \.3~s
        dodge: type: \boolean, default: true
        leader: type: \boolean, default: true
        padding: type: \number, default: 5, min: 0, max: 50, step: 1
        color: type: \choice, values: <[text line]>, default: \text
        rank: type: \boolean, default: false
      header:
        show: type: \boolean, default: true
        size: type: \number, default: 0.9, min: 0.3, max: 4, step: 0.05
        color: type: \color, default: \currentColor
      baseline:
        show: type: \boolean, default: true
        color: type: \color, default: \currentColor
        opacity: type: \number, default: 0.25, min: 0, max: 1, step: 0.05
        width: type: \number, default: 1, min: 0.25, max: 10, step: 0.25
      scale:
        mode: type: \choice, values: <[linear rank]>, default: \linear
        include-zero: type: \boolean, default: false
        reverse: type: \boolean, default: false
      hover:
        enabled: type: \boolean, default: true
        dim: type: \number, default: 0.15, min: 0, max: 1, step: 0.05
      emphasis:
        mode: type: \choice, values: <[none increase decrease largest names]>, default: \none
        names: type: \text, default: ''
        count: type: \number, default: 3, min: 1, max: 100, step: 1
        dim: type: \number, default: 0.25, min: 0, max: 1, step: 0.05
      animation:
        enabled: type: \boolean, default: true
        duration: type: \number, default: 350, min: 0, max: 5000, step: 50
    c <<< localize(own)
  dimension:
    name: {type: \N, name: "name", priority: 1}
    value: {type: \R, multiple: true, name: "value", priority: 2}
    category: {type: \C, name: "category", priority: 3}
  init: ->
    @tint = new chart.utils.tint!
    @g = view: @layout.get-group(\view), legend: @layout.get-group(\legend)
    mk = (cls) ~>
      n = document.createElementNS svgns, \g
      n.setAttribute \class, cls
      @g.view.appendChild n
    <[baseline line hit leader dot label header measure]>.map (k) ~> @g[k] = mk "s-#k"
    @g.line.setAttribute \fill, \none
    @g.hit.setAttribute \fill, \none
    @g.leader.setAttribute \fill, \none

    # 量字寬. 同字串同字級重複量很浪費, 用 cache ( 字型可能換, 每次 resize 清掉 )
    tn = document.createElementNS svgns, \text
    @g.measure.appendChild tn
    @g.measure.setAttribute \visibility, \hidden
    @text-cache = {}
    @text-w = (s, size, bold) ~>
      k = "#size:#{if bold => 1 else 0}:#s"
      if @text-cache[k]? => return @text-cache[k]
      tn.setAttribute \font-size, size
      tn.setAttribute \font-weight, (if bold => 600 else 400)
      tn.textContent = s
      @text-cache[k] = tn.getComputedTextLength!

    # hover: 高亮項目所有的元素, 其他淡化. 由 css 蓋過 opacity 屬性, 補間照跑
    @hl-item = null
    layers = <[line hit leader dot label]>
    set-hl = (item) ~>
      if item == @hl-item => return
      @hl-item = item
      @g.view.classList.toggle \slope-hover, !!item
      layers.map (k) ~> Array.from(@g[k].childNodes).map (n) ->
        d = n.__data__
        n.classList.toggle \hl, !!(item and d and d.item == item)
      top = if item => Array.from(@g.line.childNodes).find (n) -> n.__data__ and n.__data__.item == item
      if top => @g.line.appendChild top
    @_evthdr = {}
    @g.view.addEventListener \mouseover, @_evthdr.over = (e) ~>
      if !(@cfg.hover and @cfg.hover.enabled) => return set-hl null
      d = e.target.__data__
      set-hl(if d and d.item => d.item else null)
    @g.view.addEventListener \mouseout, @_evthdr.out = ~> set-hl null

    # 版面太小時 legend 會吃掉圖的空間, 直接收起來; 增減模式固定順序
    @legend-opt = ~>
      [cw, ch] = [@root.clientWidth, @root.clientHeight]
      right = @cfg.legend.position == \right
      small = if right => cw < 320 or ch < 120 else ch < 200 or cw < 220
      ({} <<< @cfg.legend) <<< (if small => {enabled: false} else {}) <<<
        (if @color-mode == \trend => {sort: {mode: \none}} else {})

    @legend-color = (key) ~>
      if key in <[increase decrease flat]> and @color-mode == \trend => return @cfg.trend[key]
      @tint.get key
    self = @
    @legend = new chart.utils.legend do
      layout: @layout, root: @root, name: \legend, direction: \horizontal
      shape: (d) -> @setAttribute \fill, self.legend-color(d.key)
    @legend.on \select, ~>
      @bind!; @resize!; @render!

    pct = (p) ->
      s = (Math.abs(p) * 100).toFixed(1).replace /\.0$/, ''
      "#{if p > 0 => '+' else if p < 0 => '−' else ''}#s%"
    @tip = new chart.utils.tip {
      root: @root
      accessor: ({evt}) ~>
        if !(evt.target and (d = evt.target.__data__) and d.item) => return null
        it = d.item
        f = format.from((@cfg.tip or {}).format or \.3~s)
        fv = (v, c) -> if num(v) => "#{f v}#{c.unit}" else '-'
        lines = @cols.map (c, i) ~>
          r = it.ranks and it.ranks[i]
          "#{c.name}: #{fv it.values[i], c}#{if r => " (\##r)" else ''}"
        c0 = @cols[it.first]
        value = if isNaN(it.change) => fv it.values[it.first], c0
        else
          sign = if it.change > 0 => '+' else if it.change < 0 => '−' else ''
          "#sign#{f Math.abs(it.change)}#{c0.unit}" + (if isNaN(it.pct) => '' else " (#{pct it.pct})")
        {group: it.cat or '', name: it.name, value, value-alt: lines.join("\n")}
      range: ~> @layout.get-node \view .getBoundingClientRect!
    }
    @tip.tip.style.maxWidth = \16em
    @tip.tip.style.wordBreak = \normal
    if (alt = @tip.tip.querySelector '[ld=value-alt]') => alt.style.whiteSpace = \pre-line

  destroy: ->
    @g.view.removeEventListener \mouseover, @_evthdr.over
    @g.view.removeEventListener \mouseout, @_evthdr.out
    @tip.destroy!
    @legend.destroy!

  parse: ->
    @cols = (@binding.value or []).map (b, i) ->
      {i, key: b.key, name: "#{b.name or b.key}", unit: b.unit or ''}
    seen = {}
    @all = @data
      .map (d, idx) ~>
        name = if d.name? and "#{d.name}".trim! => "#{d.name}" else "\##{idx + 1}"
        # 同名的項目仍是不同的線
        seen[name] = (seen[name] or 0) + 1
        key = if seen[name] > 1 => "#name\u0000#{seen[name]}" else name
        values = @cols.map (c) -> if num((d.value or [])[c.i]) => d.value[c.i] else NaN
        valid = values.map((v, i) -> i).filter (i) -> !isNaN(values[i])
        first = valid.0
        last = valid[* - 1]
        change = if valid.length > 1 => values[last] - values[first] else NaN
        pct = if isNaN(change) or values[first] == 0 => NaN else change / Math.abs(values[first])
        cat = if d.category? and "#{d.category}".trim! => "#{d.category}" else ''
        {key, name, cat, values, valid, first, last, change, pct, _raw: d._raw, _idx: idx}
      .filter -> it.valid.length
    @all.map -> it.item = it

  bind: ->
    if @cfg.palette => @tint.set @cfg.palette
    ccfg = @cfg.coloring or {}
    mode = ccfg.mode or \trend
    if mode == \category and !@binding.category => mode = \palette
    @color-mode = mode
    th = (@cfg.trend or {}).threshold or 0
    @all.map (d) ->
      d.trend = if isNaN(d.change) or Math.abs(d.change) <= th => \flat
      else if d.change > 0 => \increase else \decrease
      d.lk = switch mode
      | \trend => d.trend
      | \category => d.cat
      | otherwise => d.key

    # legend 項目
    entries = switch mode
    | \trend => <[increase decrease flat]>.map (k) ~>
        {key: k, text: t(if k == \flat => "no change" else k), value: (@all.filter -> it.trend == k).length}
    | \category =>
      Array.from(new Set(@all.map (.cat))).filter(-> it).map (k) ~>
        {key: k, text: k, value: (@all.filter -> it.cat == k).length}
    | otherwise =>
      # 項目太多時 legend 只是干擾, 兩端已經直接標名字了
      if @all.length > 12 => [] else @all.map -> {key: it.key, text: it.name, value: it.values[it.last]}
    entries = entries.filter -> it.value
    if mode == \trend and entries.length == 1 and entries.0.key == \flat => entries = []
    @legend.config @legend-opt!
    @legend.data entries
    known = Object.fromEntries entries.map -> [it.key, true]
    use-legend = @legend.enabled!
    @items = @all.filter (d) ~> !(use-legend and known[d.lk]) or @legend.is-visible(d.lk)
    @items.map (d) ~> d.dim = !!(use-legend and known[d.lk] and !@legend.is-selected(d.lk))

    # 強調: 被強調的畫在最上層
    ecfg = @cfg.emphasis or {}
    em = ecfg.mode or \none
    hit = switch em
    | \increase => (d) -> d.trend == \increase
    | \decrease => (d) -> d.trend == \decrease
    | \names =>
      set = {}
      "#{ecfg.names or ''}".split(/[,\n]/).map(-> it.trim!).filter(-> it).map -> set[it] = true
      (d) -> !!set[d.name]
    | \largest =>
      top = @items.filter(-> !isNaN(it.change))
        .sort (a, b) -> Math.abs(b.change) - Math.abs(a.change)
        .slice 0, (ecfg.count or 3)
      (d) -> d in top
    | otherwise => null
    @items.map (d) -> d.emph = if hit => hit(d) else null
    @items.sort (a, b) -> ((if a.emph => 1 else 0) - (if b.emph => 1 else 0)) or (a._idx - b._idx)

  resize: ->
    {cfg, items, cols} = @
    @tip.toggle(if @cfg.{}tip.enabled? => @cfg.tip.enabled else true)
    @root.querySelector('.pdl-layout').classList.toggle \legend-bottom, cfg.legend.position != \right
    @legend.config @legend-opt!
    @legend.update!
    @layout.update false
    box = @layout.get-box \view
    [w, h] = [box.width, box.height]
    @text-cache = {}
    @bg = bg-of @root
    fs = parseFloat(getComputedStyle(@g.view).fontSize) or 16
    lb = cfg.label
    nc = cols.length
    lsize = fs * (lb.size or 0.8)
    lh = lsize * 1.25
    sw = cfg.line.stroke-width or 2
    r = if cfg.dot.show => (cfg.dot.size or 3.5) else sw / 2
    hdr-size = fs * (cfg.header.size or 0.9)
    hh = if cfg.header.show and nc => Math.ceil(hdr-size * 1.5) else 0
    pad = Math.max(lh / 2, r) + 1
    y0 = hh + pad
    y1 = (h - pad) >? (y0 + 1)
    rng = y1 - y0
    rev = !!cfg.scale.reverse
    rank-mode = cfg.scale.mode == \rank

    # y: 名次 ( 同值同名次 ) 或線性
    if rank-mode =>
      for c in cols
        vs = items.filter(-> !isNaN it.values[c.i]).map -> it.values[c.i]
        vs.sort (a, b) -> if rev => a - b else b - a
        items.map (d) ->
          v = d.values[c.i]
          (d.ranks ?= [])[c.i] = if isNaN(v) => null else vs.indexOf(v) + 1
      maxr = Math.max.apply(Math, [1] ++ items.map (d) -> Math.max.apply(Math, d.ranks.filter((x) -> x?)))
      yf = (d, i) -> if maxr > 1 => y0 + (d.ranks[i] - 1) / (maxr - 1) * rng else y0 + rng / 2
    else
      items.map -> delete it.ranks
      vs = []
      items.map (d) -> d.valid.map (i) -> vs.push d.values[i]
      [lo, hi] = if vs.length => [Math.min.apply(Math, vs), Math.max.apply(Math, vs)] else [0, 1]
      if cfg.scale.include-zero => [lo, hi] = [lo <? 0, hi >? 0]
      if lo == hi => [lo, hi] = [lo - 1, hi + 1]
      s = Scale.linear!domain([lo, hi]).range(if rev => [y0, y1] else [y1, y0])
      yf = (d, i) -> s d.values[i]

    # 排序時同高的項目依相鄰欄位排, 引線才不會交叉
    items.map (d) -> d.pts = d.valid.map (i) -> {item: d, col: i, y: yf(d, i), _raw: d._raw}
    y-at = (d, i) -> ((d.pts.find (p) -> p.col == i) or {}).y
    fmt = format.from(lb.format or \.3~s)
    side-cfg = {left: lb.left or {}, right: lb.right or {}}

    # 每欄每側一組標籤
    groups = {}
    add = (d, col, side, cf, inner) ->
      if !(cf.show-name or cf.show-value) => return
      c = cols[col]
      v-text = if lb.rank and d.ranks => "\##{d.ranks[col]}" else "#{fmt d.values[col]}#{c.unit}"
      (groups["#col:#side"] ?= {col, side, list: []}).list.push {
        item: d, col: col, side: side, inner: inner, _raw: d._raw
        ty: y-at(d, col), y: y-at(d, col)
        name: (if cf.show-name => d.name else '')
        value: (if cf.show-value => v-text else '')
        key: "#{d.key}:#col:#side"
      }
    single-cfg =
      show-name: side-cfg.right.show-name or side-cfg.left.show-name
      show-value: side-cfg.right.show-value or side-cfg.left.show-value
    for d in items
      for p in d.pts
        i = p.col
        if nc == 1 => add d, i, \right, single-cfg, false
        else if i == 0 => add d, i, \left, side-cfg.left, false
        else if i == nc - 1 => add d, i, \right, side-cfg.right, false
        # 只存在於中間欄的端點 ( 前後缺值 ), 名字就近標
        else if i == d.first and i != d.last => add d, i, \left, side-cfg.left, false
        else if i == d.last => add d, i, \right, side-cfg.right, false
        else if lb.middle => add d, i, \right, {show-value: true}, true

    # 放不下就只留重要的: 強調的優先, 再來是變化大的
    cap = Math.floor(rng / lh) + 1
    do-dodge = lb.dodge != false
    for k, g of groups
      if do-dodge and g.list.length > cap =>
        score = (e) -> if rank-mode and e.item.ranks =>
          Math.abs(e.item.ranks[e.item.last] - e.item.ranks[e.item.first])
        else (Math.abs(e.item.change) or 0)
        g.list.sort (a, b) ->
          ((if b.item.emph => 1 else 0) - (if a.item.emph => 1 else 0)) or (score(b) - score(a))
        g.list.splice cap
      other = if g.side == \left => (d, c) -> y-at(d, d.valid[d.valid.indexOf(c) + 1]) else (d, c) -> y-at(d, d.valid[d.valid.indexOf(c) - 1])
      g.list.sort (a, b) ->
        (a.ty - b.ty) or ((other(a.item, g.col) or 0) - (other(b.item, g.col) or 0)) or (a.item._idx - b.item._idx)
      if do-dodge => dodge g.list, lh, y0, y1
      # 需要引線的組, 標籤要多退一點讓引線有地方走
      g.leader = lb.leader != false and g.list.some -> Math.abs(it.y - it.ty) > 1
      g.gap = r + (lb.padding ? 5) + (if g.leader => lsize else 0)

    # 寬度: 量每個標籤, 兩側預留. 兩側總寬有上限, 其餘給圖
    sp = lsize * 0.4
    tw = (e) ~>
      nw = if e.name => @text-w(e.name, lsize, e.item.emph) else 0
      vw = if e.value => @text-w(e.value, lsize, true) else 0
      nw + (if nw and vw => sp else 0) + vw
    edge = (side) ->
      list = []
      for k, g of groups => if g.side == side and (g.col == 0 or g.col == nc - 1) and (side == \left) == (g.col == 0 or nc == 1) =>
        list.push g
      list
    min-plot = Math.max(w * 0.3, (if nc > 2 => (nc - 1) * 32 else 40))
    cap-s = Math.min(w * 0.36, (w - min-plot) / 2) >? 0
    fit = (side) ~>
      # nc = 1 時只有右側, 上限可以放寬
      limit = if nc == 1 => w * 0.6 else cap-s
      gs = edge side
      if !gs.length => return r + 2
      g = gs.0
      allow = limit - g.gap
      want = 0
      for e in g.list
        vw = if e.value => @text-w(e.value, lsize, true) else 0
        if vw > allow =>
          e.value = ''
          vw = 0
        na = allow - vw - (if vw => sp else 0)
        if e.name =>
          if na < lsize * 2 => e.name = ''
          else e.name = trunc e.name, na, (s) ~> @text-w(s, lsize, e.item.emph)
        want = want >? tw(e)
      if !want => return r + 2
      want + g.gap
    left = fit \left
    right = fit \right
    x-pos = if nc == 1 => [((w - right) / 2) >? r]
    else if nc > 1
      x0 = left
      x1 = (w - right) >? (x0 + 1)
      [x0 + (x1 - x0) * i / (nc - 1) for i from 0 til nc]
    else []
    spacing = if nc > 1 => x-pos.1 - x-pos.0 else w

    # 中間欄的標籤放不下就不放. 端點 ( 含前後缺值的 ) 留著
    for k, g of groups
      if g.col == 0 and g.side == \left or g.col == nc - 1 and g.side == \right => continue
      inner = g.list.filter (.inner)
      if inner.length =>
        need = Math.max.apply(Math, inner.map tw) + g.gap + r
        if spacing < need => g.list = g.list.filter -> !it.inner
      for e in g.list
        allow = spacing - g.gap - r
        if e.name and tw(e) > allow =>
          vw = if e.value => @text-w(e.value, lsize, true) else 0
          na = allow - vw - (if vw => sp else 0)
          e.name = if na < lsize * 2 => '' else trunc e.name, na, (s) ~> @text-w(s, lsize, e.item.emph)

    # 把座標寫回資料, render 只管畫
    labels-list = []
    leaders = []
    for k, g of groups
      cx = x-pos[g.col]
      dir = if g.side == \left => -1 else 1
      for e in g.list
        if !(e.name or e.value) => continue
        e.x = cx + dir * g.gap
        labels-list.push e
        if g.leader and Math.abs(e.y - e.ty) > 1 =>
          leaders.push {
            key: e.key, item: e.item, _raw: e._raw
            d: "M#{cx + dir * (r + 1)},#{e.ty}L#{e.x - dir * 2},#{e.y}"
          }
    items.map (d) -> d.pts.map (p) -> p.x = x-pos[p.col]
    @geo = {w, h, hh, y0, y1, pad, r, sw, lsize, sp, hdr-size, x-pos, spacing, labels: labels-list, leaders, nc}

  render: ->
    {items, cols, cfg, geo, tint} = @
    {lsize, sp, r, sw, x-pos, spacing, hh, y1, pad, hdr-size} = geo
    an = cfg.animation or {}
    dur = if an.enabled != false => (an.duration ? 350) else 0
    tween = (n, attrs, opt = {}) ~> @anim.tween n, attrs, ({duration: dur} <<< opt)
    fade-out = (n) ->
      n.style.pointerEvents = \none
      tween n, {opacity: 0}, {remove: true}
    set = (n, attrs) -> for k, v of attrs => n.setAttribute k, v
    color = (d) ~>
      switch @color-mode
      | \trend => cfg.trend[d.trend]
      | \category => (if d.cat => tint.get(d.cat) else cfg.trend.flat)
      | otherwise => tint.get d.name
    # 整項的透明度: 被 emphasis 淡化 / 被 legend 淡化
    op = (d) ~> if d.emph == false => (cfg.emphasis.dim ? 0.25) else if d.dim => @legend.opacity! else 1
    mode-curve = cfg.line.mode == \curve
    connect = cfg.line.missing == \connect

    path = (d) ->
      ret = ''
      prev = null
      for p in d.pts
        if !prev or (!connect and p.col != prev.col + 1) => ret += "M#{p.x},#{p.y}"
        else if mode-curve =>
          mx = (prev.x + p.x) / 2
          ret += "C#mx,#{prev.y} #mx,#{p.y} #{p.x},#{p.y}"
        else ret += "L#{p.x},#{p.y}"
        prev = p
      ret

    # 基準線
    bl = if cfg.baseline.show => cols else []
    bj = join root: @g.baseline, tag: \line, cls: \base, data: bl, key: (.key)
    bj.exit.map fade-out
    bj.enter.map (n) ->
      x = x-pos[n.__data__.i]
      set n, {x1: x, x2: x, y1: hh, y2: y1 + pad, opacity: 0}
    bj.nodes.map (n) ->
      x = x-pos[n.__data__.i]
      n.setAttribute \stroke, cfg.baseline.color
      n.setAttribute \stroke-width, cfg.baseline.width ? 1
      tween n, {x1: x, x2: x, y1: hh, y2: y1 + pad, opacity: cfg.baseline.opacity ? 0.25}

    # 線: 另一層粗而透明的路徑當滑鼠範圍, 細線才容易 hover
    lj = join root: @g.line, tag: \path, cls: \s-item, data: items, key: (.key)
    lj.exit.map fade-out
    lj.enter.map (n) ->
      d = n.__data__
      set n, {d: path(d), stroke: color(d), "stroke-opacity": 0, "stroke-linecap": \round, "stroke-linejoin": \round}
    lj.nodes.map (n) ->
      d = n.__data__
      tween n, do
        d: path(d)
        stroke: color(d)
        "stroke-opacity": (cfg.line.opacity ? 0.85) * op(d)
        "stroke-width": if d.emph => sw * 1.5 else sw
      n.parentNode.appendChild n

    hj = join root: @g.hit, tag: \path, cls: \s-item, data: items, key: (.key)
    hj.exit.map -> it.remove!
    hj.nodes.map (n) ->
      set n, {d: path(n.__data__), stroke: \transparent, "stroke-width": sw + 10}

    # 點
    pts = if cfg.dot.show => [].concat.apply([], items.map (.pts)) else []
    dj = join root: @g.dot, tag: \circle, cls: \s-item, data: pts, key: (p) -> "#{p.item.key}:#{p.col}"
    dj.exit.map fade-out
    dj.enter.map (n) ~>
      p = n.__data__
      set n, {cx: p.x, cy: p.y, r: cfg.dot.size, fill: color(p.item), stroke: @bg, opacity: 0}
    dj.nodes.map (n) ~>
      p = n.__data__
      n.setAttribute \stroke, @bg
      n.setAttribute \stroke-width, 1
      tween n, {cx: p.x, cy: p.y, r: cfg.dot.size ? 3.5, fill: color(p.item), opacity: op(p.item)}

    # 引線
    gj = join root: @g.leader, tag: \path, cls: \s-item, data: geo.leaders, key: (.key)
    gj.exit.map fade-out
    gj.enter.map (n) ->
      set n, {d: n.__data__.d, opacity: 0}
    gj.nodes.map (n) ->
      d = n.__data__
      set n, {stroke: color(d.item), "stroke-width": 0.75}
      tween n, {d: d.d, opacity: 0.55 * op(d.item)}

    # 標籤: 數值靠線, 名稱在外側
    tj = join root: @g.label, tag: \text, cls: \s-label, data: geo.labels, key: (.key)
    tj.exit.map fade-out
    tj.enter.map (n) ->
      e = n.__data__
      set n, {x: e.x, y: e.y, opacity: 0}
      [0 1].map -> n.appendChild document.createElementNS(svgns, \tspan)
    tj.nodes.map (n) ~>
      e = n.__data__
      n.classList.add \s-item
      left = e.side == \left
      [first, second] = [n.childNodes.0, n.childNodes.1]
      [name-n, value-n] = if left => [first, second] else [second, first]
      name-n.textContent = e.name
      value-n.textContent = e.value
      name-n.setAttribute \font-weight, (if e.item.emph => 600 else 400)
      name-n.setAttribute \fill-opacity, 0.8
      value-n.setAttribute \font-weight, 600
      # 兩段中間留空; 順序是由左往右, 所以 dx 永遠加在第二段
      second.setAttribute \dx, (if e.name and e.value => sp else 0)
      first.removeAttribute \dx
      fill = if cfg.label.color == \line => color(e.item) else \currentColor
      set n, {"text-anchor": (if left => \end else \start), "font-size": lsize, dy: \.35em, fill}
      # 中間欄的標籤疊在線上, 用背景色描邊把線隔開
      n.classList.toggle \s-inner, !!e.inner
      if e.inner => set n, {stroke: @bg, "stroke-width": 3, "paint-order": \stroke, "stroke-linejoin": \round}
      else [\stroke \stroke-width \paint-order \stroke-linejoin].map -> n.removeAttribute it
      tween n, {x: e.x, y: e.y, opacity: op(e.item)}

    # 欄標題
    hdrs = if cfg.header.show => cols else []
    hj2 = join root: @g.header, tag: \text, cls: \s-header, data: hdrs, key: (.key)
    hj2.exit.map fade-out
    limit = if geo.nc > 1 => spacing * 0.95 else geo.w
    place = (n) ~>
      c = n.__data__
      txt = trunc c.name, limit, (s) ~> @text-w(s, hdr-size, true)
      n.textContent = txt
      tw = @text-w(txt, hdr-size, true)
      {x: ((x-pos[c.i] >? (tw / 2)) <? ((geo.w - tw / 2) >? (tw / 2))), y: hdr-size}
    hj2.enter.map (n) ->
      p = place n
      set n, {x: p.x, y: p.y, opacity: 0}
    hj2.nodes.map (n) ->
      p = place n
      set n, {"text-anchor": \middle, "font-size": hdr-size, "font-weight": 600, fill: cfg.header.color}
      tween n, {x: p.x, y: p.y, opacity: 1}

    @g.view.style.setProperty \--slope-dim, (cfg.hover.dim ? 0.15)
    @legend.render!
