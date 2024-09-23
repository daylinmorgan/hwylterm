import std/[parseutils, strutils]

type
  ColorRgb* = object
    red, green, blue: int
  ColorHex* = object
    code: string
  ColorXterm* = enum
    # 0-7
    Black, Red, Green, Yellow, Blue, Magenta, Cyan, White,
    # 8-15
    BrightBlack, BrightRed, BrightGreen, BrightYellow,
    BrightBlue, BrightMagenta, BrightCyan, BrightWhite

func rgb*(r, g, b: int): ColorRgb =
  ColorRgb(red: r, green: g, blue: b)

func hexToRgb*(s: string): ColorRgb =
  let code = s.replace("#", "")
  assert code.len == 6
  discard parseHex(code[0..1], result.red)
  discard parseHex(code[2..3], result.green)
  discard parseHex(code[4..5], result.blue)

func `$`*(c: ColorRgb): string =
  result.add $c.red
  result.add ";"
  result.add $c.green
  result.add ";"
  result.add $c.blue
