import std/strformat
import hwylterm/hwylcli


hwylCLi:
  name "gen only"
  settings GenerateOnly
  positionals:
    args seq[string]
  run:
    echo fmt"this doesn't run, unless the user says so {args=}"


echo "some code that runs first"

printGenOnlyHelp()

# inherit commandLineArgs
runGenOnly()
assert args == @["a", "b", "c"]
args = @[]
# custom args
runGenOnly(@["1","2","3"])
assert args == @["1", "2", "3"]


