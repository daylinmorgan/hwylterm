import hwylterm, hwylterm/hwylcli

hwylCli:
  name "flag-separators"
  flags:
    input(string, "flag that expects some input")
  run:
    echo "input = ", input
