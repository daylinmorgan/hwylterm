import std/[unittest]
import ./lib

suite "hwylcli":
  setup:
    preCompileTestModules()

  okWithArgs(
    "posBasic",
    "a b c d e",
    """args=@["a", "b", "c", "d", "e"]"""
  )
  okWithArgs(
    "posFirst",
    "a b c d e",
    """first=@["a", "b", "c"], second=d, third=e"""
  )
  failWithArgs(
    "posFirst",
    "a b",
    "error missing positional args, got: 2, expected at least: 3",
  )
  okWithArgs("posLast", "a b", """first=a, second=b, third=@[]""")
  okWithArgs("posNoMulti", "5 b c", """first=5, second=b, third=c""")
  failWithArgs("posNoMulti", "5 b c d", """error unexepected positional args, got: 4, expected: 3""")

  okWithArgs("enumFlag","--color red", "color=red")
  failWithArgs("enumFlag","--color black", "error failed to parse value for color as enum: black expected one of: red,blue,green")

  okWithArgs("subcommands", "a b c","""input=b outputs=@["c"]""")
  failWithArgs("subcommands", "b b c","""error got unexpected positionals args: b c""")
  okWithArgs("subcommands","b --input in --outputs out1 --outputs out2", """input=in outputs=@["out1", "out2"]""")

  okWithArgs("posFirst", "--help",
"""usage:
  positionals first... second third [flags]

flags:
  -h --help show this help""")

