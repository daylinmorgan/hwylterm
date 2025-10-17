import std/[strformat, os]
import hwylterm, hwylterm/hwylcli

putEnv("INFERENV_INPUT", "TEST")
putEnv("INFERENV_COUNT", "5")

hwylCli:
  name "inferEnv"
  settings InferEnv
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
    shell:
      S NoEnv
      T string
      * "guess"
  run:
    echo fmt"{input=}, {count=}, {shell=}"
    discard
