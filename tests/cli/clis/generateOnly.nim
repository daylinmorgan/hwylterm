import std/[os, strformat]
import hwylterm/hwylcli


hwylCLi:
  name "gen only"
  settings GenerateOnly, ShowHelp
  subcommands:
    [one]
    positionals:
      args seq[string]
    run:
      assert args == @["a", "b", "c"]
      echo fmt"{args=}"
 
    [two]
    flags:
      input(string, "someinput")
    run:
      echo "running subcmd 2"
      echo fmt"{input=}"

echo "some code that runs first"

printGenOnlyHelp()
if paramCount() == 0:
  let args = parseCmdLine("two --input test")
  runGenOnly(args)
else:
  # use from parseCommandLine
  runGenOnly()

