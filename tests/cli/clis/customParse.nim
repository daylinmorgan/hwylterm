## customize parsing of typical types and with distinct types
import std/[os, paths, strformat]
import hwylterm, hwylterm/hwylcli

type
  Input = distinct string
  Data = object
    nums: seq[int]
    names: seq[string]

proc `$`(v: Input): string {.borrow.}
proc parse(p: OptParser, target: var Input) =
  checkVal p
  if not p.val.fileExists:
    hecho "warning input file does not exist: " & p.val
  target = Input(p.val)

proc parse(p: OptParser, target: var Path) =
  checkVal p
  target = Path(p.val)

proc fieldNames(o: object): seq[string] =
  for k, _ in o.fieldPairs: result.add k

proc parse(p: var OptParser, target: var object) =
  let key = extractKey(p)
  if key notin target.fieldNames:
    hecho "ignoring unknown key: " & key
    return
  for name, field in target.fieldPairs:
    if name == key:
      parse(p, field)
      return

hwylCli:
  name "customParse"
  flags:
    input(Input, "some input")
    output(Path, "some output")
    data(Data, "data")
  run:
    echo fmt"{input=},{output=}"
    echo data
