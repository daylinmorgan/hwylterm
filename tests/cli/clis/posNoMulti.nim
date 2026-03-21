## Positionals with non-seq types accept exactly one value each and support type coercion.
import std/[strformat]
import hwylterm, hwylterm/hwylcli

hwylCli:
  name "positionals"
  positionals:
    first int
    second string
    third string
  run:
    echo fmt"{first=}, {second=}, {third=}"
