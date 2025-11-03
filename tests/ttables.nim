import std/unittest
import hwylterm/tables
import ./lib

let table = HwylTable(
  rows: @[
    toRow("movie", "box office"),
    toRow("avatar", bb"[red]2,923,706,026"),
    toRow("Avengers: Endgame", bb"[bold]2,797,501,328")
  ]
)

suite "basic":
  test "render":
    fixTest("table/basic", table.render())
  test "add row":
    var t2 = table
    t2.addRow(toRow("a string", bb"[bold] a bold string"))
    fixTest("table/basic-addrow", t2.render())

  test "wrong # cols":
    var t3 = table
    t3.addRow("one column")
    expect HwylTableError:
      discard t3.render()

    expect HwylTableError:
      discard table.render(HwylTableStyle(colAlign: @[Left]))
    expect HwylTableError:
      discard table.render(HwylTableStyle(headerAlign: @[Left]))

suite "styles":
  for sepType in HwylTableSepType:
    test "septype|" & $sepType :
      fixTest("table/styles/" & $sepType & "-sep", table.render(newHwylTableStyle(sepType = sepType)))

  test "sep-style":
    fixTest("table/styles/sep-style", table.render(HwylTableStyle(rowSep: true, sepStyle: "cyan")))

  test "seps":
    fixTest("table/styles/sep-no-colsep", table.render(HwylTableStyle(colSep: false)))
    fixTest("table/styles/sep-no-border", table.render(HwylTableStyle(border: false)))

  test "row-styles":
    var t4 = table
    t4.rows = t4.rows & t4.rows[1..^1]
    fixTest("table/styles/row-styles", t4.render(HwylTableStyle(rowStyles: @["yellow", "on blue"])))


suite "align":
  for a in [Left, Right]: # TODO: swap with ColumnAlign (Center not supported yet)
    test "align|" & $a:
      fixTest("table/align-" & $a, table.render(HwylTableStyle(colAlign: @[a, a])))

  test "header-align":
    fixTest("table/align-header", table.render(HwylTableStyle(headerAlign: @[Right,Left])))

  test "align-diff":
    var table = HwylTable(
      rows: @[
        toRow("col 1", "col 2"),
        toRow("aaaaaaaaaaaaaaaa", "bbbbbbbbbbbbbbbbbbbb"),
        toRow("c", "d")
      ]
    )
    fixTest("table/align-colAlign", table.render(HwylTableStyle(colAlign: @[Left, Right])))
    fixTest("table/align-colAlign-headerAlign", table.render(HwylTableStyle(colAlign: @[Left, Right], headerAlign: @[Right, Left])))
