task test, "run tests":
  selfExec "r tests/tbbansi.nim"

task develop, "install cligen for development":
  exec "nimble install -l 'cligen@1.7.5'"

--path:"./nimbledeps/pkgs2/cligen-1.7.5-f3ffe7329c8db755677d3ca377d02ff176cec8b1"
