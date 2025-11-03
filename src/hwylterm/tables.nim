import std/[macros, sequtils, strformat, sets, tables]
import ./bbansi
export bbansi

# conflicts with bbansi.join for some reason
# something to do with the join[T: not string] version
import std/strutils except join

type
  HwylTable* = object
    rows*: seq[seq[BbString]]

  HwylTableError* = object of CatchableError

func makeBbSeqNode(items: varargs[NimNode]): NimNode =
  ## Helper proc to generate a `seq[BbString]` node
  ## Wraps all arguments in `bb(bbEscape(item))`
  var bracket = newNimNode(nnkBracket)
  for item in items:
    bracket.add(newCall(ident "bb", newCall(ident "bbEscape", item)))
  result = prefix(bracket, "@")

macro toRow*(items: varargs[untyped]): untyped =
  ## convience macro to generate a `seq[Bbstring]`
  ## essentially wraps all arguments in `bb(bbEscape(item))`
  ## for a regular BbString these are both noops
  ## ```nim
  ##  toRow(bb"[red] a bb string", "a non bb string"))
  ## ```
  makeBbSeqNode(items.children.toSeq())

macro toCol*(items: varargs[untyped]): untyped =
  ## convience macro to generate a `seq[Bbstring]`
  ## essentially wraps all arguments in `bb(bbEscape(item))`
  ## for a regular BbString these are both noops
  ## ```nim
  ##  toCol(bb"[red] a bb string", "a non bb string"))
  ## ```
  makeBbSeqNode(items.children.toSeq())

macro toBbSeq*(items: varargs[untyped]): untyped =
  ## convience macro to generate a `seq[Bbstring]`
  ## essentially wraps all arguments in `bb(bbEscape(item))`
  ## for a regular BbString these are both noops
  ## ```nim
  ##  toBbSeq(bb"[red] a bb string", "a non bb string"))
  ## ```
  makeBbSeqNode(items.children.toSeq())

macro hwylTableBlock*(body: untyped): untyped =
  ## create a table from a list of tuples
  ## ```nim
  ## let blockTable = hwylTableBlock:
  ##   ["ID",  "Name"               ,  "Department"        ]
  ##   ("1" ,bb"[bold]Alice Johnson",  "Engineering"       )
  ##   ("2" ,  "Bob Smith"          ,bb"[blue]Marketing"   )
  ##   ("3" ,bb"[bold]Carol White"  ,  "Sales"             )
  ##   ("4" ,  "David Brown"        ,bb"[green]Engineering")
  ## ```
  result = newStmtList()

  expectKind body, nnkStmtList
  var rows = nnkBracket.newTree()
  for row in body:
    expectKind row, {nnkTupleConstr, nnkBracket}
    rows.add newCall(ident"toRow", row.children.toSeq())

  result.add nnkObjConstr.newTree(
    ident"HwylTable",
    newColonExpr(ident"rows", prefix(rows, "@"))
  )

func addRow*(
  t: var HwylTable,
  cols: varargs[BbString]
) =
  t.rows.add @cols

func addRow*(
  t: var HwylTable,
  cols: varargs[string]
) =
  t.rows.add (@cols).mapIt(bb(bbEscape(it)))

func addCol*(
  t: var HwylTable,
  col: varargs[BbString]
) =
  if @col.len != t.rows.len:
    raise newException(HwylTableError, fmt"Failed to add column, must have the same number of rows as table")
  for i in 0..<t.rows.len:
    t.rows[i].add col[i]

func addCol*(
  t: var HwylTable,
  col: varargs[string]
) =
  if @col.len != t.rows.len:
    raise newException(HwylTableError, fmt"Failed to add column, must have the same number of rows as table")
  for i in 0..<t.rows.len:
    t.rows[i].add col[i].bbEscape().bb()

proc toHwylTable*[A, B](pairs: openArray[(A, B)]): HwylTable =
  when B is string:
    {.error: "Cannot coerce string to columns. Use seq or array instead.".}
  if pairs.mapIt(it[1].len).toHashSet().len != 1:
    raise newException(HwylTableError, fmt"Failed to generate table, columns must have the same number of rows")
  let nCols = pairs.len
  for i in 0..(pairs[0][1].len):
    result.rows.add newSeq[BBString](ncols)
  for i in 0..<pairs.len:
    let (key,col) = pairs[i]
    result.rows[0][i] = bb($key)
    for j, row in col:
      result.rows[j+1][i] = bb($row)


proc toHwylTable*[A, B](t: Table[A, B]): HwylTable =
  t.pairs.toSeq().toHwylTable()

proc toHwylTable*[A, B](t: OrderedTable[A, B]): HwylTable =
  t.pairs.toSeq().toHwylTable()

