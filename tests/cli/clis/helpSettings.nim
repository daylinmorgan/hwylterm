import std/strformat
import hwylterm, hwylterm/hwylcli

const noExtras = HwylCliStyles(settings: {})

hwylCli:
  name "help-styles"
  flags:
    [flags]
    input:
      T string
      ? "required input"
      S Required
    k:
      T string
      ? "predefined flag"
      * "value"
  subcommands:
    [all]
    ... "show all help styling settings"
    help:
      styles: builtinStyles[AllSettings]
    flags: ^[flags]

    [minimal]
    ... "show minimal help with no styling"
    help:
      styles: builtinStyles[Minimal]
    flags: ^[flags]

    [noColor]
    ... "show noColor help "
    help:
      styles: builtinStyles[WithoutColor]
    flags: ^[flags]

    [noAnsi]
    ... "show noColor help "
    help:
      styles: builtinStyles[WithoutAnsi]
    flags: ^[flags]
