import std/[strformat]
import hwylterm, hwylterm/hwylcli

hwylCli:
  name "positionals"
  positionals:
    first seq[string]
    second string
    third string
  run:
    echo fmt"{first=}, {second=}, {third=}"
