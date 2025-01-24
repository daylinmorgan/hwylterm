import std/[compilesettings, os, osproc, strutils, times, unittest]

const pathToSrc = querySetting(SingleValueSetting.projectPath)
const binDir = pathToSrc / "bin"
const hwylCliSrc = pathToSrc / "../../src/hwylterm/hwylcli.nim"
let hwylCliWriteTime =  getFileInfo(hwylCliSrc).lastWriteTime

if not dirExists(binDir):
  createDir(binDir)

proc runTestCli(module: string, args: string, code: int = 0): (string, int) =
  let cmd = binDir / module & " " & args
  let (output, code) = execCmdEx(cmd)
  result = (output.strip(), code)

proc preCompileWorkingModule(module: string) =
  let exe = binDir / module
  let srcModule = pathToSrc / "clis" / (module & ".nim")
  if not exe.fileExists or getFileInfo(exe).lastWriteTime < max(getFileInfo(srcModule).lastWriteTime, hwylCliWriteTime):
    let cmd = "nim c -o:$1 $2" % [exe, srcModule]
    let code = execCmd(cmd)
    if code != 0:
      echo "cmd: ", cmd
      quit "failed to precompile test module"

proc preCompileTestModules*() =
  for srcModule in walkDirRec(pathToSrc / "clis"):
    if srcModule.endsWith(".nim"):
      let (_, moduleName, _) = srcModule.splitFile
      preCompileWorkingModule(moduleName)

template okWithArgs*(module: string, args = "", output = "") =
  preCompileWorkingModule(module)
  test (module & "|" & args):
    let (actualOutput, code) = runTestCli(module, args)
    check code == 0
    check output == actualOutput

template failWithArgs*(module: string, args = "", output = "") =
  preCompileWorkingModule(module)
  test (module & "|" & args):
    let (actualOutput, code) = runTestCli(module, args)
    check code == 1
    check output == actualOutput
