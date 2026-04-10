# hwylcli

A macro-based DSL for building styled, color-aware CLIs.

## Minimal example

```nim
import hwylterm, hwylterm/hwylcli

hwylCli:
  name "mytool"
  run:
    echo "hello"
```

The `hwylCli` macro generates a parser, a help printer, and runs the command. `-h`/`--help` are added automatically.

## Flags

Declare flags inside a `flags:` block. The default type is `bool`.

Single-character names are treated as short flags only:

```nim
import hwylterm, hwylterm/hwylcli

hwylCli:
  name "multiple-short-flags"
  flags:
    a "first short"
    b "second short"
  run:
    echo a, b
```

### Flag DSL syntax

There are several equivalent ways to declare a flag. All forms support the same set of properties:

```nim
import hwylterm, hwylterm/hwylcli

hwylCli:
  name "flag-kinds"
  flags:
    a "kind: Command"                       # flagname "help"
    b | bbbb "kind: InfixCommand"           # short | flagname "help"
    cccc:
      ? "kind: Stmt"                        # flagname: block
    d | dddd:
      ? "kind: InfixStmt"                   # short | flagname: block
    e(string, "kind: Call")                 # flagname(type, "help")
    f | ffff("kind: InfixCall"):
      ident notffff                         # custom variable name
    gggg(string, "kind: CallStmt"):
      * "default"                           # flagname(type, "help"): block
    h | hhhh("kind: InfixCall")
    i: "kind: Stmt (but one line)"
  run:
    echo a, bbbb, cccc, dddd, e, notffff, gggg, hhhh, i
```

Inside a stmt block, the available properties are:

| Key | Alias | Meaning |
|---|---|---|
| `?` | `help` | help text |
| `-` | `short` | short flag char |
| `*` | `default` | default value |
| `T` | | type |
| `g` | `group` | flag group name |
| `E` | `env` | env var name override |
| `S` | `settings` | flag settings |
| `ident` | | variable name in `run:` block |

### Flag types

Flags use Nim types directly:

```nim
import std/strformat
import hwylterm, hwylterm/hwylcli

hwylCli:
  name "default-values"
  flags:
    input:
      T string
      * "testing"
      ? "input file"
    count:
      T int
      * 5
      ? "number of iterations"
  run:
    echo fmt"{input=}, {count=}"
```

See Count_ and KV_ for the incrementing and key-value types. Enum flags are parsed by name with an error listing valid choices.

Enum flag example:

```nim
import std/strformat
import hwylterm, hwylterm/hwylcli

type Color = enum
  red, blue, green

hwylCli:
  name "enumFlag"
  flags:
    color:
      T Color
  run:
    echo fmt"{color=}"
```

`Count` and `KV` examples:

```nim
import hwylterm, hwylterm/hwylcli

hwylCli:
  name "flagKVs"
  flags:
    count(Count, "count")
    input(seq[KV[string, int]], "key=value pairs")
  run:
    echo count
    for (k, v) in input:
      echo k, ":", v
```

`object`'s can function the same as `KV` flags with known options

```nim
import hwylterm, hwylterm/hwylcli

type
  Person = object
    name: string
    age: int

hwylCli:
  name "objectflag"
  flags:
    person(Person, "a person")
  run:
    echo person
```

### Flag settings

Use `S <setting>` inside a flag block:

See CliFlagSetting_ for more info.

```nim
import hwylterm, hwylterm/hwylcli

hwylCli:
  name "flag-settings"
  flags:
    input:
      S HideDefault
      T string
      * "default.txt"
      ? "flag with default hidden from help"
  run:
    discard
```

## Help text

Use `...` or `help` to set help content:

```nim
import hwylterm, hwylterm/hwylcli

hwylCli:
  name "mytool"
  help:
    header "My Tool v1.0"
    description "does useful things"
    footer "see https://example.com for more"
  flags:
    input:
      T string
      ? "input file"
  run:
    echo input
```

