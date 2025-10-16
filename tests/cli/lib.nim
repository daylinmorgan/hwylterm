import std/[os, osproc, strutils, times, unittest, terminal, strtabs]

const pathToSrc = currentSourcePath().parentDir()
const binDir = pathToSrc / "bin"
const hwylCliSrc = pathToSrc / "../../src/hwylterm/hwylcli.nim"

let hwylCliWriteTime =  getFileInfo(hwylCliSrc).lastWriteTime

if not dirExists(binDir):
  createDir(binDir)

# poor man's progress meter
proc status(s: string) =
  eraseLine stdout
  stdout.write(s.alignLeft(terminalWidth()).substr(0, terminalWidth()-1))
  flushFile stdout

proc preCompileWorkingModule*(module: string) =
  let exe = binDir / module
  let srcModule = pathToSrc / "clis" / (module & ".nim")
  if not exe.fileExists or getFileInfo(exe).lastWriteTime < max(getFileInfo(srcModule).lastWriteTime, hwylCliWriteTime) or defined(forceSetup):
    let cmd = "nim c -o:$1 $2" % [exe, srcModule]
    let (output, code) = execCmdEx(cmd)
    if code != 0:
      echo "cmd: ", cmd
      quit "failed to precompile test module:\n" & output

proc preCompileTestModules*() =
  var modules: seq[string]
  for srcModule in walkDirRec(pathToSrc / "clis"):
    if srcModule.endsWith(".nim"):
      modules.add srcModule.splitFile().name

  for i, module in modules:
    status "compiling [$2/$3] $1" % [ module, $(i+1), $modules.len]
    preCompileWorkingModule(module)

  eraseLine stdout

type
  Fixture* = object
    name*: string
    module*: string
    args*: string
    ok*: bool
    output*: string

proc loadFixture*(path: string): Fixture =
  let name = path.splitPath.tail.replace(".args", "")
  let parts = name.split("-")
  assert parts.len == 3
  result.name = name
  result.module = parts[0]
  result.ok = parts[2] == "ok"
  result.args = readFile(path).strip()

proc loadFixtureWithOutput(path: string): Fixture =
  result = loadFixture(path)
  result.output = readFile(path.replace(".args",".output")).strip()


iterator fixtures*(fixturePath: string): Fixture =
  for (kind, path) in walkDir(fixturePath):
    if kind != pcFile: continue
    if path.endsWith(".args"):
      yield loadFixtureWithOutput(path)

proc run*(f: Fixture, markup= false): (string, int) =
  preCompileWorkingModule(f.module)
  let cmd = binDir / f.module & " " & f.args
  let key = if markup: "HWYLTERM_FORCE_MARKUP" else: "HWYLTERM_FORCE_COLOR"
  let (output, code) = execCmdEx(cmd, env = newStringTable({key: "1"}))
  result = (output.strip(), code)

template test*(f: Fixture) =
  let normalizedOutput = f.output.strip().strip(leading = false, chars = {'\n'}).dedent()
  test (f.module & "|" & f.args):
    let (actualOutput, code) = run(f)
    check code == (if f.ok: 0 else: 1)
    check normalizedOutput == actualOutput


