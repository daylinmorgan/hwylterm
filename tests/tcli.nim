# TODO: combine this with tests/cli/
import std/[
  unittest,
  strutils
]
import hwylterm, hwylterm/hwylcli

suite "cli":
  test "cli":
    let expected = """[b]test-program[/] [[args...]

[bold cyan]flags[/]:
  [yellow]-h[/yellow] [magenta]--help   [/magenta] []show this help[/]
  [yellow]-V[/yellow] [magenta]--version[/magenta] []print version[/]"""
    let cli =
      newHwylCliHelp(
        header = "[b]test-program[/] [[args...]",
        flags = [("h","help","show this help",),("V","version","print version")]
      )
    check render(cli) == expected
    check $bb(render(cli)) == $bb(expected)
