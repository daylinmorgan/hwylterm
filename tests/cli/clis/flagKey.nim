## Bool flags are the default type — no type annotation needed, just a name and help string.
import hwylterm, hwylterm/hwylcli

hwylCli:
  name "base"
  flags:
    key "a flag named 'key'"
  run:
    if key:
      echo "key set"
    else:
      echo "key not set"
