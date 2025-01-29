import std/strformat
import hwylterm, hwylterm/hwylcli

const noExtras = HwylCliStyles(settings: {})

hwylCli:
  name "help-switches"
  help:
    styles: noExtras
  subcommands:
    [required]
    alias r
    help:
      styles: noExtras
    flags:
      input:
        T string
        ? "required input"
        S Required
      k:
        T string
        ? "predefined flag"
        * "value"
    run:
      echo fmt"{input=},{k=}"
