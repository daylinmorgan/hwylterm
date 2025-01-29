import std/strformat
import hwylterm, hwylterm/hwylcli

hwylCli:
  name "inherit-flags"
  flags:
    [global]
    always "in all subcommands"
    [misc]
    misc1 "first misc flag"
    misc2 "second misc flag"
  subcommands:
    [first]
    ... "command with it's own flag"
    flags:
      first "first first flag"
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
    run:
      echo fmt"{always=},{misc1=}"
