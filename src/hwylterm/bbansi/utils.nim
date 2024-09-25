import std/[
  enumutils, os, strutils, terminal, sequtils
]
import ./[styles, colors]

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

func normStyle(style: string): string = style.replace("_","").capitalizeAscii()
func toCode(style: BbStyle): string = $ord(style)
func toCode(abbr: BbStyleAbbr): string = abbr.toStyle().toCode()
func toCode(color: ColorXterm): string = "38;5;" & $ord(color)
func toBgCode(color: ColorXterm): string = "48;5;" & $ord(color)
func toCode(c: ColorRgb): string = "38;2;" & $c
func toBgCode(c: ColorRgb): string = "48:2;" & $c
func toCode(c: Color256): string = "38;5;" & $c
func toBgCode(c: Color256): string = "48;5;" & $c

const ColorXTermNames = ColorXterm.items().toSeq().mapIt(($it).toLowerAscii().capitalizeAscii())
const BbStyleNames = BbStyle.items().toSeq().mapIt(($it).toLowerAscii().capitalizeAscii())
const ColorDigitStrings = (1..255).toSeq().mapIt($it)

func isHex(s: string): bool =
  (s.startswith "#") and (s.len == 7)

# TODO: write seperate parseStyle procedure

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
    let normalizedStyle = style.normStyle

    if normalizedStyle in ["B", "I", "U"]:
      codes.add parseEnum[BbStyleAbbr](normalizedStyle).toCode()
    elif normalizedStyle in BbStyleNames:
      codes.add parseEnum[BbStyle](normalizedStyle).toCode()

    if not (bbMode == On): continue

    if normalizedStyle in ColorXtermNames:
      codes.add parseEnum[ColorXterm](normalizedStyle).toCode()
    elif normalizedStyle.isHex():
      codes.add  normalizedStyle.hexToRgb.toCode()
    elif normalizedStyle in ColorDigitStrings:
      codes.add parseInt(normalizedStyle).toCode()
    else:
      when defined(debugBB): echo "unknown style: " & normalizedStyle

  if bbMode == On and bgStyle != "":
    let normalizedBgStyle = bgStyle.normStyle
    if normalizedBgStyle in ColorXtermNames:
      codes.add parseEnum[ColorXTerm](normalizedBgStyle).toBgCode()
    elif normalizedBgStyle.isHex():
      codes.add normalizedBgStyle.hexToRgb().toBgCode()
    elif normalizedBgStyle in ColorDigitStrings:
      codes.add parseInt(normalizedBgStyle).toCode()
    else:
      when defined(debugBB): echo "unknown bg style: " & normalizedBgStyle

  if codes.len > 0:
    result.add "\e["
    result.add codes.join ";"
    result.add "m"


