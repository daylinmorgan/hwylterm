import std/[unittest]
import ./lib

suite "hwylcli":
  test "positionals":
    checkRunWithArgs("posFirst", "a b c d e","""first=@["a", "b", "c"], second=d, third=e""")
    checkRunWithArgs("posFirst", "a b", "error missing positional args, got: 2, expected at least: 3", code = 1)
    checkRunWithArgs("posLast", "a b", """first=a, second=b, third=@[]""")
    checkRunWithArgs("posLastExact", "a b c d e", """first=a, second=b, third=@["c", "d", "e"]""")
    checkRunWithArgs("posNoMulti", "5 b c", """first=5, second=b, third=c""")
    checkRunWithArgs("posNoMulti", "5 b c d", """error missing positional args, got: 4, expected: 3""", code = 1)
