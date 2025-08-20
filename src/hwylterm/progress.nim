import std/[math, terminal, strutils,]
import ./[bbansi, spin]

type
  ProgressBarStyle* = object ## Style for progress bar
    initial, final: string  ## complete and incomplete should be equal len
    complete: string
    incomplete: string

  ProgressBar* = object
    style: ProgressBarStyle
    current: Natural
    total: Natural
    file: File

const defaultStyle = ProgressBarStyle(
    initial: "[",
    final: "]",
    complete: "-",
    incomplete: " ",
)

proc newProgressBar*(
  total: int = 0,
  style: ProgressBarStyle = defaultStyle
): ProgressBar =
  result.style = style
  result.total = total
  result.file = hwylConsole.file

proc toString*(p: ProgressBar, w: Natural): string =
  ## progress bar will extend to size of screen
  assert w > 2
  let innerWidth = w - 2
  let nPieces = int(p.current / p.total * innerWidth.float)
  result.add p.style.initial
  result.add p.style.complete.repeat(nPieces)
  result.add p.style.incomplete.repeat(innerWidth - nPieces)
  result.add p.style.final

proc inc*(p: var ProgressBar, v: Natural = 1) {.inline.} =
  inc p.current

iterator progress*[T](pb: var ProgressBar, spinner: var Spinny, items: openArray[T]): T =
  if pb.total == 0:
    pb.total = items.len

  useSpinner(spinner):

    for i in items:
      spinner.setText(bbEscape(pb.toString(terminalWidth() - spinner.symbolPad)))
      inc pb
      yield i

    if pb.current < pb.total:
      inc pb
      spinner.setText(bbEscape(pb.toString(terminalWidth() - spinner.symbolPad)))


iterator progress*[T](spinner: var Spinny, items: openArray[T]): T =
  var pb = newProgressBar(items.len)
  for i in progress(pb, spinner, items):
    yield i

iterator progress*[T](items: openArray[T]): T =
  var spinner = newSpinny("")
  for i in progress(spinner, items):
    yield i

when isMainModule:
  import std/[os, sequtils]
  for i in progress((1..100).toSeq()):
    sleep 200

  # var pb = newProgressBar()
  # for i in pb.progress((1..100).toSeq()):
    # echo pb, i
    # sleep 100

