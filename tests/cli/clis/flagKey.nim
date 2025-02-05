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
