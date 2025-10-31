import std/[macros, sequtils, strformat,sets]
import ./bbansi
export bbansi

# conflicts with bbansi.join for some reason
# something to do with the join[T: not string] version
import std/strutils except join

type
  HwylTable* = object
    rows*: seq[seq[BbString]]

  HwylTableError* = object of CatchableError

macro toRow*(items: varargs[untyped]): untyped =
  ## convience macro to generate a `seq[Bbstring]`
  ## essentially wraps all arguments in `bb(bbEscape(item))`
  ## for a regular BbString these are both noops
  ## ```nim
  ##  toRow(bb"[red] a bb string", "a non bb string"))
  ## ```

  result = newNimNode(nnkPrefix)
  result.add(ident "@")
  var bracket = newNimNode(nnkBracket)
  for item in items:
    bracket.add(newCall(ident "bb", newCall(ident "bbEscape", item)))
  result.add(bracket)

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
]

type
  ColumnAlign* = enum
    Left, Center, Right

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
    sepStyle* = ""
    seps* = HwylTableSepsByType[BoxRounded]

func newHwylTableStyle*(sepType: HwylTableSepType): HwylTableStyle =
  result = HwylTableStyle()
  result.seps = HwylTableSepsByType[sepType]

func getRowStyle(s: HwylTableStyle, num: Natural): string =
  if s.rowStyles.len == 0: return ""
  s.rowStyles[num mod s.rowStyles.len]

func colSep(style: HwylTableStyle): BbString =
  let seps = style.seps
  (seps.horizontal & seps.centerMiddle & seps.horizontal).bb()

func horizontalSep(style: HwylTableStyle, w: Natural): BbString =
  style.seps.horizontal.repeat(w).bb()

func renderDiv*(
  t: HwylTable,
  style: HwylTableStyle,
  colWidths: seq[int],
): BbString =
  let seps =  style.seps

  result.add style.horizontalSep(colWidths[0])
  for i in 1..<colWidths.len:
    result.add style.colsep
    result.add style.horizontalSep(colWidths[i])

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
 let vSep = style.seps.vertical.bb(style.sepStyle)
 result = join(row, " " & vsep & " ")
 if style.border:
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

proc topBorder*(
  colWidths: seq[int],
  style: HwylTableStyle
): BbString =
  let seps = style.seps
  result.add seps.topLeft
  result.add strutils.join(colWidths.mapIt(seps.horizontal.repeat(it+2)),seps.topMiddle)
  result.add seps.topRight

  result = result.bb(style.sepStyle)

func bottomBorder*(
  colWidths: seq[int],
  style: HwylTableStyle
): BbString =
  let seps = style.seps
  result.add seps.bottomLeft
  result.add strutils.join(colWidths.mapIt(seps.horizontal.repeat(it+2)),seps.bottomMiddle)
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

when isMainModule:
  var t = HwylTable(
    rows: @[
      toRow("movie", "box office"),
      toRow("avatar", bb"[red]2,923,706,026"),
      toRow("Avengers: Endgame", bb"[bold]2,797,501,328")
    ]
  )
  # t.addRow(toRow(
  #   "hello", "no go :)"
  # ))
  #
  echo t.render()
  echo t.render(HwylTableStyle(headerAlign: @[Right,Left]))
  #
  # for name, seps in HwylTableSepsByType:
  #   echo name
  #   echo t.render(HwylTableStyle(seps:seps))
  #
  # echo t.render(HwylTableStyle(border:false))
  #
  # echo t.render(HwylTableStyle(
  #   rowStyles: @["italic", "faint"],
  #   rowSep: true,
  #   sepStyle: "cyan",
  #   colAlign: @[Left, Right]
  # ))
  #
  # try:
  #   t.addRow(@["testing"])
  #   discard t.render()
  # except:
  #   echo getCurrentExceptionMsg()
