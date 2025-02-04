import std/[compilesettings, os, osproc, strutils, times, unittest, terminal]

const pathToSrc = currentSourcePath().parentDir()
const binDir = pathToSrc / "bin"
const hwylCliSrc = pathToSrc / "../../src/hwylterm/hwylcli.nim"
let hwylCliWriteTime =  getFileInfo(hwylCliSrc).lastWriteTime

if not dirExists(binDir):
  createDir(binDir)

proc runTestCli(module: string, args: string, code: int = 0): (string, int) =
  let cmd = binDir / module & " " & args
  let (output, code) = execCmdEx(cmd)
  result = (output.strip(), code)

# poor man's progress meter
proc status(s: string) =
  eraseLine stdout
  stdout.write(s.alignLeft(terminalWidth()).substr(0, terminalWidth()-1))
  flushFile stdout

proc preCompileWorkingModule(module: string) =
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

template okWithArgs*(module: string, args = "", output = "") =
  preCompileWorkingModule(module)
  let normalizedOutput = output.strip().strip(leading = false, chars = {'\n'}).dedent()
  test (module & "|" & args):
    let (actualOutput, code) = runTestCli(module, args)
    check code == 0
    check normalizedOutput == actualOutput

template failWithArgs*(module: string, args = "", output = "") =
  preCompileWorkingModule(module)
  let normalizedOutput = output.strip().strip(leading = false, chars = {'\n'}).dedent()
  test (module & "|" & args):
    let (actualOutput, code) = runTestCli(module, args)
    check code == 1
    check normalizedOutput == actualOutput
