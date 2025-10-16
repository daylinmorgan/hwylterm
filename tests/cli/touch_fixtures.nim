import std/[os, strutils]
import hwylterm
import ./lib

const pathToSrc = currentSourcePath().parentDir()
const fixturePath = pathToSrc / "fixtures"
const binDir = pathToSrc / "bin"

proc touchFixture(path: string) =
  let f = loadFixture(path)
  preCompileWorkingModule(f.module)
  echo f.module & " | " & f.args
  let (output, code) = run(f)
  # code should be the same ....
  let (markup, _) = run(f, markup = true)
  if f.ok:
    if code != 0: quit "expected zero exit status"
  else:
    if code == 0: quit "expected non-zero exit status"
  writeFile(path.replace(".args", ".markup"), markup)
  writeFile(path.replace(".args", ".output"), output)

proc touchSuite(suitePath: string) =
  echo "updating suite: ", suitePath.splitPath.tail
  for (kind, path) in walkDir(suitePath, checkDir = true):
    if path.endsWith(".args"):
      touchFixture(path)

when isMainModule:
  import hwylterm/parseopt3

  proc writeHelp() =
    echo """

touch_fixtures
  --help          show this help
  --suite [name]
  --fixture [fixture]
"""
    quit(0)

  var suites: seq[string]
  var fixtures: seq[string]

  for kind, key, val in getopt():
    case kind
    of cmdArgument, cmdEnd, cmdError: assert(false)
    of cmdLongOption, cmdShortOption:
      case key
      of "help", "h": writeHelp()
      of "suite": suites.add val
      of "fixture": fixtures.add val

  if (suites.len + fixtures.len) == 0:
    for (kind, path) in walkDir(fixturePath):
      if kind == pcDir:
        touchSuite(path)

  for suite in suites:
    touchSuite(pathToSrc / suite)

  for fixture in fixtures:
    touchFixture(pathToSrc / fixture)
