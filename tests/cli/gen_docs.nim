import std/[os, strutils, algorithm, tables, sequtils]
import ./lib

const
  pathToSrc = currentSourcePath().parentDir()
  fixturePath = pathToSrc / "fixtures"
  clisPath = pathToSrc / "clis"
  outPath = pathToSrc / "../../docs/cli-examples.md"

proc docComment(src: string): string =
  ## return first encountered doc comment
  for line in src.splitLines():
    if line.startsWith("## "):
      return line[3..^1]

var byModule = initOrderedTable[string, seq[Fixture]]()
for (kind, suitePath) in walkDir(fixturePath):
  if kind != pcDir: continue
  for f in fixtures(suitePath):
    byModule.mgetOrPut(f.module, @[]).add f

var modules = toSeq(byModule.keys)
modules.sort()

var doc = "# hwylterm CLI Examples\n\n"

doc.add "| CLI | Description |\n"
doc.add "|-----|-------------|\n"
for module in modules:
  let src = readFile(clisPath / module & ".nim")
  doc.add "| [$1](#$2) | $3 |\n" % [module, module.toLower(), src.docComment()]
doc.add "\n"

for module in modules:
  let src = readFile(clisPath / module & ".nim")
  doc.add "## $1\n\n" % module
  doc.add "```nim\n$1\n```\n\n" % src.strip()
  let fixtureList = byModule[module].sortedByIt(it.path)
  for i, f in fixtureList:
    let status = if f.ok: "ok" else: "error"
    doc.add "**Case $1** ($2)\n\n" % [$(i + 1), status]
    let suite = f.path.parentDir().splitPath().tail
    let parts = f.name.split("-")
    let svgPath = "cli/$1-$2-$3.svg" % [suite, parts[0], parts[1]]
    doc.add "```cmd\n$1 $2\n```\n\n.. image:: $3\n\n" % [f.module, f.args, svgPath]

writeFile(outPath, doc)
echo "wrote ", outPath
