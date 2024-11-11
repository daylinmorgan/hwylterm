##[
  ## bbansi

  use BB style markup to add color to strings using VT100 escape codes
]##

{.push raises:[].}

import std/[
  macros, os, sequtils, strformat, strutils, terminal
]
import ./bbansi/[styles, colors]


type
  BbMode* = enum
    On, NoColor, Off
  ColorSystem = enum
    TrueColor, EightBit, Standard, None

proc checkColorSupport(): BbMode =
  when defined(bbansiOff):
    return Off
  when defined(bbansiNoColor):
    return NoColor
  else:
    if getEnv("HWYLTERM_FORCE_COLOR") != "":
      return On
    elif getEnv("NO_COLOR") != "":
      return NoColor
    elif (getEnv("TERM") in ["dumb", "unknown"]) or not isatty(stdout):
      return Off

proc checkColorSystem(): ColorSystem =
  let colorterm = getEnv("COLORTERM").strip().toLowerAscii()
  if colorterm in ["truecolor", "24bit"]:
    return TrueColor
  let term = getEnv("TERM", "").strip().toLowerAscii()
  let colors = term.split("-")[^1]
  return
    case colors:
    of "kitty": EightBit
    of "256color": EightBit
    of "16color": Standard
    else: Standard

let bbMode* = checkColorSupport()
let colorSystem* = checkColorSystem()

func firstCapital(s: string): string = s.toLowerAscii().capitalizeAscii()
func normalizeStyle(style: string): string = style.replace("_","").toLowerAscii().capitalizeAscii()
func isHex(s: string): bool = (s.startswith "#") and (s.len == 7)

func toCode(style: BbStyle): string = $ord(style)
func toCode(abbr: BbStyleAbbr): string = abbr.toStyle().toCode()
func toCode(color: ColorXterm): string = "38;5;" & $ord(color)
func toBgCode(color: ColorXterm): string = "48;5;" & $ord(color)
func toCode(c: ColorRgb): string = "38;2;" & $c
func toBgCode(c: ColorRgb): string = "48:2;" & $c
func toCode(c: Color256): string = "38;5;" & $c
func toBgCode(c: Color256): string = "48;5;" & $c

macro enumNames(a: typed): untyped =
  ## unexported macro copied from std/enumutils
  result = newNimNode(nnkBracket)
  for ai in a.getType[1][1..^1]:
    assert ai.kind == nnkSym
    result.add newLit ai.strVal

const ColorXTermNames = enumNames(ColorXterm).mapIt(firstCapital(it))
const BbStyleNames = enumNames(BbStyle).mapIt(firstCapital(it))
const ColorDigitStrings = (1..255).toSeq().mapIt($it)


template parseUnsafe(body: untyped): untyped =
  try: body
  except: discard

proc parseStyle(codes: var seq[string], style: string)  =
  var style = normalizeStyle(style)

  if style in ["B", "I", "U"]:
    parseUnsafe: codes.add parseEnum[BbStyleAbbr](style).toCode()
  elif style in BbStyleNames:
    parseUnsafe: codes.add parseEnum[BbStyle](style).toCode()

  if not (bbMode == On): return

  if style in ColorXtermNames:
    parseUnsafe: codes.add parseEnum[ColorXterm](style).toCode()
  elif style.isHex():
    codes.add style.hexToRgb.toCode()
  elif style in ColorDigitStrings:
    parseUnsafe: codes.add parseInt(style).toCode()
  else:
    when defined(debugBB): echo "unknown style: " & normalizedStyle

func parseBgStyle(codes: var seq[string], style: string) =
    var style = normalizeStyle(style)
    if style in ColorXtermNames:
      parseUnsafe: codes.add parseEnum[ColorXTerm](style).toBgCode()
    elif style.isHex():
      codes.add style.hexToRgb().toBgCode()
    elif style in ColorDigitStrings:
      parseUnsafe: codes.add parseInt(style).toBgCode()
    else:
      when defined(debugBB): echo "unknown bg style: " & style

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
    parseStyle codes, style

  if bbMode == On and bgStyle != "":
    parseBgStyle codes, bgStyle

  if codes.len > 0:
    result.add "\e["
    result.add codes.join ";"
    result.add "m"


