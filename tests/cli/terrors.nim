import std/[os, unittest, strutils, sugar]
import ./lib

template testFailingModule(name: string) =
  let output = compileFailingModule(name).strip()
  let expectedEnd = readFile(pathToSrc / "errors" / "alias.error").strip()
  check output.endsWith(expectedEnd)

let modules = collect:
  for (kind, path) in walkDir(pathToSrc / "errors"):
    let (dir, name, ext) = path.splitFile
    if kind == pcFile and ext == ".nim":
      name

suite "errors":
  for name in modules:
    test name:
      testFailingModule(name)
