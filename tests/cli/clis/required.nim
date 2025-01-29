import std/strformat
import hwylterm, hwylterm/hwylcli


hwylCli:
  name "required-flag"
  flags:
    input:
      S Required
      T string
      ? "a required flag!"
  run:
    echo fmt"{input=}"
