import std/[os, strformat]
import hwylterm, hwylterm/hwylcli

putEnv("HWYLCLISTYLES_HEADER","red")
# putEnv("HWYLCLISTYLES_SETTINGS", "Aliases")

hwylCli:
  name "help-settings"
  flags:
    [flags]
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
      ? """
      predefined flag
      k could be short for key idk
      """
      * "value"
  subcommands:
    [all]
    ... "show all help styling settings"
    help:
      styles: fromBuiltinHelpStyles(AllSettings)
    flags: ^[flags]

    [minimal]
    ... "show minimal help with no styling"
    help:
      styles: fromBuiltinHelpStyles(Minimal)
    flags: ^[flags]

    [noColor]
    ... "show noColor help "
    help:
      styles: fromBuiltinHelpStyles(WithoutColor)
    flags: ^[flags]

    [noAnsi]
    ... "show noColor help "
    help:
      styles: fromBuiltinHelpStyles(WithoutAnsi)
    flags: ^[flags]

    [longHelp]
    ... "-h != --help"
    flags: ^[flags]
    settings LongHelp

    [noEnv]
    ... "ignore env styles"
    flags: ^[flags]
    help:
      styles: newHwylCliStyles(settings = defaultStyleSettings + {HwylCliStyleSetting.NoEnv})

