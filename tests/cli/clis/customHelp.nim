import std/[strutils,strformat, sequtils]
import hwylterm, hwylterm/hwylcli


# TODO: actually implement this in bbansi
func stripMarkup*(s: string): string =
  result = bb(s).plain

func render*(cli: HwylCliHelp, f: HwylFlagHelp): string =
  result.add "  "
  if f.short != "":
    result.add "[" & cli.styles.flagShort & "]"
    result.add "-" & f.short.alignLeft(cli.lengths.shortArg)
    result.add "[/" & cli.styles.flagShort & "]"
  else:
    result.add " ".repeat(1 + cli.lengths.shortArg)
  result.add " "

  let indentSize = stripMarkup(result).len
  if f.long != "":
    result.add "[" & cli.styles.flagLong & "]"
    result.add "--" & f.long.alignLeft(cli.lengths.longArg)
    result.add "[/" & cli.styles.flagLong & "]"
  else:
    result.add " ".repeat(2 + cli.lengths.longArg)

  result.add "\n"
  result.add " ".repeat(indentSize + 4)
  if f.description != "":
    result.add "[" & cli.styles.flagDesc & "]"
    result.add f.description
    result.add "[/" & cli.styles.flagDesc & "]"
    if f.defaultVal != "":
      result.add " "
      result.add "[" & cli.styles.default & "]"
      result.add "(" & f.defaultVal & ")"
      result.add "[/" & cli.styles.default & "]"

hwylCli:
  name "custom-help"
  defaultFlagType string
  flags:
    input:
      ? "input"
      * "input.txt"
    output:
      ? "output"
      * "output.txt"
  run:
    echo fmt"{input=},  {output=}"
