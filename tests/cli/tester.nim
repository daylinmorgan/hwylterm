import std/[unittest]
import ./lib

suite "hwylcli":
  test "positionals":
    okWithArgs(
      "posFirst",
      "a b c d e",
      """
first=@["a", "b", "c"], second=d, third=e
args=@[]"""
    )
    failWithArgs(
      "posFirst",
      "a b",
      "error missing positional args, got: 2, expected at least: 3",
    )
    okWithArgs("posLast", "a b", """first=a, second=b, third=@[]""")
    okWithArgs("posLastExact", "a b c d e", """first=a, second=b, third=@["c", "d", "e"]""")
    okWithArgs("posNoMulti", "5 b c", """first=5, second=b, third=c""")
    failWithArgs("posNoMulti", "5 b c d", """error missing positional args, got: 4, expected: 3""")
  test "special flag types":
    okWithArgs("enumFlag","--color red", "color=red")
    failWithArgs("enumFlag","--color black", "error failed to parse value for color as enum: black expected one of: red,blue,green")

  test "help":
    okWithArgs("posFirst", "--help",
"""usage:
  positionals first... second third [flags]

flags:
  -h --help show this help""")
