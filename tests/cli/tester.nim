import std/[os, unittest]
import ./lib

if commandLineParams().len == 0:
  preCompileTestModules()

suite "hwylcli":
  okWithArgs("posBasic", "a b c d e", """args=@["a", "b", "c", "d", "e"]""")
  okWithArgs("posFirst", "a b c d e", """first=@["a", "b", "c"], second=d, third=e""")
  failWithArgs(
    "posFirst", "a b", "error missing positional args, got: 2, expected at least: 3"
  )
  okWithArgs("posLast", "a b", """first=a, second=b, third=@[]""")
  okWithArgs("posNoMulti", "5 b c", """first=5, second=b, third=c""")
  failWithArgs(
    "posNoMulti", "5 b c d",
    """error unexepected positional args, got: 4, expected: 3""",
  )

  okWithArgs("enumFlag", "--color red", "color=red")
  failWithArgs(
    "enumFlag", "--color black",
    "error failed to parse value for color as enum: black expected one of: red,blue,green",
  )

  okWithArgs("subcommands", "a b c", """input=b outputs=@["c"]""")
  failWithArgs("subcommands", "b b c", """error got unexpected positionals args: b c""")
  okWithArgs(
    "subcommands", "b --input in --outputs out1 --outputs out2",
    """input=in outputs=@["out1", "out2"]""",
  )

  okWithArgs("subcommands", "ccccc", """no flags :)""")
  okWithArgs("subcommands", "c", """no flags :)""")

  okWithArgs(
    "posFirst", "--help",
    """
usage:
  positionals first... second third [flags]

flags:
  -h --help show this help
""",
  )

  okWithArgs(
    "flagSettings", "--help",
    """
usage:
  flag-settings [flags]

flags:
     --input flag with default hidden
     --count a count var with default (0)
  -h --help  show this help
""",
  )

  okWithArgs(
    "cliCfgSettingHideDefault", "--help",
"""
usage:
  setting-hide-default [flags]

flags:
     --input flag with default hidden
     --count a count var with default
  -h --help  show this help
""",
  )

  okWithArgs(
    "customHelp", "--help",
"""
usage:
  custom-help [flags]

flags:
     --input 
         input (input.txt)
     --output
         output (output.txt)
  -h --help  
         show this help
""",
  )
  okWithArgs(
    "subHooks", "a",
"""
preSub from root!
inside sub 'a'
postSub from root!
""",
  )
  okWithArgs(
    "subHooks", "b a",
    """
preSub from root!
inside sub 'b a'
postSub from root!
inside sub 'b'
""",
  )
  okWithArgs(
    "subHooks", "c a",
"""
preSub from 'c'!
inside sub 'c a'
postSub from root!
inside sub c
""",
  )
  failWithArgs(
    "errorOverride", "--flag","override the default error\nerror unknown flag: flag"
  )
  okWithArgs(
    "inferShort", "-i input -o output","""input=input, output=output, count=0, nancy=false, ignore=false"""
  )
