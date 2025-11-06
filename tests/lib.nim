import std/[os, strutils, unittest]
import hwylterm/bbansi {.all.}
export bbansi

const pathToSrc* = currentSourcePath().parentDir()
const fixturePath* = pathToSrc / "fixtures"

proc fixTest*(name: string, s: BbString) =
  let
    path = fixturePath / name
    outpath = path & ".output"
  when defined(fixtureWrite):
    createDir(path.splitFile.dir)
    writeFile(path & ".markup", s.toString(Markup))
    writeFile(outpath, s.toString(On))
  else:
    check fileExists(outpath)
    check $(s) == readFile(path & ".output").replace("\r\n", "\n")

when isMainModule:
  fixTest("simple", bb"[red]red text")

