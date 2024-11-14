import std/[
  unittest
]


import hwylterm, hwylterm/hwylcli

suite "cli":
  test "cli":
    let expected = """[b]test-program[/] [[args...]

[b cyan]flags[/]:
  [yellow]-h[/] [magenta]--help   [/] []show this help[/]
  [yellow]-V[/] [magenta]--version[/] []print version[/]
"""
    let cli =
      newHwylCliHelp(
        header = "[b]test-program[/] [[args...]",
        flags = [("h","help","show this help",),("V","version","print version")]
      )
    check $bb(cli) == $bb(expected)
