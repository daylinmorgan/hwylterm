import std/[os, strformat, strutils]

task test, "run tests":
  selfExec "r tests/tbbansi.nim"

task develop, "install cligen for development":
  exec "nimble install -l 'cligen@1.7.5'"

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
  let
    deployDir = getCurrentDir() / "public"
    pkgName = "hwylterm"
    gitFlags = fmt"--git.url:'https://github.com/daylinmorgan/{pkgName}' --git.commit:main"
  when defined(clean):
    echo fmt"clearing {deployDir}"
    rmDir deployDir
  for module in ["cligen", "chooser", "logging", "cli"]:
    selfExec fmt"doc --docRoot:{getCurrentDir()}/src/ --index:on --outdir:{deployDir} src/hwylterm/{module}"
  selfExec fmt"doc --project --index:on {gitFlags} --outdir:{deployDir} --project src/{pkgName}.nim"
  docFixup(deployDir,pkgName)

when withDir(thisDir(), system.dirExists("nimbledeps")):
  --path:"./nimbledeps/pkgs2/cligen-1.7.5-f3ffe7329c8db755677d3ca377d02ff176cec8b1"
