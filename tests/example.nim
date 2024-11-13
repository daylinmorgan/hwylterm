import std/[strformat, strutils]
import hwylterm, hwylterm/hwylcli


type
  Color = enum
    red, blue, green


hwylCli:
  name "example"
  V "0.1.0"
  ... "a description of hwylterm"
  flags:
    [global]
    yes:
      T bool
      ? "set flag to yes"
    [shared]
    something:
      ? "some flag only needed in one subcommand"
    config:
      T seq[string]
      ? "path to config file"
      * @["config.yml"]
  preSub:
    echo "this is run after subcommand parsing but before its run block"
  run:
    echo "this is always run prior to subcommand parsing"
  subcommands:
    [onelonger]
    ... """
    the first subcommand

    this command features both an enum flag and a Count flag
    it also inherits the `[[shared]` flag group
    """

    alias o,"one", `one-l`
    flags:
      color:
        T Color
        ? "a color (red, green, blue)"
      verbose:
        T Count
        ? "a count flag"
        - v
      ^[shared]
    subcommands:
      [subsub]
      ... "another level down subcommand"
      flags:
        ^color
      run:
        echo fmt"{color=}"
        
    run:
      echo "hello from `example one` command!"
      echo args
      echo fmt"{color=}"
      echo fmt"{verbose=}"
      echo fmt"{config=}"

    ["two-longer"]
    ... """
    some second subcommand

    a longer mulitline description that will be visible in the subcommand help
    and it will automatically be "bb"'ed [bold]this is bold text[/]
    """
    flags:
      ^something
      auto:
        - a
        ? "some help"
      b:
        T seq[float]
        ? "multiple floats"
      h "this will override the builtin 'h' for help"
    run:
      echo "hello from `example b` command"
      echo fmt"{auto=}, {b=}"

