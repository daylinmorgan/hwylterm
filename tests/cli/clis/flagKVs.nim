## Key=value pair flags let you accept structured input like --flag key=value in a single argument.
import hwylterm, hwylterm/hwylcli


type Inputs = KVString

type
  Person = object
    name: string
    age: int
    weight: float = 150.5


proc `$`(_:typedesc[seq[KVString]]): string =
  "k(str):v(str)..."

hwylCli:
  name "flagKVs"
  flags:
    inputs(seq[Inputs], "version with type alias")
    counts(KV[string, int], "key value, custom types")
    builtins(seq[KVstring], "one using provided type")
    person(Person, "a person")
  run:
    echo counts.key,":", counts.val
    for (k, v) in inputs:
      echo k, ":", v
    for item in builtins:
      echo item
    echo person
