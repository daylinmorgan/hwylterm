##[
  # Cli
]##

import std/[strutils]
import ./bbansi

type
  HwylFlag = tuple
    short, long, description = ""
  HwylCliStyles* = object
    hdr = "b cyan"
    shortFlag = "yellow"
    longFlag = "magenta"
    descFlag = ""
  HwylCli* = object
    cmd*: string
    usage*: string
    flags*: seq[HwylFlag]
    styles*: HwylCliStyles
    shortArgLen, longArgLen, descArgLen: int


func newHwylCli*(
  cmd = "",
  usage = "",
  flags: openArray[HwylFlag] = @[],
  styles = HwylCliStyles()
): HwylCli =
  result.cmd = cmd
  result.usage = usage
  result.flags = @flags
  result.styles = styles
  for f in flags:
    result.shortArgLen = max(result.shortArgLen, f.short.len)
    result.longArgLen  = max(result.longArgLen, f.long.len)
    result.descArgLen  = max(result.descArgLen, f.description.len)


func flagHelp(cli: HwylCli, f: HwylFlag): string =
  result.add "  "
  if f.short != "":
    result.add "[" & cli.styles.shortFlag & "]"
    result.add "-" & f.short.alignLeft(cli.shortArgLen)
    result.add "[/]"
  else:
    result.add " ".repeat(1 + cli.shortArgLen)

  result.add " "
  if f.long != "":
    result.add "[" & cli.styles.longFlag & "]"
    result.add "--" & f.long.alignLeft(cli.longArgLen)
    result.add "[/]"
  else:
    result.add " ".repeat(2 + cli.longArgLen)

  result.add " "
  if f.description != "":
    result.add "[" & cli.styles.descFlag & "]"
    result.add f.description
    result.add "[/]"
  result.add "\n"

proc bbImpl(cli: HwylCli): string =
  if cli.cmd != "":
    result.add cli.cmd
    result.add "\n"
  if cli.usage != "":
    result.add "\n"
    result.add "[" & cli.styles.hdr & "]"
    result.add "usage[/]:\n"
    result.add indent(cli.usage, 2 )
    result.add "\n"
  if cli.flags.len > 0:
    result.add "\n"
    result.add "[" & cli.styles.hdr & "]"
    result.add "flags[/]:\n"
    for f in cli.flags:
      result.add flagHelp(cli,f)

proc bb*(cli: HwylCli): BbString = 
  result = bb(bbImpl(cli))

proc `$`*(cli: HwylCli): string =
  result = $bb(cli)
