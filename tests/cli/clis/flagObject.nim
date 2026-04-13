## Flags can be objects ,including with their own collection types (seq, set, etc.)

import hwylterm, hwylterm/hwylcli

type
  Person = object
    name: string
    age: int
    weight: float = 150.5
    roles: seq[string]

hwylCli:
  name "flagObject"
  flags:
    person(Person, "a person")
  run:
    echo person
