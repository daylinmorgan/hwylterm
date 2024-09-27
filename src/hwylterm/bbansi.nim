##[
  ## bbansi

  use BB style markup to add color to strings using VT100 escape codes
]##

import std/[os, sequtils, strformat, strutils]
import ./bbansi/[styles, utils, colors]
export utils

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

proc `&`*(x: BbString, y: string): BbString =
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

proc bbEcho*(args: varargs[string, `$`]) {.sideEffect.} =
  for x in args:
    stdout.write(x.bb)
  stdout.write('\n')
  stdout.flushFile

when isMainModule:
  import std/[parseopt, sugar]
  const version = staticExec "git describe --tags --always --dirty=-dev"
  const longOptPad = 8
  const flags = collect(
    for (s, l, d) in [
      ("h", "help", "show this help"),
      ("v", "version", "show version"),
      ("s", "style", "set style for string"),
    ]:
      fmt"  [yellow]-{s}[/]  [green]--{l.alignLeft(longOptPad)}[/] {d}"
    ).join("\n")
  proc writeHelp() =
    let help =
      bbfmt"""
[bold]bbansi[/] \[[green]args...[/]] [[[faint]-h|-v[/]]

[italic]usage[/]:
  bbansi "[[yellow] yellow text!"
    |-> [yellow] yellow text![/]
  bbansi "[[bold red] bold red text[[/] plain text..."
    |-> [bold red] bold red text[/] plain text...
  bbansi "[[red]some red[[/red] but all italic" --style:italic
    |-> [italic][red]some red[/red] but all italic[/italic]

flags:
{flags}
"""
    echo help; quit 0

  proc testCard() =
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

  proc debug(bbs: BbString): string =
    echo "bbString("
    echo "  plain: ", bbs.plain
    echo "  spans: ", bbs.spans
    echo "  escaped: ", escape($bbs)
    echo ")"

  proc writeVersion() =
    echo bbfmt"[yellow]bbansi version[/][red] ->[/] [bold]{version}[/]"
    quit 0

  var
    strArgs: seq[string]
    style: string
    showDebug: bool
  var p = initOptParser()
  for kind, key, val in p.getopt():
    case kind
    of cmdEnd:
      break
    of cmdShortOption, cmdLongOption:
      case key
      of "help", "h":
        writeHelp()
      of "version", "v":
        writeVersion()
      of "testCard":
        testCard()
        quit(QuitSuccess)
      of "style", "s":
        if val == "":
          echo "[red]ERROR[/]: expected value for -s/--style".bb
          quit(QuitFailure)
        style = val
      of "debug":
        showDebug = true
      else:
        echo bb"[yellow]warning[/]: unexpected option/value -> ", key, ", ", val
    of cmdArgument:
      strArgs.add key
  if strArgs.len == 0:
    writeHelp()
  for arg in strArgs:
    let styled =
      if style != "":
        arg.bb(style)
      else:
        arg.bb
    echo styled
    if showDebug:
      echo debug(styled)
