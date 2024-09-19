import std/[os, strformat, strutils]

task test, "run tests":
  selfExec "r tests/tbbansi.nim"

task develop, "install cligen for development":
  exec "nimble install -l 'cligen@1.7.5'"

task docs, "Deploy doc html + search index to public/ directory":
  let
    deployDir = getCurrentDir() / "public"
    pkgName = "hwylterm"
    srcFile = getCurrentDir() / fmt"src/{pkgName}.nim"
    gitUrl = fmt"https://github.com/daylinmorgan/{pkgName}"
  # selfExec fmt"doc --index:on --git.url:{gitUrl} --git.commit:v{version} --outdir:{deployDir} --project {srcFile}"
  selfExec fmt"doc --index:on --git.url:{gitUrl} --git.commit:main --outdir:{deployDir} --project {srcFile}"
  withDir deployDir:
    mvFile(pkgName & ".html", "index.html")
    for file in walkDirRec(".", {pcFile}):
      # As we renamed the file, we need to rename that in hyperlinks
      exec(r"sed -i -r 's|$1\.html|index.html|g' $2" % [pkgName, file])
      # drop 'src/' from titles
      exec(r"sed -i -r 's/<(.*)>src\//<\1>/' $1" % file)

when withDir(thisDir(), system.dirExists("nimbledeps")):
  --path:"./nimbledeps/pkgs2/cligen-1.7.5-f3ffe7329c8db755677d3ca377d02ff176cec8b1"
