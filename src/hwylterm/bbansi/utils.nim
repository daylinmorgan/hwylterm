import std/[strutils]

import styles

proc toAnsiCode*(s: string): string =
  var
    codes: seq[string]
    styles: seq[string]
    bgStyle: string
  if " on " in s or s.startswith("on"):
    let fgBgSplit = s.rsplit("on", maxsplit = 1)
    styles = fgBgSplit[0].toLowerAscii().splitWhitespace()
    bgStyle = fgBgSplit[1].strip().toLowerAscii()
  else:
    styles = s.splitWhitespace()
  for style in styles:
    if style in bbStyles:
      codes.add bbStyles[style]
    elif style in bbColors:
      codes.add "3" & bbColors[style]
  if bgStyle in bbColors:
    codes.add "4" & bbColors[bgStyle]

  if codes.len > 0:
    result.add "\e["
    result.add codes.join ";"
    result.add "m"
