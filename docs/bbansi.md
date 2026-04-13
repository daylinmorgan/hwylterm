# bbansi

BB-style markup for ANSI terminal colors and styles.

## Basic Markup Syntax

Wrap text in `[style]...[/style]` tags:

```txt
[bold]hello[/bold]
[red]error[/red]
[bold red]warning[/]
```

- `[/style]` — close a specific style
- `[/]` — close the most recently opened style
- `[reset]` — reset all active styles

## Available Styles

### Text styles

| Markup | Abbreviation | Effect |
|---|---|---|
| `bold` | `b` | **bold** |
| `italic` | `i` | *italic* |
| `underline` | `u` | underline |
| `faint` | | dim/faint |
| `blink` | | blinking |
| `reverse` | | reverse video |
| `strike` | | ~~strikethrough~~ |
| `conceal` | | hidden |

### Colors

Named xterm colors: `black`, `red`, `green`, `yellow`, `blue`, `magenta`, `cyan`, `white`, plus bright variants (`brightred`, `brightblue`, etc.).

Hex colors:

```txt
[#ff8800]orange text[/]
```

256-color palette:

```txt
[color(42)]text[/]
```

### Background colors

Use the `on` keyword to set a background color:

```txt
[red on blue]text[/]
[on yellow]text[/]
```

### Combined styles

Multiple styles can be combined in a single tag:

```txt
[bold red]error[/]
[bold italic underline]important[/]
```

## Rendering to string

Parse markup into a `BbString`:

```nim
let s = bb("[bold]hello[/bold]")
```

Apply a style to a plain string:

```nim
let s = bb("hello", "bold red")
```

Render a `BbString` to an ANSI string using the global console:

```nim
echo $bb("[green]ok[/]")
```

Write to the global `hwylConsole` file (a wrapper around `hwylConsole.file.write`):

```nim
hecho bb("[bold]hello[/]"), " world"
```

Format strings with BB markup using `bbfmt`:

```nim
let name = "world"
hecho $bbfmt"[bold]hello {name}[/]"
```

## Escaping

| Input | Output |
|---|---|
| `[[` | ``[`` |
| `\\` | ``\`` |

Use `bbEscape` to programmatically escape a string before embedding it in markup:

```nim
let userInput = bbEscape(untrustedText)
hecho $bb("[bold]" & userInput & "[/bold]")
```

## Text Operations on BbString

All operations preserve styling:

```nim
# Truncate to N visible characters
let t = bb("[bold]hello world[/]").truncate(5)

# Word-wrap at N columns
let w = bb("[red]long text...[/]").wrapWords(40)

# Right-align / left-align (pad with spaces)
let r = bb("[blue]hi[/]").align(10)
let l = bb("[blue]hi[/]").alignLeft(10)

# Concatenate
let a = bb("[red]foo[/]") & bb("[blue]bar[/]")

# Side-by-side horizontal concatenation
let h = hconcat(bb("left\ncol"), bb("right\ncol"))

# Join a seq of BbStrings
let parts = @[bb("[red]a[/]"), bb("[green]b[/]")]
let joined = parts.join(bb(", "))
```

## Environment / Color Mode

| Variable | Effect |
|---|---|
| `NO_COLOR` | Disables all color output |
| `HWYLTERM_FORCE_COLOR` | Forces color on (even in pipes) |
| `HWYLTERM_FORCE_MARKUP` | Outputs BB markup instead of ANSI codes |

Compile-time flags (checked before environment variables):

| Flag | Effect |
|---|---|
| `-d:bbansiOn` | Forces color on |
| `-d:bbansiOff` | Forces color off |
| `-d:bbansiNoColor` | Disables color (strips styles, keeps text) |
| `-d:bbMarkup` | Outputs BB markup instead of ANSI codes |
