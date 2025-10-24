import hwylterm, hwylterm/hwylcli


type Inputs = KVString

proc `$`(_:typedesc[seq[KVString]]): string =
  "k(str):v(str)..."

hwylCli:
  name "flagKVs"
  flags:
    inputs(seq[Inputs], "version with type alias")
    counts(KV[string, int], "key value, custom types")
    builtins(seq[KVstring], "one using provided type")
  run:
    echo counts.key,":", counts.val
    for (k, v) in inputs:
      echo k, ":", v
    for item in builtins:
      echo item
