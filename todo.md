# hwylterm todo's

- [x] add cligen adapters to add colors with bbansi
  - [ ] add integration test check cligen
  - [ ] test cligen generator with recent releases (use example from cligen repo?)
- [x] add generic help generator to accompany parseopt

## improvements

- [ ] addJoinStyle(); works like join except wraps each argument in a style
- [ ] consider reducing illwill surface to only relevant IO (input) features
- [ ] revamp spinner api (new threads module?)
- [x] add Bbstring ~~indexing operations~~ strutils, that are span aware
- [ ] console object with customizable options to apply formatting (like rich.console)

## cli generator

- [x] add InferShortFlags setting
- [x] add support for types(metavars)/defaults/required in help output
- [x] BUG: flag can't be `key`
- [ ] ShowHelp setting should also occur after "a hwylCliError"
      could be by default (see `program --help` for more info.)
- [ ] consider support "more verbose" help i.e. -h vs --help giving different results
- [ ] add support for E/env param for flags to add custom env_var (in help (env: OPTIONAL_ENV_VAR))
      inject this code in the same place as the "default" setting
- [ ] consider default (or opt in) "help subcmd"
  > app help (show all help?)
  > app help <subcmd> same as app <subcmd> --help
- [ ] support old positionals behavior as optin toplevel setting (store data in `args`)
- [ ] allow single positional to be optional
- [ ] add support for hidden flags


## features

- [x] make a basic choose one from list widget
- [ ] tables/boxes?
- [x] confirmation proc
- [ ] basic progress bar
- [ ] support for 256 and truecolors
  - [x] support for rgb colors
  - [x] modify 256 colors w/parser changes to be `"[color(9)]red"` instead of `[9]red`
  - [x] improve color detection [ref](https://github.com/Textualize/rich/blob/4101991898ee7a09fe1706daca24af5e1e054862/rich/console.py#L791)

## testing

- [ ] make proper test suite for cli generator
- [ ] investigate [cap10](https://github.com/crashappsec/cap10) as a means of scripting the testing

<!-- generated with <3 by daylinmorgan/todo -->
