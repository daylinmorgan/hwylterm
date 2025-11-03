import std/os except getCurrentDir
import std/[strformat, strutils]

task develop, "install cligen for development":
  exec "nimble install -l 'cligen@1.7.5'"

task setupTests, "pre-compile test bins":
  exec "nim r tests/cli/setup"

proc docFixup(deployDir:string, pkgName: string) =
  ## apply renames to api docs
  withDir deployDir:
    mvFile(pkgName & ".html", "index.html")
    for file in walkDirRec(".", {pcFile}):
      # As we renamed the file, we need to rename that in hyperlinks
      exec(r"sed -i -r 's|$1\.html|index.html|g' $2" % [pkgName, file])
      # drop 'src/' from titles
      exec(r"sed -i -r 's/<(.*)>src\//<\1>/' $1" % file)

task docs, "Deploy doc html + search index to public/ directory":
  const extraModules = ["cligen", "chooser", "logging", "hwylcli", "parseopt3", "tables"]
  let
    deployDir = getCurrentDir() / "public"
    pkgName = "hwylterm"
    gitFlags = fmt"--git.url:'https://github.com/daylinmorgan/{pkgName}' --git.commit:main --git.devel:main"
    docCmd = fmt"doc {gitFlags} --index:on --outdir:{deployDir}"
  when defined(clean):
    echo fmt"clearing {deployDir}"
    rmDir deployDir
  for module in extraModules:
    selfExec fmt"{docCmd} --docRoot:{getCurrentDir()}/src/ src/hwylterm/{module}"
  selfExec fmt"{docCmd} --project  --project src/{pkgName}.nim"
  docFixup(deployDir, pkgName)

when withDir(thisDir(), system.dirExists("nimbledeps")):
  --path:"./nimbledeps/pkgs2/cligen-1.7.5-f3ffe7329c8db755677d3ca377d02ff176cec8b1"
