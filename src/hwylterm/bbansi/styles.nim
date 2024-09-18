import std/tables
export tables


const
  bbReset* = "\e[0m"
  bbStyles* = {
    "reset": "0",
    "bold": "1",
    "b": "1",
    "faint": "2",
    "italic": "3",
    "i": "3",
    "underline": "4",
    "u": "4",
    "blink": "5",
    "reverse": "7",
    "conceal": "8",
    "strike": "9",
  }.toTable

  bbColors* = {
    "black": "0",
    "red": "1",
    "green": "2",
    "yellow": "3",
    "blue": "4",
    "magenta": "5",
    "cyan": "6",
    "white": "7",
  }.toTable
