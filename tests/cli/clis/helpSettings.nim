## Builtin style presets let you switch the entire help appearance without manual style configuration.
import std/[os, strformat]
import hwylterm, hwylterm/hwylcli

putEnv("HWYLCLISTYLES_HEADER","red")
# putEnv("HWYLCLISTYLES_SETTINGS", "Aliases")

const identHelp = """predefined help string

k could be short for key idk
"""

proc helpRuntime(s: string): string = 
  result = s & """

some runtime generated help
"""


hwylCli:
  name "help-settings"
  flags:
    [group]
    input:
      T string
      ? """
      required input
      A long help that continues here
      and spans multiple lines
        the lines are dedented then reindented
        [yellow]this is yellow....[/]
      """
      S Required
    key:
      T string
      ? identHelp
      * "value"
    other:
      ? helpRuntime("first line of help")
  subcommands:
    [all]
    ... "show all help styling settings"
    help:
      styles: fromBuiltinHelpStyles(AllSettings)
    flags: ^[group]

    [minimal]
    ... "show minimal help with no styling"
    help:
      styles: fromBuiltinHelpStyles(Minimal)
    flags: ^[group]

    [noColor]
    ... "show noColor help "
    help:
      styles: fromBuiltinHelpStyles(WithoutColor)
    flags: ^[group]

    [noAnsi]
    ... "show noColor help "
    help:
      styles: fromBuiltinHelpStyles(WithoutAnsi)
    flags: ^[group]

    [longHelp]
    ... "-h != --help"
    flags: ^[group]
    settings LongHelp

    [noEnv]
    ... "ignore env styles"
    flags: ^[group]
    help:
      styles: newHwylCliStyles(settings = defaultStyleSettings + {HwylCliStyleSetting.NoEnv})