func stripAnsi*(s: string): string =
  ## remove all ansi escape codes from a string
  var i: int
  while i < s.len:
    if s[i] == '\e':
      inc i
      if i < s.len and s[i] == '[':
        inc i
        while i < s.len and not (s[i] in {'A'..'Z','a'..'z'}):
          inc i
      else:
        result.add s[i-1]
    else:
      result.add s[i]
    inc i

type
  BbSpan* = object
    styles*: seq[string]
    slice*: array[2, int]

  BbString* = object
    plain*: string
    spans*: seq[BbSpan]

func shift(s: BbSpan, i: Natural): BbSpan =
  result = s
  inc(result.slice[0],i)
  inc(result.slice[1],i)

proc len(span: BbSpan): int =
  span.slice[1] - span.slice[0]

template endSpan(bbs: var BbString) =
  if bbs.spans.len == 0:
    return
  if bbs.plain.len >= 1:
    bbs.spans[^1].slice[1] = bbs.plain.len - 1
  if bbs.spans[^1].len == 0 and bbs.plain.len == 0:
    bbs.spans.delete(bbs.spans.len - 1)

proc newSpan(bbs: var BbString, styles: seq[string] = @[]) =
  bbs.spans.add BbSpan(styles: styles, slice: [bbs.plain.len, 0])

template resetSpan(bbs: var BbString) =
  bbs.endSpan
  bbs.newSpan

template closeLastStyle(bbs: var BbString) =
  bbs.endSpan
  let newStyle = bbs.spans[^1].styles[0 ..^ 2] # drop the latest style
  bbs.newSpan newStyle

template addToSpan(bbs: var BbString, pattern: string) =
  let currStyl = bbs.spans[^1].styles
  bbs.endSpan
  bbs.newSpan currStyl & @[pattern]

template closeStyle(bbs: var BbString, pattern: string) =
  let style = pattern[1 ..^ 1].strip()
  if style in bbs.spans[^1].styles:
    bbs.endSpan
    if bbs.spans.len == 0: return
    let newStyle = bbs.spans[^1].styles.filterIt(it != style) # use sets instead?
    bbs.newSpan newStyle

template closeFinalSpan(bbs: var BbString) =
  if bbs.spans.len >= 1:
    if bbs.spans[^1].slice[0] == bbs.plain.len:
      bbs.spans.delete(bbs.spans.len - 1)
    elif bbs.spans[^1].slice[1] == 0:
      bbs.endSpan

func bb*(s: string): BbString =
  ## convert bbcode markup to ansi escape codes
  var
    pattern: string
    i = 0

  template next() =
    result.plain.add s[i]
    inc i

  template incPattern() =
    pattern.add s[i]
    inc i

  template resetPattern() =
    pattern = ""
    inc i

  if not s.startswith('[') or s.startswith("[["):
    result.spans.add BbSpan()

  while i < s.len:
    case s[i]
    of '\\':
      if i < s.len and (s[i + 1] == '[' or s[i+1] == '\\'):
        inc i
      next
    of '[':
      if i < s.len and s[i + 1] == '[':
        inc i
        next
        continue
      inc i
      while i < s.len and s[i] != ']':
        incPattern
      pattern = pattern.strip()
      if result.spans.len > 0:
        if pattern == "/":
          result.closeLastStyle
        elif pattern == "reset":
          result.resetSpan
        elif pattern.startswith('/'):
          result.closeStyle pattern
        else:
          result.addToSpan pattern
      else:
        result.newSpan @[pattern]
      resetPattern
    else:
      next

  result.closeFinalSpan

proc bb*(s: string, style: string): BbString =
  bb("[" & style & "]" & s & "[/" & style & "]")

proc bb*(s: string, style: Color256): BbString =
  bb(s, $style)

proc bb*(s: BbString): BbString = s

func `&`*(x: BbString, y: string): BbString =
  result = x
  result.plain &= y
  result.spans.add BbSpan(styles: @[], slice: [x.plain.len, result.plain.len - 1])

