import std/[strformat]
import hwylterm, hwylterm/hwylcli

hwylCli:
  name "subcommands"
  preSub:
    echo "preSub from root!"
  postSub:
    echo "postSub from root!"
  subcommands:
    [a]
    ... "subcommand 'a'"
    run:
      echo "inside sub 'a'"
    [b]
    ... "subcommand 'b'"
    run:
      echo "inside sub 'b'"
    subcommands:
      [a]
      ... "subcommand 'b a'"
      run:
        echo "inside sub 'b a'"
    [c]
    ... "subcommand 'c'"
    preSub:
      echo "preSub from 'c'!"
    run:
      echo "inside sub c"
    subcommands:
      [a]
      ... "subcommand 'c a'"
      run:
        echo "inside sub 'c a'"
