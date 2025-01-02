import std/[strformat, strutils]
import hwylterm, hwylterm/hwylcli

# TODO: break this up into a bunch of integration tests

type
  Color = enum
    red, blue, green

hwylCli:
  name "example"
  V "0.1.0"
  flags:
    [global]
    color:
      T Color
      ? "a color (red, green, blue)"
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
    echo "this is run after subcommand parsing but before final run block"
    echo fmt"{yes=}, {color=}"
  run:
    echo "this is always run prior to subcommand parsing"
    echo fmt"{yes=}, {color=}"
  subcommands:
    [one]
    help:
      description """
    the first subcommand

    this command features both an enum flag and a Count flag
    it also inherits the `[[shared]` flag group
    """

    alias o
    flags:
      verbose:
        T Count
        ? "a count flag"
        - v
      ^[shared]
    subcommands:
      [subsub]
      ... "another level down subcommand"
      flags:
        ^config
      run:
        echo "hello from `example one subsub` command"
        echo fmt"{color=}"

    run:
      echo "hello from `example one` command!"
      echo args
      echo fmt"{color=}"
      echo fmt"{verbose=}"
      echo fmt"{config=}"

    [two]
    ... """
    some second subcommand

    a longer mulitline description that will be visible in the subcommand help
    and it will automatically be "bb"'ed [bold]this is bold text[/]
    """
    # args first, second
    # or
    args:
      # default type is string
      # only one 'arg' can be the seq[string]
      # order matters here
      # by default string
      inputs:
        T int
      second seq[string]
    flags:
      ^something
      thing:
        T seq[KV[string, Color]]
        ? "some key value colors"
      b:
        T seq[float]
        ? "multiple floats"
      def:
        T string
        ? "a flag with a string default"
        * "the value"
    run:
      echo "hello from `example b` command"
      echo fmt"{thing=}, {b=}, {def=}"

