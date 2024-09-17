import std/[os, locks, sequtils, terminal]
import "."/bbansi

type
  SpinnerKind* = enum
    Dots

  Spinner* = object
    interval*: int
    frames*: seq[string]

proc makeSpinner*(interval: int, frames: seq[string]): Spinner =
  Spinner(interval: interval, frames: frames)

const Spinners*: array[SpinnerKind, Spinner] = [
  # Dots
  Spinner(
    interval: 80,
    frames: @["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"],
  )
]

type
  Spinny = ref object
    t: Thread[Spinny]
    lock: Lock
    text: string
    running: bool
    frames: seq[string]
    frame: string
    interval: int
    customSymbol: bool
    style: string

  EventKind = enum
    Stop
    SymbolChange
    TextChange

  SpinnyEvent = object
    kind: EventKind
    payload: string

var spinnyChannel: Channel[SpinnyEvent]

proc newSpinny*(text: string, s: Spinner): Spinny =
  let style = "bold blue"
  Spinny(
    text: text,
    running: true,
    frames: mapIt(s.frames, $bb(it, style)),
    customSymbol: false,
    interval: s.interval,
    style: "bold blue",
  )

proc newSpinny*(text: string, spinType: SpinnerKind): Spinny =
  newSpinny(text, Spinners[spinType])

proc setSymbolColor*(spinny: Spinny, style: string) =
  spinny.frames = mapIt(spinny.frames, $bb(it, style))

proc setSymbol*(spinny: Spinny, symbol: string) =
  spinnyChannel.send(SpinnyEvent(kind: SymbolChange, payload: symbol))

proc setText*(spinny: Spinny, text: string) =
  spinnyChannel.send(SpinnyEvent(kind: TextChange, payload: text))

proc handleEvent(spinny: Spinny, eventData: SpinnyEvent): bool =
  result = true
  case eventData.kind
  of Stop:
    result = false
  of SymbolChange:
    spinny.customSymbol = true
    spinny.frame = eventData.payload
  of TextChange:
    spinny.text = eventData.payload

proc spinnyLoop(spinny: Spinny) {.thread.} =
  var frameCounter = 0

  while spinny.running:
    let data = spinnyChannel.tryRecv()
    if data.dataAvailable:
      # If we received a Stop event
      if not spinny.handleEvent(data.msg):
        spinnyChannel.close()
        # This is required so we can reopen the same channel more than once
        # See https://github.com/nim-lang/Nim/issues/6369
        spinnyChannel = default(typeof(spinnyChannel))
        # TODO: Do we need spinny.running at all?
        spinny.running = false
        break

    stdout.flushFile()
    if not spinny.customSymbol:
      spinny.frame = spinny.frames[frameCounter]

    withLock spinny.lock:
      eraseLine()
      stdout.write(spinny.frame & " " & spinny.text)
      stdout.flushFile()

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
  spinnyChannel.send(SpinnyEvent(kind: kind, payload: payload))
  spinnyChannel.send(SpinnyEvent(kind: Stop))
  joinThread spinny.t
  eraseLine stdout
  flushFile stdout

proc stop*(spinny: Spinny) =
  spinny.stop(Stop)

template withSpinner*(msg: string = "", body: untyped): untyped =
  var spinner {.inject.} = newSpinny(msg, Dots)
  if isatty(stdout): # don't spin if it's not a tty
    start spinner

  body

  if isatty(stdout):
    stop spinner

template withSpinner*(body: untyped): untyped =
  withSpinner("", body)
