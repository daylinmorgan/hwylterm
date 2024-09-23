import std/[tables]

version       = "0.1.0"
author        = "Daylin Morgan"
description   = "bringing some fun (hwyl) to the terminal"
license       = "MIT"
srcDir        = "../src"
namedBin      = {
  "hwylterm/bbansi" :"bbansi",
  "hwylterm/chooser":"hwylchoose"
}.toTable


requires "nim >= 2.0.8"