template bbfmt*(pattern: static string): BbString =
  bb(fmt(pattern))

proc `&`*(x: string, y: BbString): BbString =
  result.plain = x & y.plain
  result.spans.add BbSpan(styles: @[], slice: [0, x.len - 1])
  let i = x.len
  for span in y.spans:
    result.spans.add span.shift(i)

func len*(bbs: BbString): int =
  bbs.plain.len

proc `$`*(bbs: BbString): string =
  if bbMode == Off:
    return bbs.plain

  for span in bbs.spans:
    var codes = ""
    if span.styles.len > 0:
      codes = span.styles.join(" ").toAnsiCode

    result.add codes
    result.add bbs.plain[span.slice[0] .. span.slice[1]]

    if codes != "":
      result.add toAnsiCode("reset")

func align*(bs: BbString, count: Natural, padding = ' '): Bbstring =
  if bs.len < count:
    result = (padding.repeat(count - bs.len)) & bs
  else:
    result = bs

func alignLeft*(bs: BbString, count: Natural, padding = ' '): Bbstring = 
  if bs.len < count:
    result = bs & (padding.repeat(count - bs.len))
  else:
    result = bs

func slice(bs: BbString, span: BbSpan): string =
  bs.plain[span.slice[0]..span.slice[1]]

proc truncate*(bs: Bbstring, len: Natural): Bbstring =
  if bs.len < len: return bs
  for span in bs.spans:
    if span.slice[0] >= len: break
    if span.slice[1] >= len:
      var finalSpan = span
      finalSpan.slice[1] = len - 1
      result.spans.add finalSpan
      result.plain.add bs.slice(finalSpan)
      break
    result.spans.add span
    result.plain.add bs.slice(span)

proc `&`*(x: BbString, y: BbString): Bbstring =
  result.plain.add x.plain
  result.spans.add x.spans
  result.plain.add y.plain
  let i = x.plain.len
  for span in y.spans:
    result.spans.add shift(span, i)

proc bbEscape*(s: string): string {.inline.} = 
  s.replace("[", "[[").replace("\\", "\\\\")

proc bbEcho*(args: varargs[string, `$`]) {.raises: [IOError]} =
  for x in args:
    stdout.write(x.bb)
  stdout.write('\n')
  stdout.flushFile

# NOTE: could move to standlone modules in the tools/ directory
when isMainModule:
  import ./[hwylcli]
  const version = staticExec "git describe --tags --always --dirty=-dev"
  proc showTestCard() =
    for style in [
      "bold", "faint", "italic", "underline", "blink", "reverse", "conceal", "strike"
    ]:
      echo style, " -> ", fmt"[{style}]****".bb
    const colors =
      ["black", "red", "green", "yellow", "blue", "magenta", "cyan", "white"]
    for color in colors:
      echo color, " -> ", fmt"[{color}]****".bb
    for color in colors:
      echo "on ", color, " -> ", fmt"[on {color}]****".bb
    quit(QuitSuccess)

  proc debugBb(bbs: BbString): string =
    echo "bbString("
    echo "  plain: ", bbs.plain
    echo "  spans: ", bbs.spans
    echo "  escaped: ", escape($bbs)
    echo ")"

  hwylCli:
    name "bbansi"
    settings ShowHelp
    usage "[bold]bbansi[/] [[[green]args...[/]] [[[faint]-h|-V[/]]"
    description """
    bbansi "[[yellow] yellow text!"
      -> [yellow] yellow text![/]
    bbansi "[[bold red] bold red text[[/] plain text..."
      -> [bold red] bold red text[/] plain text...
    bbansi "[[red]some red[[/red] but all italic" --style:italic
      -> [italic][red]some red[/red] but all italic[/italic]
    """
    version bbfmt"[yellow]bbansi version[/][red] ->[/] [bold]{version}[/]"
    hidden debug, testCard
    flags:
      debug "show debug"
      testCard "show test card"
      style:
        T string
        ? "set style for string"
        - "s"
    run:
      if testCard: showTestCard()
      for arg in args:
        let styled = arg.bb(style)
        echo styled
        if debug:
          echo debugBb(styled)
