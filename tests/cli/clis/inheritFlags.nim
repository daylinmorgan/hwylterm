import std/strformat
import hwylterm, hwylterm/hwylcli

hwylCli:
  name "inherit-flags"
  help:
    styles: newHwylCliStyles(settings = defaultStyleSettings + {FlagGroups})
  flags:
    [global]
    always "in all subcommands"
    [misc]
    misc1 "first misc flag"
    misc2 "second misc flag"
    ["_hidden"]
    other "flag from hidden group"
  subcommands:
    [first]
    ... "command with it's own flag"
    flags:
      # manually defined groups
      first "first first flag":
        group misc
    run:
      echo fmt"{always=},{first=}"

    [second]
    ... "command with 'misc' flags"
    flags:
      ^[misc]
    run:
      echo fmt"{always=},{misc1=},{misc2=}"

    [third]
    ... "command with only 'misc1' flag"
    flags:
      ^misc1
      ^["_hidden"]
    run:
      echo fmt"{always=},{misc1=}"
