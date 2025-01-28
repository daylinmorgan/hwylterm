import std/[strformat]
import hwylterm, hwylterm/hwylcli

hwylCli:
  name "posLast"
  positionals:
    first:
      T string
      ident notFirst
    rest seq[string]
  run:
    echo fmt"{notFirst=} {rest=}"
