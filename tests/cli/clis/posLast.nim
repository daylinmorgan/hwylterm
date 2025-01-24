import std/[strformat]
import hwylterm, hwylterm/hwylcli

hwylCli:
  name "posLast"
  positionals:
    first string
    second string
    third seq[string]
  run:
    echo fmt"{first=}, {second=}, {third=}"
