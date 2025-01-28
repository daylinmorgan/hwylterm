import std/strformat
import hwylterm, hwylterm/hwylcli

hwylCli:
  name "inferred short flags"
  settings InferShort
  flags:
    input:
      T string
      ? "the input var"
    output:
      T string
      ? "the output var"
    count:
      T int
      ? "a number"
      - n
    nancy:
      ? "needed a flag that starts with n :)"
    ignore:
      S NoShort
      ? "a flag to not infer"
  run:
    echo fmt"{input=}, {output=}, {count=}, {nancy=}, {ignore=}"

