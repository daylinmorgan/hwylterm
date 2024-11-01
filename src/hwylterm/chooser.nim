##[
  # Hwylterm Chooser

  ```nim
  import hwylterm/chooser

  let items = ["a","b","c"]
  let item = choose(items)
  ```
]##

import std/[enumerate, os, strutils, sequtils, sets, terminal]
import ./bbansi
import ./vendor/illwill

proc exitProc() {.noconv.} =
  illwillDeInit()
  showCursor()

proc quitProc() {.noconv.} =
  exitProc()
  quit(0)

type
  State = object
    lastKey: Key
    buffer: string
    selections: HashSet[Natural]
    height, max, pos, low, high: Natural

func newState[T](things: openArray[T], height: Natural): State =
  result.max = len(things) - 1
  result.height = height
  result.high = min(result.max,height)

func up(s: var State) =
  if s.pos > 0: dec s.pos
  if (s.pos < s.low):
      dec s.low
      dec s.high

func down(s: var State) =
  if s.pos < s.max:
    inc s.pos
  if ((s.pos - s.low) > s.height) and
     (s.pos > s.high) and
     (s.high < s.max):
      inc s.low
      inc s.high

func pressed(s: var State, k: Key) = s.lastKey = k
func select(s: var State ) =
  s.selections =
    symmetricDifference(s.selections, toHashSet([s.pos]))

func clip(s: string, length: int): string =
  if s.len > length: s[0..length]
  else: s

func prefix(state: State, i: int): string =
  result.add (
      if (i + state.low) == state.pos: ">"
      else: " "
  )
  result.add (
      if (i + state.low) in state.selections: ">"
      else: " "
  )

func addThingsWindow[T](state: var State, things: openArray[T]) =
  var window: string
  for i, t in enumerate(things[state.low..state.high]):
    window.add prefix(state, i)
    window.add $t
    window.add "\n"
  state.buffer.add window


proc draw(s: var State) =
  let maxWidth = terminalWidth()
  var lines= (
    s.buffer.splitLines().mapIt(("  " & it).clip(maxWidth).alignLeft(maxWidth))
  )
  when defined(debugChoose):
    lines = @[$s] & lines

  for l in lines:
    stdout.writeLine l

  cursorUp lines.len
  flushFile stdout
  s.buffer = ""

func getSelections[T](state: State, things: openArray[T]): seq[T] =
  if state.selections.len == 0:
    result.add things[state.pos]
  for i in state.selections:
    result.add things[i]


proc choose*[T](things: openArray[T], height: Natural = 6): seq[T] =
  illwillInit(fullscreen = false)
  setControlCHook(quitProc)
  hideCursor()

  var state = newState(things, height)

  while true:
    var key = getKey()
    pressed(state, key)
    case key:
    of Key.None: discard
    of Key.Down, Key.J:
      down state
    of Key.Up, Key.K:
      up state
    of Key.Tab:
      select state
    of Key.Enter:
      exitProc()
      return getSelections(state, things)
    else: discard

    addThingsWindow(state, things)
    draw state
    sleep 20


when isMainModule:
  import ./[hwylcli]
  hwylcli:
    name "hwylchoose"
    settings NoArgsShowHelp
    usage "[bold]hwylchoose[/] [[[green]args...[/]] [[[faint]-h[/]]"
    description """
    hwylchoose a b c d
    hwylchoose a,b,c,d -s ,
    hwylchoose a,b,c,d --seperator ","
    hwylchoose --demo
    """
    hidden demo
    flags:
      demo:
        T bool
      separator:
        help "separator to split items"
        short "s"
    run:
      var items: seq[string]
      if demo:
        items &= LowercaseLetters.toSeq().mapIt($it)
      else:
        if separator != "":
          if args.len != 1: quit "only pass one positional arg when using --separator"
          items = args[0].split(separator).mapIt(strip(it))
        else:
          items = args

      let item = choose(items)
      echo "selected: ", item



