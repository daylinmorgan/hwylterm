import std/[strformat]
import hwylterm, hwylterm/hwylcli

type
  Color = enum
    red, blue, green

# TODO: color should be a required flag by default?

hwylCli:
  name "enumFlag"
  flags:
    color:
      T Color
  run:
    echo fmt"{color=}"
    assert args.len == 0
