import hwylterm, hwylterm/hwylcli

hwylCli:
  name "setting-hide-default"
  settings HideDefault
  flags:
    input:
      T string
      * "a secret default"
      ? "flag with default hidden"
    count:
      T Count
      * Count(val: 0)
      ? "a count var with default"
  run:
    discard
