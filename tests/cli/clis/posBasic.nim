## Positional arguments can bind to a different variable name in the run block via ident.
import std/[strformat]
import hwylterm, hwylterm/hwylcli

hwylCli:
  name "posBasic"
  positionals:
    input:
      T string
      ? "the \"input\""
      ident i
  run:
    echo fmt"input={i}"
