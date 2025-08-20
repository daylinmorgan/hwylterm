# TODO: better integrate console with spinner
import std/[os, locks, sequtils, strutils, terminal]
import ./bbansi
import ./spin/spinners
export spinners

type
  Spinny* = ref object
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

  SpinnyEvent = object
    kind: EventKind
    payload: BbString

var spinnyChannel: Channel[SpinnyEvent]

const defaultSpinnerKind* =
  block:
    const defaultSpinner {.strdefine.} = "Dots2" # I prefer Dots2 ¯\_(ツ)_/¯ 
    parseEnum[SpinnerKind](defaultSpinner)

proc newSpinny*(text: Bbstring, s: Spinner): Spinny =
  let style = "bold blue"
  result = Spinny(
    text: text,
    # running: true,
    frames: s.frames,
    bbFrames: mapIt(s.frames, bb(bbEscape(it), style)),
    customSymbol: false,
    interval: s.interval,
    style: style,
    file: hwylConsole.file,
  )

proc newSpinny*(text: string, s: Spinner): Spinny =
  newSpinny(bb(text), s)

proc newSpinny*(text: string | Bbstring, spinType: SpinnerKind = defaultSpinnerKind): Spinny =
  newSpinny(text, Spinners[spinType])

proc setSymbolColor*(spinny: Spinny, style: string) =
  if not spinny.running: return
  spinny.bbFrames = mapIt(spinny.frames, bb(bbEscape(it), style))

proc setSymbol*(spinny: Spinny, symbol: string) =
  if not spinny.running: return
  spinnyChannel.send(SpinnyEvent(kind: SymbolChange, payload: bb(symbol)))

proc setText*(spinny: Spinny, text: string | BbString) =
  if not spinny.running: return
  spinnyChannel.send(SpinnyEvent(kind: TextChange, payload: bb(text)))

proc echo*(spinny: Spinny, text: string | BbString) =
  spinnyChannel.send(SpinnyEvent(kind: Echo, payload: bb(text)))

proc spinnyLoop(spinny: Spinny) {.thread.} =
  var frameCounter = 0
  var lastTextEvent: BbString # Variable to hold the last text change

  while spinny.running:
    var textUpdatePending = false
    while true:
      let (dataAvailable, msg) = spinnyChannel.tryRecv()
      if not dataAvailable:
        break # Channel is empty, exit the drain loop

      # Process all events in the channel
      case msg.kind
      of Stop:
        # A Stop event should immediately stop the spinner
        spinnyChannel.close()
        spinnyChannel = default(typeof(spinnyChannel))
        spinny.running = false
        return # Use `return` to exit the thread immediately
      of SymbolChange:
        spinny.customSymbol = true
        spinny.frame = msg.payload
      of TextChange:
        # We only care about the last text change, so we store it
        lastTextEvent = msg.payload
        textUpdatePending = true
      of Echo:
        withLock spinny.lock:
            eraseLine spinny.file
            writeLine spinny.file, $(msg.payload)
            flushFile spinny.file

    # After draining the channel, apply the last pending text change
    if textUpdatePending:
      spinny.text = lastTextEvent

    withLock spinny.lock:
      flushFile spinny.file

    if not spinny.customSymbol:
      spinny.frame = spinny.bbFrames[frameCounter]

    # TODO: instead of truncating support multiline text, need custom wrapping and cleanup then
    withLock spinny.lock:
      eraseLine spinny.file
      spinny.file.write hwylConsole.toString((spinny.frame & " " & spinny.text).truncate(terminalWidth())) # needs to be truncated
      flushFile spinny.file

    sleep spinny.interval

    if frameCounter >= spinny.frames.len - 1:
      frameCounter = 0
    else:
      frameCounter += 1

proc start*(spinny: Spinny) =
  initLock spinny.lock
  spinny.running = true
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
    try:
      start spinner
      body
    finally:
      stop spinner
  else:
    body

template withSpinner*(msg: string = "", body: untyped): untyped =
  block:
    var spinner {.inject.} = newSpinny(msg, defaultSpinnerKind)
    useSpinner(spinner, body)

template withSpinner*(msg: BbString = bb"", body: untyped): untyped =
  block:
    var spinner {.inject.} = newSpinny(msg, defaultSpinnerKind)
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
  var delay = 1000
  let params = commandLineParams()
  if params.len > 0: delay = parseInt(params[0])
  for kind, _ in Spinners:
    with(kind, $kind):
      echo spinner, $kind
      sleep 1 * delay
