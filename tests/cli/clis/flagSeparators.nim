## String flags accept both --flag value and --flag=value — either separator works.
import hwylterm, hwylterm/hwylcli

hwylCli:
  name "flag-separators"
  flags:
    input(string, "flag that expects some input")
  run:
    echo "input = ", input
