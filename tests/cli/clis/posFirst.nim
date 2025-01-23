import std/[strformat]
import hwylterm, hwylterm/hwylcli

hwylCli:
  name "positionals"
  args:
    first seq[string]
    second string
    third string
  run:
    echo fmt"{first=}, {second=}, {third=}"
    echo fmt"{args=}"
