import hwylterm, hwylterm/hwylcli

hwylCli:
  name "setting-propagate"
  settings InferShort, LongHelp
  flags:
    [misc]
    input:
      T string
      * "the default"
      ? "input flag"
    count:
      T Count
      * Count(val: 0)
      ? "a count var with default"
  subcommands:
    [one]
    settings IgnoreParent
    flags:
      ^[misc]

    [two]
    settings HideDefault
    flags:
      ^[misc]


