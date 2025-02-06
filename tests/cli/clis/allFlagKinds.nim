import std/strformat
import hwylterm, hwylterm/hwylcli

hwylCli:
  name "flag-kinds"
  flags:
    a "kind: Command"
    b | bbbb "kind: InfixCommand"
    cccc:
      ? "kind: Stmt"
    d | dddd:
      ? "kind: InfixStmt"
    e(string, "kind: Call")
    f | ffff("kind: InfixCallStmt"):
      ident notffff
    gggg(string, "kind: CallStmt"):
      * "default"
    h | hhhh("kind: InfixCall")
  run:
    echo fmt"{a=}, {bbbb=}, {cccc=}, {dddd=}"
    echo fmt"{e=}, {notffff=}, {gggg=}, {hhhh=}"
