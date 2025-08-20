import std/[math, terminal, strutils, strformat, sequtils]
import ./[bbansi, spin]

type
  ProgressStyle* = object ## Style for progress bar
    initial, final: string  ## complete and incomplete should be equal len
    complete: string
    incomplete: string

  ProgressSegment* = enum
    Bar, Fraction, Percent # Elapsed?

  Progress* = object
    style: ProgressStyle
    current: Natural
    total: Natural
    file: File
    segments: seq[ProgressSegment]

const defaultStyle = ProgressStyle(
    initial: "[",
    final: "]",
    complete: "-",
    incomplete: " ",
)

proc renderFraction(p: Progress): string =
  let pad = ($p.total).len
  result.add " "
  result.add align($p.current, pad)
  result.add "/"
  result.add $p.total
  result.add " "

proc renderPercent(p: Progress): string =
  let perc = p.current / p.total * 100.0
  fmt" {perc:.2f} "

proc renderBar(p: Progress, width: Natural): string =
  assert width > 2
  let innerWidth = width - 2
  let nPieces = int(p.current / p.total * innerWidth.float)
  result.add p.style.initial
  result.add p.style.complete.repeat(nPieces)
  result.add p.style.incomplete.repeat(innerWidth - nPieces)
  result.add p.style.final

proc renderSegment(p: Progress, width: Natural, segment: ProgressSegment): string =
  case segment
  of Bar: renderBar(p, width)
  of Fraction: renderFraction(p)
  of Percent: renderPercent(p)

proc render(p: Progress, width: Natural): string =
  if p.segments.len == 1:
    return renderSegment(p, width, p.segments[0])

  var rendered = newSeq[string](p.segments.len)
  var barIdx = 0
  for i, segment in p.segments:
    if segment == Bar:
      barIdx = i
      continue
    rendered[i] = renderSegment(p, width, segment)

  if Bar in p.segments:
    let remaining = mapIt(rendered, it.len).sum()
    rendered[barIdx] = renderBar(p, width - remaining)

  for r in rendered:
    result.add r

proc newProgress*(
  total: int = 0,
  style: ProgressStyle = defaultStyle,
  segments: openArray[ProgressSegment] = @[Bar]
): Progress =
  result.style = style
  result.total = total
  result.file = hwylConsole.file
  result.segments = @segments

proc inc*(p: var Progress, v: Natural = 1) {.inline.} =
  inc p.current

iterator progress*[T](p: var Progress, spinner: var Spinny, items: openArray[T]): T =
  if p.total == 0:
    p.total = items.len

  useSpinner(spinner):

    for i in items:
      spinner.setText(bbEscape(p.render(terminalWidth() - spinner.symbolPad)))
      inc p
      yield i

    if p.current < p.total:
      inc p
      spinner.setText(bbEscape(p.render(terminalWidth() - spinner.symbolPad)))

iterator progress*[T](p: var Progress, items: openArray[T]): T =
  var spinner = newSpinny("")
  for i in progress(p, spinner, items):
    yield i

iterator progress*[T](spinner: var Spinny, items: openArray[T]): T =
  var p = newProgress(items.len)
  for i in progress(p, spinner, items):
    yield i

iterator progress*[T](items: openArray[T]): T =
  var spinner = newSpinny("")
  for i in progress(spinner, items):
    yield i

when isMainModule:
  import std/[os]
  # for i in progress((1..100).toSeq()):
  #   sleep 200

  var pb = newProgress(segments = @[Bar, Fraction])
  for i in pb.progress((1..100).toSeq()):
    sleep 100

