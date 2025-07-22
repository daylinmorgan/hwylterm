import std/[os, locks, sequtils, strutils, terminal]
import "."/[bbansi, spin/spinners]
export spinners

type
  Spinny = ref object
    t: Thread[Spinny]
    lock: Lock
    text: BbString
    running: bool
    frames: seq[string]
    bbFrames: seq[BbString]
    frame: BbString
    interval: int
    customSymbol: bool
    style: string
    file: File

  EventKind = enum
    Stop
    SymbolChange
    TextChange
    Echo
    Write

  SpinnyEvent = object
    kind: EventKind
    payload: BbString

var spinnyChannel: Channel[SpinnyEvent]

proc newSpinny*(text: Bbstring, s: Spinner): Spinny =
  let style = "bold blue"
  Spinny(
    text: text,
    running: true,
    frames: s.frames,
    bbFrames: mapIt(s.frames, bb(bbEscape(it), style)),
    customSymbol: false,
    interval: s.interval,
    style: style,
    file: stderr,
  )

proc newSpinny*(text: string, s: Spinner): Spinny =
  newSpinny(bb(text), s)

proc newSpinny*(text: string | Bbstring, spinType: SpinnerKind): Spinny =
  newSpinny(text, Spinners[spinType])

proc setSymbolColor*(spinny: Spinny, style: string) =
  spinny.bbFrames = mapIt(spinny.frames, bb(bbEscape(it), style))

proc setSymbol*(spinny: Spinny, symbol: string) =
  spinnyChannel.send(SpinnyEvent(kind: SymbolChange, payload: bb(symbol)))

proc setText*(spinny: Spinny, text: string | BbString) =
  spinnyChannel.send(SpinnyEvent(kind: TextChange, payload: bb(text)))

proc echo*(spinny: Spinny, text: string | BbString) =
  spinnyChannel.send(SpinnyEvent(kind: Echo, payload: bb(text)))

proc write*(spinny: Spinny, text: string | BbString) =
  spinnyChannel.send(SpinnyEvent(kind: Write, payload: bb(text)))

proc spinnyLoop(spinny: Spinny) {.thread.} =
  var frameCounter = 0

  while spinny.running:
    let (dataAvailable, msg) = spinnyChannel.tryRecv()
    if dataAvailable:
      case msg.kind
      of Stop:
        spinnyChannel.close()
        # This is required so we can reopen the same channel more than once
        # See https://github.com/nim-lang/Nim/issues/6369
        # is this still required?
        spinnyChannel = default(typeof(spinnyChannel))
        spinny.running = false
        break
      of SymbolChange:
        spinny.customSymbol = true
        spinny.frame = msg.payload
      of TextChange:
        spinny.text = msg.payload
      # TODO: combine echo/write with sensible 'File abstraction'
      of Echo:
        eraseLine spinny.file
        flushFile spinny.file
        writeLine(stdout, $msg.payload)
        flushFile stdout
      of Write:
        eraseLine spinny.file
        flushFile spinny.file
        writeLine spinny.file, $msg.payload

    flushFile spinny.file
    if not spinny.customSymbol:
      spinny.frame = spinny.bbFrames[frameCounter]

    # TODO: instead of truncating support multiline text, need custom wrapping and cleanup then
    withLock spinny.lock:
      eraseLine spinny.file
      spinny.file.write $((spinny.frame & " " & spinny.text).truncate(terminalWidth())) # needs to be truncated
      flushFile spinny.file

    sleep spinny.interval

    if frameCounter >= spinny.frames.len - 1:
      frameCounter = 0
    else:
      frameCounter += 1

proc start*(spinny: Spinny) =
  initLock spinny.lock
  spinnyChannel.open()
  createThread(spinny.t, spinnyLoop, spinny)

proc stop(spinny: Spinny, kind: EventKind, payload = "") =
  spinnyChannel.send(SpinnyEvent(kind: kind, payload: bb(payload)))
  spinnyChannel.send(SpinnyEvent(kind: Stop))
  joinThread spinny.t
  eraseLine spinny.file
  deinitLock spinny.lock
  flushFile spinny.file

proc stop*(spinny: Spinny) =
  spinny.stop(Stop)

template useSpinner(spinner: Spinny, body: untyped) =
  # NOTE: it it necessary to inject the spinner here?
  if isatty(spinner.file): # don't spin if it's not a tty
    proc echo(x: varargs[string, `$`]) =
      spinner.echo(x.join(""))
    try:
      start spinner
      body
    finally:
      stop spinner
  else:
    body

template withSpinner*(msg: string = "", body: untyped): untyped =
  block:
    var spinner {.inject.} = newSpinny(msg, Dots)
    useSpinner(spinner, body)

template withSpinner*(msg: BbString = bb"", body: untyped): untyped =
  block:
    var spinner {.inject.} = newSpinny(msg, Dots)
    useSpinner(spinner, body)

template withSpinner*(body: untyped): untyped =
  withSpinner("", body)

template with*(kind: SpinnerKind, msg: string, body: untyped): untyped =
  block:
    var spinner {.inject.} = newSpinny(msg, kind)
    useSpinner(spinner, body)

template with*(kind: SpinnerKind, msg: BbString, body: untyped): untyped =
  block:
    var spinner {.inject.} = newSpinny(msg, kind)
    useSpinner(spinner, body)

when isMainModule:
  for kind, _ in Spinners:
    with(kind, $kind):
      echo $kind
      sleep 1 * 1000
