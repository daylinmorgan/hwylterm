{.define: bbansiOn.}
# these test cases can be generated using
# tools/bbansi

# TODO: use fixTest more here?

import std/[sequtils, strutils, strformat, unittest]
import hwylterm/bbansi
import ./lib

template `~=`(input: string, output: string): bool =
  escape($bb(input)) == escape(output)

proc dofixTests(prefix: string, a: openArray[string]) =
  for i, s in a:
    fixTest(fmt"{prefix}/{i+1:03}", bb(s))

proc dofixTests(prefix: string, a: openArray[BbString]) =
  for i, s in a:
    fixTest(fmt"{prefix}/{i+1:03}", s)

suite "basic":
  test "simple":
    doFixTests("basic-simple"): [
      "[b]Bold[/] Not Bold",
      "[red]red text",
      "[yellow]Yellow Text",
      "[bold red]Bold Red Text",
      "[bold][red]5",
      "[color(9)]red[/color(9)][color(2)]blue[/color(2)]",
      "[red]Red Text[/]\nNext Line",
      "[red on yellow]Red on Yellow",
      "[#FF0000]red"
    ]

    check "[red]RED[/]".bb.len == 3

  test "compile time":
    const s = bb"[red]red text"
    check s == bb"[red]red text"

  test "closing":
    doFixTests("basic-closing"): [
      "[bold]Bold[red] Bold Red[/red] Bold Only",
      "[bold]daughter of [magenta]atlas[/magenta], [i]installer of packages[/i][/bold]"
    ]

  test "noop":
    doFixTests("basic-noop"): [
      "[red][/red]",
      "[color(256)]no color![/]",
      "[unknown]Unknown Style",
      "No Style",
    ]

  test "escaped":
    doFixTests("basic-escaped"): [
      "[[red] ignored pattern",
      "\\[red] ignored pattern"
    ]

  test "spans":
    check bb("[red]red[/][blue]blue[/]").spans.len == 2
    check bb("[red]red[/red][blue]blue[/]").spans.len == 2

  test "style insensitive":
    doFixTests("basic-style-insensitive"): [
      "[red]no case sensitivity[/RED]",
      "[bright_red]should be BrightRed[/]",
      "[BrightRed]should be BrightRed[/]",
    ]

  test "style full":
    doFixTests("basic-style-full"): [
      bb("Red", "red"),
      bb("color 9", 9),
      bb(bb"[yellow]yellow[/] not yellow", "b")
    ]

  test "escape":
    check bbEscape("[info] brackets") == "[[info] brackets"
    check bbEscape("[info] brackets") ~= "[info] brackets"

  test "fmt":
    let x = 5
    check $bbfmt"[red]{x}" == "\e[38;5;1m5\e[0m"

suite "strutils":
  test "concat":
    doFixTests("strutils-concat"): [
      "[red]RED[/]".bb & " plain string",
      bb("[blue]Blue[/]") & " " & bb("[red]Red[/]"),
      "a plain string" & "[blue] a blue string".bb
    ]

    var s = bb("[red]red")
    s.add bb("[blue]blue")
    check escape($s) == escape($bb("[red]red[/][blue]blue[/]"))

  test "stripAnsi":
    check stripAnsi($bb"[red]red!") == "red!"
    check stripAnsi("\e[1mBold String!") == "Bold String!"

  test "truncate":
    let tester = bb"[red]a red[/] [blue on red]blue on red part"
    check tester.truncate(50) == tester
    check tester.truncate(5) == bb"[red]a red"
    check tester.truncate(10) == bb"[red]a red[/] [blue on red]blue"

  test "align":
    check (bb"[red]red").align(10) == bb"       [red]red"
    check (bb"[red]red").alignLeft(10) == bb"[red]red[/]       "

  test "add":
    var x = bb("[red]red")
    x.add bb("[yellow]yellow")
    check bb"[red]red[/][yellow]yellow[/]" == x

    var y = bb("[red]red")
    y.add "yellow"
    check bb"[red]red[/]yellow" == y

  test "wrapping":
    doFixTests("strutils-wrapping"): [
      "[bold]This is a [italic]long string[/italic] that will be wrapped I hope[/]".bb().wrapWords(20),
      "[[bold]This is a [red]long string[/] with markup like text".bb().wrapWords(20),
    ]

  test "slicing":
    check bb"[red]long string[/]"[0..3] == bb"[red]long[/]"
    expect IndexDefect:
      discard bb"[red]long"[0..10]

  test "linesplit":
    check bb("[b]bold text\nwith [i]multiple[/i] lines").splitLines.toSeq() == @[bb"[b]bold text[/]", bb"[b]with [i]multiple[/i] lines" ]
    check bb("[b]bold text\nwith [i]multiple[/i] lines").splitLines(keepEol=true).toSeq() ==
      @[bb("[b]bold text\n[/]"), bb("[b]with [i]multiple[/i] lines")]



