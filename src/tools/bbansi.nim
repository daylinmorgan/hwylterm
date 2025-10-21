##[
  ## bbansi

  use BB style markup to add color to strings using VT100 escape codes
]##

import std/[
  os, sequtils, strformat, strutils
]
import ../hwylterm, ../hwylterm/hwylcli

proc debugBb(bbs: BbString): string {.used.} =
    echo "bbString("
    echo "  plain: ", bbs.plain
    echo "  spans: ", bbs.spans
    echo "  escaped: ", escape($bbs)
    echo ")"

when isMainModule:
  const version = staticExec "git describe --tags --always --dirty=-dev"

  proc showTestCard() =
    for style in [
      "bold", "faint", "italic", "underline", "blink", "reverse", "conceal", "strike"
    ]:
      echo style, " -> ", fmt"[{style}]****".bb
    const colors =
      ["black", "red", "green", "yellow", "blue", "magenta", "cyan", "white"]
    for color in colors:
      echo color, " -> ", fmt"[{color}]****".bb
    for color in colors:
      echo "on ", color, " -> ", fmt"[on {color}]****".bb
    quit(QuitSuccess)

  hwylCli:
    name "bbansi"
    settings ShowHelp
    positionals:
      args seq[string]
    help:
      description """
    bbansi "[[yellow] yellow text!"
      -> [yellow] yellow text![/]
    bbansi "[[bold red] bold red text[[/] plain text..."
      -> [bold red] bold red text[/] plain text...
    bbansi "[[red]some red[[/red] but all italic" --style:italic
      -> [italic][red]some red[/red] but all italic[/italic]
    """
    version bbfmt"[yellow]bbansi version[/][red] ->[/] [bold]{version}[/]"
    hidden debug, testCard, inferShort
    flags:
      debug "show debug"
      testCard "show test card":
        S NoShort
      style(string, "set style for string")
      file(string, "file path")
    run:
      if testCard: showTestCard()
      if file != "": echo readFile(file).bb()
      else:
        for arg in args:
          let styled = arg.bb(style)
          echo styled
          if debug:
            echo debugBb(styled)
