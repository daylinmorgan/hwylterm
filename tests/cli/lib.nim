import std/[compilesettings, os, osproc, strutils, times, unittest]

const pathToSrc = querySetting(SingleValueSetting.projectPath)
const binDir = pathToSrc / "bin"
const hwylCliSrc = pathToSrc / "../../src/hwylterm/hwylcli.nim"
let hwylCliWriteTime =  getFileInfo(hwylCliSrc).lastWriteTime

if not dirExists(binDir):
  createDir(binDir)

proc runTestCli(module: string, args: string, code: int = 0): string =
  let cmd = binDir / module & " " & args
  let (output, exitCode) = execCmdEx(cmd)
  check code == exitCode
  result = output.strip()

proc preCompileWorkingModule(module: string) =
  let exe = binDir / module
  let srcModule = pathToSrc / "clis" / (module & ".nim")
  if not exe.fileExists or getFileInfo(exe).lastWriteTime < max(getFileInfo(srcModule).lastWriteTime, hwylCliWriteTime):
    let cmd = "nim c -o:$1 $2" % [exe, srcModule]
    let code = execCmd(cmd)
    if code != 0:
      echo "cmd: ", cmd
      quit "failed to precompile test module"

proc checkRunWithArgs*(module: string, args = "", output = "", code = 0) =
  preCompileWorkingModule(module)
  check output == runTestCli(module, args, code)
