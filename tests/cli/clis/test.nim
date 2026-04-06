## The simplest possible hwylCli program — just a name and a run block.
import hwylterm, hwylterm/hwylcli


hwylCli:
  
  name "base"
  run:
    echo "a base cli"
    hwylCliError("AHY")
