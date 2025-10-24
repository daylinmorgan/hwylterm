import std/[os, strutils]
import hwylterm
import ./lib

const pathToSrc = currentSourcePath().parentDir()
const fixturePath = pathToSrc / "fixtures"
const binDir = pathToSrc / "bin"

proc touchFixture(f: Fixture) =
  preCompileWorkingModule(f.module)
  echo f.module & " | " & f.args
  let (output, code) = run(f)
  # code should be the same ....
  let (markup, _) = run(f, markup = true)
  if f.ok:
    if code != 0:
      echo output
      quit "expected zero exit status"
  else:
    if code == 0: quit "expected non-zero exit status"
  writeFile(f.markupPath, markup)
  writeFile(f.outputPath, output)

proc findFixtures(path: string): seq[Fixture] =
  for (kind, path) in walkDir(path, checkDir = true):
    if kind == pcFile and path.endsWith(".args"):
      result.add loadFixture(path)

proc touchSuite(suitePath: string) =
  echo "updating suite: ", suitePath.splitPath.tail
  for f in findFixtures(suitePath):
    touchFixture(f)

proc findSuites(path: string): seq[string] =
  for (kind, path) in walkDir(path):
    if kind == pcDir:
      result.add path

proc findMissing(path: string): seq[Fixture] =
  for s in findSuites(path):
    for f in findFixtures(s):
      if f.isMissing():
        result.add f

when isMainModule:
  import hwylterm/parseopt3

  proc writeHelp() =
    echo """

touch_fixtures
  --help          show this help
  --missing
  --suite [name]
  --fixture [fixture]
  --all
"""
    quit(0)

  var fixtures: seq[Fixture]
  var all: bool

  for kind, key, val in getopt():
    case kind
    of cmdArgument, cmdEnd, cmdError: assert(false)
    of cmdLongOption, cmdShortOption:
      case key
      of "help", "h": writeHelp()
      of "suite":
        fixtures.add findFixtures(val)
      of "fixture":
        fixtures.add loadFixture(val)
      of "missing":
        fixtures.add findMissing(fixturePath)
      of "all": all = true

  if all:
    for (kind, path) in walkDir(fixturePath):
      if kind == pcDir:
        touchSuite(path)

  for fixture in fixtures:
    touchFixture(fixture)
