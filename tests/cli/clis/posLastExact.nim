import std/[strformat]
import hwylterm, hwylterm/hwylcli

hwylCli:
  name "posLast"
  settings: ExactArgs
  args:
    first string
    second string
    third seq[string]
  run:
    echo fmt"{first=}, {second=}, {third=}"
    assert args.len == 0