type
  HwylTableSepType* = enum
    None, Ascii, Box, BoxRounded

  HwylTableSeps* = object
    topLeft, topRight, topMiddle,
      bottomLeft, bottomRight, bottomMiddle,
      centerLeft, centerRight, centerMiddle,
      vertical, horizontal: string

const HwylTableSepsByType* = [
  None: HwylTableSeps(topLeft: " ", topRight: " ", topMiddle: " ", bottomLeft: " ",
    bottomMiddle: " ", bottomRight: " ", centerLeft: " ", centerMiddle: " ",
    centerRight: " ", vertical: " ", horizontal: " "),
  Ascii: HwylTableSeps(topLeft: "+", topRight: "+", topMiddle: "+", bottomLeft: "+",
    bottomMiddle: "+", bottomRight: "+", centerLeft: "+", centerMiddle: "+",
    centerRight: "+", vertical: "|", horizontal: "-"),
  Box: HwylTableSeps(topLeft: "┌", topRight: "┐", topMiddle: "┬", bottomLeft: "└",
    bottomMiddle: "┴", bottomRight: "┘", centerLeft: "├", centerMiddle: "┼",
    centerRight: "┤", vertical: "│", horizontal: "─"),
  BoxRounded: HwylTableSeps(topLeft: "╭", topRight: "╮", topMiddle: "┬", bottomLeft: "╰",
    bottomMiddle: "┴", bottomRight: "╯", centerLeft: "├", centerMiddle: "┼",
    centerRight: "┤", vertical: "│", horizontal: "─")
  # TODO:
  # BoxThick
  # BoxDouble
]

type
  ColumnAlign* = enum
    Left, Center, Right
  # CellOverflow* = enum
  #   Wrap, Truncate

  # TODO: docstrings
  HwylTableStyle* = object
    headerStyle* = "bold"
    rowStyles*: seq[string] = @[]
    headerAlign*: seq[ColumnAlign] = @[]
    colAlign*: seq[ColumnAlign] = @[]
    header* = true
    border* = true
    headerSep* = true
    rowSep* = false
    colSep* = true
    sepStyle* = ""
    # cellOverflow: CellOverflow = Wrap
    seps* = HwylTableSepsByType[BoxRounded]

func newHwylTableStyle*(sepType: HwylTableSepType): HwylTableStyle =
  result = HwylTableStyle()
  result.seps = HwylTableSepsByType[sepType]

func getRowStyle(s: HwylTableStyle, num: Natural): string =
  if s.rowStyles.len == 0: return ""
  s.rowStyles[num mod s.rowStyles.len]

func vSep(style: HwylTableStyle, grid = false): string=
  if grid:
    if style.colSep: style.seps.horizontal & style.seps.centerMiddle & style.seps.horizontal
    else: style.seps.horizontal
  else:
    if style.colSep: " " & style.seps.vertical & " "
    else: " "

func hSep(style: HwylTableStyle, w: Natural): BbString =
  style.seps.horizontal.repeat(w).bb()

func renderDiv*(
  t: HwylTable,
  style: HwylTableStyle,
  colWidths: seq[int],
): BbString =
  let seps =  style.seps

  result.add style.hSep(colWidths[0])
  for i in 1..<colWidths.len:
    result.add style.vSep(grid = true)
    result.add style.hSep(colWidths[i])

  if style.border:
    result = (seps.centerLeft & seps.horizontal & result & seps.horizontal & seps.centerRight)
  result = result.bb(style.sepStyle)

func getColAlign(style: HwylTableStyle, i: Natural): ColumnAlign =
  if style.colAlign.len == 0: return Left
  style.colAlign[i]

func getHeaderAlign(style: HwylTableStyle, i: Natural): ColumnAlign =
  if style.headerAlign.len == 0: return getColAlign(style, i)
  style.headerAlign[i]

func renderRow*(
  row: seq[BbString],
  style: HwylTableStyle,
  colWidths: seq[int],
): BbString =
 result = join(row, style.vSep.bb(style.sepStyle))

 if style.border:
  let vSep = style.seps.vertical.bb(style.sepStyle)
  result = (
    vSep & " " & result & " " & vSep
  )

func renderRows*(
  t: HwylTable,
  style: HwylTableStyle,
  colWidths: seq[int],
): BbString =
  var rows: seq[BbString]
  for i, r in t.rows[1..^1]:
    rows.add renderRow(r, style, colWidths)
  if style.rowSep:
    result = bbansi.join(rows,"\n" & t.renderDiv(style, colWidths) & "\n")
  else:
    result.add bbansi.join(rows,"\n")

