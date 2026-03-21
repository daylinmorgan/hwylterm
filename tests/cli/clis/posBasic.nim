## Positional arguments can bind to a different variable name in the run block via ident.
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
