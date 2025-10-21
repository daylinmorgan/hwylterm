##[
  # Hwylterm Chooser

  ```nim
  import hwylterm/chooser

  let items = ["a","b","c"]
  let item = choose(items)
  ```
]##

import std/[enumerate, os, strutils, sequtils, sets, terminal]

import ../hwylterm
import ../hwylterm/[hwylcli, chooser]

when isMainModule:
  hwylcli:
    name "hwylchoose"
    settings ShowHelp
    help:
      description """
      hwylchoose a b c d
      hwylchoose a,b,c,d -s ,
      hwylchoose a,b,c,d --seperator ","
      hwylchoose --demo
      """
    hidden demo
    positionals:
      args seq[string]
    flags:
      demo "show demo (select from a-zA-Z)"
      s|separator(string, "separator to split items")
      height(6, int, "set height")
    run:
      var items: seq[string]
      if demo:
        items &= LowercaseLetters.toSeq().mapIt($it) & UppercaseLetters.toSeq().mapIt($it)
      else:
        if separator != "":
          if args.len != 1: hwylCliError("only pass one positional arg (of items separated with separator) when using --separator")
          items = args[0].split(separator).mapIt(strip(it))
        else:
          items = args

      let selected = choose(items, height)
      echo selected.join("\n")



