import std/[os, unittest, strutils]
import ./lib

if commandLineParams().len == 0:
  preCompileTestModules()

const pathToSrc = currentSourcePath().parentDir()
const fixturePath = pathToSrc / "fixtures"

for (kind,path) in walkDir(fixturePath):
  if kind == pcDir:
    suite "fixtures-" & path.splitPath.tail:
      for fixture in fixtures(path):
        test fixture

