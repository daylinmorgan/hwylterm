# hwylterm

Bringing some fun (hwyl) to the terminal!

A library for building styled terminal applications. It provides BB-style markup for ANSI colors (`[bold red]error[/]`), a macro-based CLI framework (`hwylCli`), styled tables, spinners, progress bars, an interactive chooser, and a colored logger — all built around a shared color mode that respects `NO_COLOR` and terminal detection.

See the [API documentation](https://hwylterm.dayl.in) for more information.

## use library

```nim
requires "https://github.com/daylinmorgan/hwylterm"
```

## use CLI's

```sh
nimble install "https://github.com/daylinmorgan/hwylterm?subdir=tools"
```
