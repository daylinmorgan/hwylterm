import std/[strformat]
import hwylterm, hwylterm/hwylcli

type
  Color = enum
    red, blue, green

hwylCli:
  name "enumFlag"
  flags:
    color:
      T Color
  run:
    echo fmt"{color=}"
