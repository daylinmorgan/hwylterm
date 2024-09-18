import std/[os, strutils, terminal]
import ./styles

type
  BbMode* = enum
    On, NoColor, Off

proc checkColorSupport(): BbMode =
  when defined(bbansiOff):
    return Off
  when defined(bbansiNoColor):
    return NoColor
  else:
    if os.getEnv("HWYLTERM_FORCE_COLOR") != "":
      return On
    if os.getEnv("NO_COLOR") != "":
      return NoColor
    if not isatty(stdout):
      return Off

let bbMode* = checkColorSupport()

proc toAnsiCode*(s: string): string =
  if bbMode == Off: return
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
    elif style in bbColors and bbMode == On:
      codes.add "3" & bbColors[style]
  if bgStyle in bbColors and bbMode == On:
    codes.add "4" & bbColors[bgStyle]

  if codes.len > 0:
    result.add "\e["
    result.add codes.join ";"
    result.add "m"


