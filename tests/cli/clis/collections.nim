## Various collection types (seq/sets) allow for repeated flags or delimited values

import std/strformat
import hwylterm, hwylterm/hwylcli

type
  Mode = enum
    fun, sad, angry, sleepy

hwylCli:
  name "collects"
  flags:
    inputs(seq[string], "sequence of inputs")
    modes(set[Mode], "set of modes")
    modes2(toHashSet([fun]), HashSet[Mode], "hashset of modes")
    outputs(seq[KVstring], "sequence of key/value pairs")
  run:
    echo fmt"{inputs=},{modes=},{modes2=},{outputs=}"
