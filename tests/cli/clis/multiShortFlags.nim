import hwylterm, hwylterm/hwylcli

hwylCli:
  name "multiple-short-flags"
  flags:
    a "first short"
    b "second short"
  run:
    echo a, b
