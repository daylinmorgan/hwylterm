import std/strformat
import hwylterm/hwylcli

type
  Color = enum
    red, blue, green

hwylCli:
  name "example"
  V "0.1.0"
  ... "a description of hwylterm"
  flags:
    yes:
      T bool
      ? "set flag to yes"
    [global]
    config:
      T seq[string]
      ? "path to config file"
      * @["config.yml"]
  run:
    echo "this is always run prior to subcommand parsing"
    echo fmt"{yes=}, {config=}"
  subcommands:
    --- one
    ... "the first subcommand"
    flags:
      color:
        T Color
        ? "a color (red, green, blue)"
      verbose:
        T Count
        ? "a count flag"
        - v
    run:
      echo "hello from `example one` command!"
      echo fmt"{color=}"
      echo fmt"{verbose=}"

    --- two
    ... """
    some second subcommand

    a longer mulitline description that will be visible in the subcommand help
    it will automatically be "bb"'ed [bold]this is bold text[/]
    """
    flags:
      aflag:
        T bool
        ? "some help"
      bflag:
        T seq[float]
        ? "multiple floats"
      c:
        ? "this should be a single flag"
      h "overwrite the short h from help"
    run:
      echo "hello from `example b` command"
      echo fmt"{aflag=}, {bflag=}"


