import std/[os, strformat]
import hwylterm, hwylterm/hwylcli

putEnv("DEFAULTS-SUB_COUNT", "15")
putEnv("DEFAULTS-SUB_OUTPUTS", ",a,b,c")

hwylCli:
  name "defaults-sub"
  settings InferEnv
  flags:
    [global]
    input:
      T string
      * "testing"
      ? "some help after default"
    outputs:
      T seq[string]
    count:
      T int
      * 5
      ? "some number"
  subcommands:
    [a]
    run:
      assert count == 15
      echo fmt"{input=}, {outputs=}, {count=}"
