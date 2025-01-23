import std/[strformat]
import hwylterm, hwylterm/hwylcli

hwylCli:
  name "positionals"
  settings: ExactArgs
  args:
    first int
    second string
    third string
  run:
    echo fmt"{first=}, {second=}, {third=}"
    assert args.len == 0
