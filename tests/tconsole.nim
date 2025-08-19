{.define: bbansiOn.}
import std/unittest
import hwylterm

suite "console":
  test "file":
    let console = newConsole()
    console.echo bb"[red]red[/]"

  test "global":
    hwylConsole.file = stderr
    hecho bb"[red]red[/]"

    setHwylConsoleFile(stdout)
    hecho bb"[red]red[/]"

