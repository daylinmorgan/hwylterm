import std/[os, unittest]
import ./lib

if commandLineParams().len == 0:
  preCompileTestModules()


suite "positional":

  okWithArgs("posBasic", "a b c d e", """notFirst=a rest=@["b", "c", "d", "e"]""")
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


suite "flags":
  okWithArgs("enumFlag", "--color red", "color=red")
  failWithArgs(
    "enumFlag", "--color black",
    "error failed to parse value for color as enum: black expected one of: red,blue,green",
  )

suite "subcommands":

  okWithArgs("subcommands", "a b c", """input=b outputs=@["c"]""")
  failWithArgs("subcommands", "b b c", """error got unexpected positionals args: b c""")
  okWithArgs(
    "subcommands", "b --input in --outputs out1 --outputs out2",
    """input=in outputs=@["out1", "out2"]""",
  )

  okWithArgs("subcommands", "ccccc", """no flags :)""")
  okWithArgs("subcommands", "c", """no flags :)""")


suite "help":
  okWithArgs(
    "posFirst", "--help",
    """
usage:
  positionals first... second third [flags]

flags:
  -h --help  show this help
""",
  )

  okWithArgs(
    "flagSettings", "--help",
    """
usage:
  flag-settings [flags]

flags:
     --input string flag with default hidden
     --count Count  a count var with default (default: 0)
  -h --help         show this help
""",
  )

  okWithArgs(
    "cliCfgSettingHideDefault", "--help",
"""
usage:
  setting-hide-default [flags]

flags:
     --input string flag with default hidden
     --count Count  a count var with default
  -h --help         show this help
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
    "helpSettings", "--help",
"""
usage:
  help-switches subcmd [flags]

subcommands:
  required 

flags:
  -h --help show this help
"""
  )

  okWithArgs(
    "helpSettings", "required --help",
"""
usage:
  help-switches required [flags]

flags:
     --input required input
  -k         predefined flag
  -h --help  show this help
"""
  )

suite "hooks":
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

suite "parent-child":
  okWithArgs(
    "inheritFlags", "first --always", "always=true,first=false"
  )
  okWithArgs(
    "inheritFlags", "second --always --misc2", "always=true,misc1=false,misc2=true"
  )
  okWithArgs(
    "inheritFlags", "third --misc1", "always=false,misc1=true"
  )

suite "settings":
  okWithArgs(
    "inferShort", "-i input -o output","""input=input, output=output, count=0, nancy=false, ignore=false"""
  )
