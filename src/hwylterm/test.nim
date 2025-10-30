import std/macros
macro myMacro(args: varargs[untyped]): untyped =
  result = newStmtList()
  for arg in args:
    result.add quote do:
      echo `arg`

myMacro(1, 2, 3, "hello")

