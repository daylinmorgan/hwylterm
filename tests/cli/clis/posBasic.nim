import std/[strformat]
import hwylterm, hwylterm/hwylcli

hwylCli:
  name "posLast"
  positionals:
    args seq[string]
  run:
    echo fmt"{args=}"
