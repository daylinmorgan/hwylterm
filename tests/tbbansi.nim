import std/[strutils,unittest]

import hwylterm/bbansi

template bbCheck(input: string, output: string): untyped =
  check escape($bb(input)) == escape(output)

suite "basic":
  test "simple":
    bbCheck "[red]red text", "\e[31mred text\e[0m"
    bbCheck "[red]Red Text", "\e[31mRed Text\e[0m"
    bbCheck "[yellow]Yellow Text", "\e[33mYellow Text\e[0m"
    bbCheck "[bold red]Bold Red Text", "\e[1;31mBold Red Text\e[0m"
    bbCheck "[red]5[/]", "\e[31m5\e[0m"
    bbCheck "[bold][red]5","\e[1;31m5\e[0m"

  test "closing":
    bbCheck "[bold]Bold[red] Bold Red[/red] Bold Only",
      "\e[1mBold\e[0m\e[1;31m Bold Red\e[0m\e[1m Bold Only\e[0m"

  test "abbreviated":
    bbCheck "[b]Bold[/] Not Bold", "\e[1mBold\e[0m Not Bold"

  test "noop":
    bbCheck "No Style", "No Style"
    bbCheck "[unknown]Unknown Style", "Unknown Style"

  test "escaped":
    bbCheck "[[red] ignored pattern", "[red] ignored pattern"

  test "newlines":
    bbCheck "[red]Red Text[/]\nNext Line", "\e[31mRed Text\e[0m\nNext Line"

  test "on color":
    bbCheck "[red on yellow]Red on Yellow", "\e[31;43mRed on Yellow\e[0m"

  test "concat-ops":
    check "[red]RED[/]".bb & " plain string" == "[red]RED[/] plain string".bb
    check "[red]RED[/]".bb.len == 3
    check bb("[blue]Blue[/]") & " " & bb("[red]Red[/]") ==
        "[blue]Blue[/] [red]Red[/]".bb
    check "a plain string" & "[blue] a blue string".bb ==
        "a plain string[blue] a blue string".bb

  test "case":
    bbCheck "[red]no case sensitivity[/RED]", "\e[31mno case sensitivity\e[0m"

  test "style full":
    check "[red]Red[/red]".bb == bb("Red", "red")
    check "[b][yellow]not yellow[/][/b]".bb == bb("[yellow]not yellow[/]", "b")