Available keys inside `help:`:

| Key | Meaning |
|---|---|
| `description` | main description text |
| `usage` | usage line |
| `header` | printed above usage |
| `footer` | printed below flags |
| `styles` | `HwylCliStyles` value |

Short form: `... "description text"` sets the description directly.

## CLI settings

Use `settings` to enable different behaviors. See CliSetting_ for more info.

```nim
import hwylterm, hwylterm/hwylcli

hwylCli:
  name "setting-propagate"
  settings InferShort, LongHelp
  flags:
    input:
      T string
      * "the default"
      ? "input flag"
  run:
    echo input
```

Settings propagate to subcommands by default. Use `IgnoreParent` on a subcommand to opt out, or add a setting to override for that subcommand only:

```nim
import hwylterm, hwylterm/hwylcli

hwylCli:
  name "setting-propagate"
  settings InferShort
  flags:
    input:
      T string
      ? "input flag"
  subcommands:
    [one]
    settings IgnoreParent   # won't inherit InferShort
    run:
      echo input

    [two]
    settings HideDefault    # inherits InferShort, adds HideDefault
    run:
      echo input
```

## Version flag

```nim
import hwylterm, hwylterm/hwylcli

hwylCli:
  name "mytool"
  version "1.0.0"
  run:
    echo "running"
```

Adds `-V`/`--version` which prints the version string and exits.

## Positional arguments

Positionals are declared in a `positionals:` block. Each entry is `name type`:

```nim
import std/strformat
import hwylterm, hwylterm/hwylcli

hwylCli:
  name "positionals"
  positionals:
    first int
    second string
    third string
  run:
    echo fmt"{first=}, {second=}, {third=}"
```

Use `seq[T]` for a variadic positional. It can appear first or last:

```nim
# variadic last
import std/strformat
import hwylterm, hwylterm/hwylcli

hwylCli:
  name "posLast"
  positionals:
    first string
    second string
    third seq[string]
  run:
    echo fmt"{first=}, {second=}, {third=}"
```

```nim
# variadic first
import std/strformat
import hwylterm, hwylterm/hwylcli

hwylCli:
  name "positionals"
  positionals:
    first seq[string]
    second string
    third string
  run:
    echo fmt"{first=}, {second=}, {third=}"
```

Use a stmt block to set a custom variable name via `ident`:

```nim
import std/strformat
import hwylterm, hwylterm/hwylcli

hwylCli:
  name "posBasic"
  positionals:
    first:
      T string
      ident notFirst
    rest seq[string]
  run:
    echo fmt"{notFirst=} {rest=}"
```

## Subcommands

Subcommands are delimited by `[name]` markers inside a `subcommands:` block:

```nim
import std/strformat
import hwylterm, hwylterm/hwylcli

hwylCli:
  name "mytool"
  subcommands:
    [build]
    ... "compile the project"
    flags:
      release "build in release mode"
    run:
      echo fmt"building... {release=}"

    [clean]
    ... "remove build artifacts"
    alias c
    run:
      echo "cleaning..."
```

Subcommands can be nested:

```nim
import hwylterm, hwylterm/hwylcli

hwylCli:
  name "subcommands"
  subcommands:
    [b]
    ... "subcommand with nested subcommands"
    run:
      echo "inside sub 'b'"
    subcommands:
      [a]
      ... "subcommand 'b a'"
      run:
        echo "inside sub 'b a'"
```

### Hooks

`preSub` and `postSub` run before/after any subcommand at that level:

```nim
import hwylterm, hwylterm/hwylcli

hwylCli:
  name "mytool"
  preSub:
    echo "before subcommand"
  postSub:
    echo "after subcommand"
  subcommands:
    [build]
    run:
      echo "building"

    [clean]
    run:
      echo "cleaning"
```

### Inheriting flags from parent and flag grouping

