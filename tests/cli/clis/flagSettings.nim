import hwylterm, hwylterm/hwylcli

hwylCli:
  name "flag-settings"
  flags:
    input:
      S HideDefault
      T string
      * "a secret default"
      ? "flag with default hidden"
    count:
      T Count
      * Count(val: 0)
      ? "a count var with default"
  run:
    discard
