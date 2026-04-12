import std/os except getCurrentDir
import std/[strutils]

task develop, "install cligen for development":
  exec "nimble install -l 'cligen@1.7.5'"

task setupTests, "pre-compile test bins":
  exec "nim r tests/cli/setup"

when defined(docs):
  --index:on
  --warning:"LanguageXNotSupported:off"
  --git.url:"https://github.com/daylinmorgan/hwylterm"
  --path:src
  --outdir:public

proc generatedDocs() =
  if not dirExists("public/cli"):
    selfExec "r tests/cli/gen_svgs"
  if not fileExists("docs/cli-examples.md"):
    selfExec "r tests/cli/gen_docs"

task docs, "build docs with fixup":
  const extraModules = [
    "cligen", "chooser", "logging", "hwylcli", "parseopt3", "tables"
  ]
  when defined(clean):
    echo "clearing outputs"
    rmDir "public"
    rmFile "docs/cli-examples.md"
  generatedDocs()
  selfExec "md2html -d:docs docs/cli-examples.md"
  for module in extraModules:
    selfExec "doc -d:docs --docRoot:$1/src/ src/hwylterm/$2" % [ getCurrentDir(), module ]
  selfExec "doc -d:docs --project src/hwylterm.nim"
  withDir "public": cpFile("hwylterm.html", "index.html")


when withDir(thisDir(), system.dirExists("nimbledeps")):
  --path:"./nimbledeps/pkgs2/cligen-1.7.5-f3ffe7329c8db755677d3ca377d02ff176cec8b1"
