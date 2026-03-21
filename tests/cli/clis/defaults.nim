## Flags can carry default values of any supported type, shown in help output automatically.
import std/[strformat]
import hwylterm, hwylterm/hwylcli

hwylCli:
  name "default-values"
  flags:
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
  run:
    echo fmt"{input=} {outputs=}, {count=}"
