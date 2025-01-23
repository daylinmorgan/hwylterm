import std/[os, strutils, unittest]

import hwylterm/bbansi
bbMode = On

template bbCheck(input: string, output: string): untyped =
  check escape($bb(input)) == escape(output)

suite "basic":
  test "simple":
    bbCheck "[red][/red]", ""
    bbCheck "[red]red text", "\e[38;5;1mred text\e[0m"
    bbCheck "[red]Red Text", "\e[38;5;1mRed Text\e[0m"
    bbCheck "[yellow]Yellow Text", "\e[38;5;3mYellow Text\e[0m"
    bbCheck "[bold red]Bold Red Text", "\e[1;38;5;1mBold Red Text\e[0m"
    bbCheck "[red]5[/]", "\e[38;5;1m5\e[0m"
    bbCheck "[bold][red]5","\e[1;38;5;1m5\e[0m"

  test "closing":
    bbCheck "[bold]Bold[red] Bold Red[/red] Bold Only",
      "\e[1mBold\e[0m\e[1;38;5;1m Bold Red\e[0m\e[1m Bold Only\e[0m"

  test "abbreviated":
    bbCheck "[b]Bold[/] Not Bold", "\e[1mBold\e[0m Not Bold"

  test "noop":
    bbCheck "No Style", "No Style"
    bbCheck "[unknown]Unknown Style", "Unknown Style"

  test "escaped":
    bbCheck "[[red] ignored pattern", "[red] ignored pattern"
    bbCheck "\\[red] ignored pattern","[red] ignored pattern"

  test "newlines":
    bbCheck "[red]Red Text[/]\nNext Line", "\e[38;5;1mRed Text\e[0m\nNext Line"

  test "on color":
    bbCheck "[red on yellow]Red on Yellow", "\e[38;5;1;48;5;3mRed on Yellow\e[0m"

  test "concat-ops":
    check "[red]RED[/]".bb & " plain string" == "[red]RED[/] plain string".bb
    check "[red]RED[/]".bb.len == 3
    check bb("[blue]Blue[/]") & " " & bb("[red]Red[/]") ==
        "[blue]Blue[/] [red]Red[/]".bb
    check "a plain string" & "[blue] a blue string".bb ==
        "a plain string[blue] a blue string".bb
    var s = bb("[red]red")
    s.add bb("[blue]blue")
    check escape($s) == escape($bb("[red]red[/][blue]blue[/]"))

  test "spans":
    check bb("[red]red[/][blue]blue[/]").spans.len == 2
    check bb("[red]red[/red][blue]blue[/]").spans.len == 2

  test "style insensitive":
    bbCheck "[red]no case sensitivity[/RED]", "\e[38;5;1mno case sensitivity\e[0m"
    bbCheck "[bright_red]should be BrightRed[/]", "\e[38;5;9mshould be BrightRed\e[0m"
    bbCheck "[BrightRed]should be BrightRed[/]", "\e[38;5;9mshould be BrightRed\e[0m"

  test "style full":
    check "[red]Red[/red]".bb == bb("Red", "red")
    check "[b][yellow]not yellow[/][/b]".bb == bb("[yellow]not yellow[/]", "b")
    check "[9]color 9[/9]".bb == bb("color 9", 9) # syntax will change to [color(9)]

  test "escape":
    check bbEscape("[info] brackets") == "[[info] brackets"
    bbCheck bbEscape("[info] brackets"), "[info] brackets"

  test "fmt":
    let x = 5
    check $bbfmt"[red]{x}" == "\e[38;5;1m5\e[0m"

  test "hex":
    bbCheck "[#FF0000]red", "\e[38;2;255;0;0mred\e[0m"

suite "strutils":
  test "stripAnsi":
    check stripAnsi($bb"[red]red!") == "red!"
    check stripAnsi("\e[1mBold String!") == "Bold String!"

  test "&":
    check "plain string" & bb"[red]red string" == bb"plain string[red]red string"
    check (bb"a [b]bold string") & " and plain string" == bb"a [b]bold string[/] and plain string"

  test "truncate":
    let tester = bb"[red]a red[/] [blue on red]blue on red part"
    check tester.truncate(50) == tester
    check tester.truncate(5) == bb"[red]a red"
    check tester.truncate(10) == bb"[red]a red[/] [blue on red]blue"

  test "align":
    check (bb"[red]red").align(10) == bb"       [red]red"
    check (bb"[red]red").alignLeft(10) == bb"[red]red[/]       "



