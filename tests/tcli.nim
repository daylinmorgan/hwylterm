import std/[
  unittest
]


import hwylterm, hwylterm/cli

suite "cli":
  test "cli":
    let expected = """[b]test-program[/] [[args...]

[b cyan]flags[/]:
  [yellow]-h[/] [magenta]--help   [/] []show this help[/]
  [yellow]-V[/] [magenta]--version[/] []print version[/]
"""
    let cli =  newHwylCli("[b]test-program[/] [[args...]",flags = [("h","help","show this help",),("V","version","print version")])
    check $cli == $bb(expected)
