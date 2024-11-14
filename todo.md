# hwylterm todo's

- [x] add cligen adapters to add colors with bbansi
  - [ ] add integration test check cligen
- [x] add generic help generator to accompany parseopt

## improvements


- [ ] addJoinStyle(); works like join except wraps each argument in a style
- [ ] add span aware split/splitlines
- [ ] consider reducing illwill surface to only relevant IO (input) features
- [ ] revamp spinner api (new  threads?)
- [x] add Bbstring ~~indexing operations~~ strutils, that are span aware
- [ ] console object with customizable options to apply formatting

### cli generator

- [ ] add support for types(metavars)/defaults/required in help output
- [ ] add nargs to CliCfg
- [x] add support for inheriting a single flag from parent (even from a "group")
- [x] add support to either (lengthen commands) or provide an alias for a subcommand
- [x] add command aliases to hwylcli help with switch
- [x] don't recreate "global"" variables in var section
- [ ] add flag overlap check before case statement generation (after parsing?)
- [ ] add key-value flag support -> `--setting:a:off`
- [ ] add defaultFlagType CliCfg setting

## features

- [x] make a basic choose one from list widget
- [ ] tables/boxes?
- [x] confirmation proc
- [ ] basic progress bar
- [ ] support for 256 and truecolors
  - [ ] support for rgb colors
  - [ ] modify 256 colors w/parser changes to be `"[color(9)]red"` instead of `[9]red`
  - [x] improve color detection [ref](https://github.com/Textualize/rich/blob/4101991898ee7a09fe1706daca24af5e1e054862/rich/console.py#L791)

## testing

- [ ] make proper test suite for cli generator
- [ ] investigate [cap10](https://github.com/crashappsec/cap10) as a means of scripting the testing

<!-- generated with <3 by daylinmorgan/todo -->