func renderHeader*(
  t: HwylTable,
  style: HwylTableStyle,
  colWidths: seq[int],
): Bbstring =
  result = renderRow(t.rows[0], style, colWidths)

func getRowLengths*(
  t: HwylTable,
): seq[seq[int]] =
  for r in t.rows:
    var rowL: seq[int]
    for col in r:
      rowL.add col.len
    result.add rowL

func getColWidths*(
  t: HwylTable
): seq[int] =
  result = newSeq[int](t.rows[0].len)
  let rowLengths = t.getRowLengths()
  for i in 0..<result.len:
    result[i] = rowLengths.mapIt(it[i]).max()

func borderMiddleSep*(style: HwylTableStyle, top = false): string =
  let middle =
    if not style.colSep: style.seps.horizontal
    else:
      if top: style.seps.topMiddle else: style.seps.bottomMiddle
  (style.seps.horizontal & middle & style.seps.horizontal)

func borderMiddle*(colWidths: seq[int], style: HwylTableStyle, top = false): string =
  strutils.join(colWidths.mapIt(style.seps.horizontal.repeat(it+(if style.colSep: 1 else: 0))), style.borderMiddleSep(top=top))

proc topBorder*(
  colWidths: seq[int],
  style: HwylTableStyle
): BbString =
  let seps = style.seps
  result.add seps.topLeft
  result.add borderMiddle(colWidths, style, top = true)
  result.add seps.topRight

  result = result.bb(style.sepStyle)

func bottomBorder*(
  colWidths: seq[int],
  style: HwylTableStyle
): BbString =
  let seps = style.seps
  result.add seps.bottomLeft
  result.add borderMiddle(colWidths, style)
  result.add seps.bottomRight
  result = result.bb(style.sepStyle)


proc validate*(t: HwylTable) =
  var nCols: HashSet[Natural]
  for i, row in t.rows:
    nCols.incl row.len
  if nCols.len > 1:
    raise newException(HwylTableError, fmt"Failed to render table, rows must have the same number of columns")

proc normStyle(style: HwylTableStyle, nCols: Natural): HwylTableStyle =
  if style.colAlign.len != 0 and style.colAlign.len != nCols:
    raise newException(HwylTableError, fmt"Failed to render table, colAlign must have the same number of columns as table")

  if style.headerAlign.len != 0 and style.headerAlign.len != nCols:
    raise newException(HwylTableError, fmt"Failed to render table, headerAlign must have the same number of columns as table")

  # NOTE: should headers be centered by default?
  result = style


func transformCell(
  elem: Bbstring,
  rowStyle: string,
  width: Natural,
  colAlign: ColumnAlign
): BbString =

  case colAlign
  of Left:
    result = elem.alignLeft(width)
  of Center:
    # need rune/markup aware centering in bbansi
    assert false
  of Right:
    result = elem.align(width)

  result = result.bb(rowStyle)

proc transformRow(
  cols: seq[BbString],
  style: HwylTableStyle,
  rowStyle: string,
  widths: seq[int],
  header = false
): seq[BbString] =
  for i in 0..<cols.len:
    let align = if header: style.getHeaderAlign(i) else: style.getColAlign(i)
    result.add cols[i].transformCell(rowStyle, widths[i], align)

# will need to splitlines of the bbstrings then
# make a markup aware line splitter?
# [red]red text          & [blue] blue [/]
# next line still red[/] & not blue
#
# [red]red text        [/red][blue] blue [/]
# [red]next line still red[/]not blue

# proc hconcat(
#   a: openArray[BbString],
#   sep: string | BbString
# ): BbString =
#
#

proc transform*(
  t: HwylTable,
  s: HwylTableStyle,
  widths: seq[int]
): HwylTable =
  ## apply cell level styling and alignment
  # TODO: expand these transformations as necessary, to truncate or wrap cells (if necessary, adding extra lines/whitespace)

  var i = 0
  if s.header:
    result.addRow transformRow(t.rows[0], s, s.headerStyle, widths, header=true)
    inc i

  for j, row in t.rows[i..^1]:
    result.addRow transformRow(row,s, s.getRowStyle(j), widths)

proc render*(
  t: HwylTable,
  style = HwylTableStyle()
): BbString =
  validate t
  let widths = t.getColWidths()
  let style = normStyle(style, widths.len)

  let t = transform(t, style, widths)
  if style.border:
    result.add topBorder(widths, style)
    result.add "\n"
  if style.header:
    result.add renderRow(t.rows[0], style, widths)
    result.add "\n"
    if style.headerSep:
      result.add t.renderDiv(style, widths)
  result.add "\n"
  result.add t.renderRows(style, widths) # todo: row delimiter?
  if style.border:
    result.add "\n"
    result.add bottomBorder(widths, style)

