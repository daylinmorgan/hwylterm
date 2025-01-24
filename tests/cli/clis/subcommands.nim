import std/[strformat]
import hwylterm, hwylterm/hwylcli

hwylCli:
  name "subcommands"
  subcommands:
    [a]
    ... "a subcommand with positionals"
    positionals:
      input string
      outputs seq[string]
    run:
      echo fmt"{input=} {outputs=}"
    [b]
    ... "a subcommand with flags"
    flags:
      input:
        T string
        * "testing"
        ? "some help after default"
      outputs:
        T seq[string]
    run:
      echo fmt"{input=} {outputs=}"
