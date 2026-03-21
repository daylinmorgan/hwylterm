import std/[os, osproc, strutils]
import ./lib

const
  pathToSrc = currentSourcePath().parentDir()
  fixturePath = pathToSrc / "fixtures"
  svgDir = pathToSrc / "../../public/cli"

createDir(svgDir)

for (kind, suitePath) in walkDir(fixturePath):
  if kind != pcDir: continue
  for f in fixtures(suitePath):
    let suite = f.path.parentDir().splitPath().tail
    let parts = f.name.split("-")
    let svgName = "$1-$2-$3.svg" % [suite, parts[0], parts[1]]
    let svgPath = svgDir / svgName
    let (svg, code) = execCmdEx("ansisvg --colorscheme catppuccin-mocha --fontname 'Source Code Pro' --marginsize 1x1", input = f.output)
    if code != 0:
      echo "error generating svg for ", f.name
      continue
    writeFile(svgPath, svg)
    echo svgPath
