## Marking a flag Required causes the CLI to exit with an error if it is not provided.
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