Use `[groupname]` inside `flags:` to group flags. Requires `FlagGroups` in help settings to render as separate sections.
Flags in a group named `global` are automatically inherited by all subcommands. Other flags/groups can be pulled in explicitly using `^`:

```nim
import std/strformat
import hwylterm, hwylterm/hwylcli

hwylCli:
  name "inherit-flags"
  help:
    styles: newHwylCliStyles(settings = defaultStyleSettings + {FlagGroups})
  flags:
    [global]
    always "in all subcommands"
    [misc]
    misc1 "first misc flag"
    misc2 "second misc flag"
    ["_hidden"]
    other "flag from hidden group"
  subcommands:
    [first]
    ... "command with it's own flag"
    flags:
      # manually defined groups
      first "first first flag":
        group misc
    run:
      echo fmt"{always=},{first=}"

    [second]
    ... "command with 'misc' flags"
    flags:
      ^[misc]
    run:
      echo fmt"{always=},{misc1=},{misc2=}"

    [third]
    ... "command with only 'misc1' flag"
    flags:
      ^misc1
      ^["_hidden"]
    run:
      echo fmt"{always=},{misc1=}"
```

Groups prefixed with `_` are hidden from help output but can still be inherited with `^`.

### Env var inference with subcommands

With `InferEnv`, env vars are named `CMDNAME_FLAGNAME` and work across subcommands:

```nim
import std/strformat
import hwylterm, hwylterm/hwylcli

hwylCli:
  name "mytool"
  settings InferEnv
  flags:
    [global]
    input:
      T string
      * "default.txt"
      ? "input file"
  subcommands:
    [build]
    run:
      echo fmt"{input=}"   # reads MYTOOL_INPUT env var if flag not passed
```

## `GenerateOnly` — manual invocation

Use `GenerateOnly` when you need to run code before the CLI or call the parser manually. The macro generates `printNameHelp()`, `parseNameCmdLine()`, and `runName()` procs but does not call `runName()` automatically:

```nim
import hwylterm/hwylcli

hwylCli:
  name "mytool"
  settings GenerateOnly
  flags:
    input(string, "input file")
  run:
    echo input

# code that runs before the CLI
echo "starting up"

runMytool()
```

## Help styling

The `HwylCliStyles` object controls how help text is rendered:

```nim
import hwylterm, hwylterm/hwylcli

hwylCli:
  name "help-settings"
  help:
    styles: newHwylCliStyles(
      header = "bold cyan",
      flagShort = "yellow",
      flagLong = "magenta",
      required = "red",
      settings = defaultStyleSettings + {FlagGroups},
    )
  flags:
    input:
      T string
      S Required
      ? "required input"
  run:
    echo input
```

### Builtin style presets

```nim
import hwylterm, hwylterm/hwylcli

hwylCli:
  name "mytool"
  flags:
    input:
      T string
      ? "input file"
  subcommands:
    [styled]
    help:
      styles: fromBuiltinHelpStyles(AllSettings)
    run:
      echo input

    [plain]
    help:
      styles: fromBuiltinHelpStyles(WithoutAnsi)
    run:
      echo input
```

See BuiltinStyleKind_ for available presets.

### Help display settings

Controlled via HwylCliStyleSetting_ values in `styles.settings`. The default set is `{Aliases, Required, Defaults, Types}`.

### Environment overrides for styles

Each style field can be overridden at runtime:

```sh
HWYLCLISTYLES_HEADER=bold
HWYLCLISTYLES_FLAGSHORT=cyan
HWYLCLISTYLES_SETTINGS=Aliases,Defaults
HWYLCLISTYLES_MINCMDLEN=12
```

Set `NoEnv` in the help settings to disable this.

## Error reporting

```nim
hwylCliError("something went wrong")
hwylCliError(bb("[bold]flag[/] requires a value"))
```

Prints `error <msg>` (with `error` styled red) and exits.
