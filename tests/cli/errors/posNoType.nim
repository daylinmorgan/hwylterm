## Positional arguments must have a defined type block
import hwylterm, hwylterm/hwylcli

hwylCli:
  name "posNoType"
  positionals:
    input:
      ? "the \"input\""
  run:
    echo input
