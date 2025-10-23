##[
  # HwylCli

  ## example program:

  ```nim
  import std/[strutils]
  import hywlterm/hwylcli

  hwylCli:
    name "example"
    flags:
      count:
        ? "# of times"
        - n
      input:
        ? "content"
        - i
    run:
      echo (input & " ").repeat(count)
  ```

  ```
  $ example -n 2 --input "testing"
  > testing testing
  ```

  For more example programs see the [tests directory](https://github.com/daylinmorgan/hwylterm/tree/main/tests/cli/clis).
]##

import std/[
  algorithm,
  macros, os, sequtils,
  sets, strutils, strformat, tables,
  sugar
]
import ./[bbansi, parseopt3]
export parseopt3, sets, bbansi


type
  HwylCliStyleSetting* = enum
    Aliases,    ## show aliases, example "show (s)"
    Required,   ## indicate if flag is required
    Defaults,   ## show default value
    Types,      ## show expected type for flag
    FlagGroups, ## group flags together
    NoEnv,      ## ignore env settings for style

const defaultStyleSettings* = [Aliases, Required, Defaults, Types].toHashSet()

type
  HwylFlagHelp* = tuple[
    short, long, description, typeRepr, defaultVal, group: string; required: bool,
  ]
  HwylSubCmdHelp* = tuple[
    name, aliases, desc: string
  ]

  BuiltinStyleKind* = enum
    AllSettings,  ## Use all help settings (besides NoEnv)
    Minimal,      ## Use no extra help settings
    WithoutColor, ## Default help settings without color
    WithoutAnsi,  ## Default help settings without color or styling

  HwylCliStyles* = object
    name* = "bold"
    header* = "bold cyan"
    flagShort* = "yellow"
    flagLong* = "magenta"
    flagDesc* = ""
    default* = "faint"
    required* = "red"
    subcmd* = "bold"
    args* = "bold italic"
    typeRepr = "faint"
    minCmdLen* = 8
    settings*: HashSet[HwylCliStyleSetting] = defaultStyleSettings

  HwylCliLengths = object
    subcmd*, subcmdDesc*, shortArg*, longArg*, descArg*, typeRepr*, defaultVal*: int

  HwylCliHelp* = object
    header*, footer*, description*, usage*: string
    subcmds*: seq[HwylSubCmdHelp]
    flags*: seq[HwylFlagHelp]
    styles*: HwylCliStyles
    lengths*: HwylCliLengths
    longHelp*: bool

func `+`*[T](a: HashSet[T], b: set[T]): HashSet[T] =
  a + toSeq(b).toHashSet()

func `-`*[T](a: HashSet[T], b: set[T]): HashSet[T] =
  a - toSeq(b).toHashSet()

# NOTE: do i need both strips?
func firstLine(s: string): string =
  s.strip().dedent().strip().splitlines()[0]

func newHwylCliStyles*(
    name = "bold",
    header = "bold cyan",
    flagShort = "yellow",
    flagLong = "magenta",
    flagDesc = "",
    default = "faint",
    required = "red",
    subcmd = "bold",
    args = "bold italic",
    typeRepr = "faint",
    minCmdLen = 8,
    settings: HashSet[HwylCliStyleSetting] = defaultStyleSettings,
): HwylCliStyles =

  template `*`(field: untyped): untyped =
    result.field = field

  *name
  *header
  *flagShort
  *flagLong
  *flagDesc
  *default
  *required
  *subcmd
  *args
  *typeRepr
  *args
  *minCmdLen
  *settings

  # style parsing should be a more detailed hwylCliError
  if NoEnv notin settings:
    template setEnvVal(k: string, val: untyped): untyped =
      val = getEnv("HWYLCLISTYLES_" & k.toUpperAscii(), val)
    for key, val in result.fieldPairs:
      when key == "minCmdLen":
        # NOTE: shouldnt need to parse twice...
        let envVal = getEnv("HWYLCLISTYLES_MINCMDLEN")
        if envVal != "":
          val = parseInt(envVal)
      elif key == "settings":
        let envVal = getEnv("HWYLCLISTYLES_SETTINGS")
        if envVal != "":
          val = envVal.split(",").mapIt(parseEnum[HwylCliStyleSetting](it)).toHashSet()
      when key notin ["settings", "minCmdLen"]:
        setEnvVal(key, val)

func fromBuiltinHelpStyles*(kind: BuiltinStyleKind): HwylCliStyles =
  case kind
  of AllSettings: newHwylCliStyles(settings =  defaultStyleSettings + {FlagGroups})
  of Minimal: newHwylCliStyles(settings = initHashSet[HwylCliStyleSetting]())
  of WithoutColor: newHwylCliStyles(header= "bold", flagShort= "", flagLong= "", required= "")
  of WithoutAnsi: newHwylCliStyles(name= "", header= "", flagShort= "", flagLong= "", default= "", required= "", subcmd= "", args="", typeRepr= "")

func withHelpSettings*(
  settings: set[HwylCliStyleSetting] | HashSet[HwylCliStyleSetting]
): HwylCliStyles =
  let settings =
    when settings is set[HwylCliStyleSetting]:
      settings.toSeq().toHashSet()
    else: settings

  result = newHwylCliStyles(
    settings = settings
  )



func newHwylCliHelp*(
  usage = "",
  header = "",
  footer = "",
  description = "",
  subcmds: openArray[HwylSubCmdHelp] = @[],
  flags: openArray[HwylFlagHelp] = @[],
  styles = HwylCliStyles(),
  longHelp = false,
): HwylCliHelp =
  result.header = dedent(header).strip()
  result.footer = dedent(footer).strip()
  result.description = dedent(description).strip()
  if Aliases in styles.settings:
    # TODO: subcmds should use long help?
    result.subcmds =
      subcmds.mapIt((it.name & " " & it.aliases, it.aliases, it.desc.firstLine))
  else:
    result.subcmds =
      subcmds.mapIt((it.name, it.aliases, it.desc.firstLine))
  result.usage = dedent(usage).strip()
  result.flags = @flags
  result.styles = styles
  result.lengths.subcmd = styles.minCmdLen
  result.longHelp = longHelp

  for f in flags:
    # template?
    result.lengths.shortArg = max(result.lengths.shortArg, f.short.len)
    result.lengths.longArg  = max(result.lengths.longArg, f.long.len)
    result.lengths.descArg  = max(result.lengths.descArg, f.description.len)

    result.lengths.defaultVal  = max(result.lengths.defaultVal, f.defaultVal.len)

    # using "bb" before len.. to squash out the escaped [[
    result.lengths.typeRepr = max(result.lengths.typeRepr, f.typeRepr.bb.len)

  for s in result.subcmds:
    result.lengths.subcmd = max(result.lengths.subcmd, s.name.len)
    result.lengths.subcmdDesc = max(result.lengths.subcmdDesc, s.desc.len)


# break this up
func render*(cli: HwylCliHelp, f: HwylFlagHelp): string =
  # TODO: add wrapping for TerimnalWidth? need wrapWords supporting bbMarkup and bbAnsi string

  result.add " "
  if f.short != "":
    result.add ("-" & f.short.alignLeft(cli.lengths.shortArg)).bbMarkup(cli.styles.flagShort)
  else:
    result.add " ".repeat(1 + cli.lengths.shortArg)

  result.add " "
  if cli.longHelp:
    if f.long != "":
      result.add ("--" & f.long).bbMarkup(cli.styles.flagLong)
  else:
    if f.long != "":
      result.add ("--" & f.long.alignLeft(cli.lengths.longArg)).bbMarkup(cli.styles.flagLong)
    else:
      result.add " ".repeat(2 + cli.lengths.longArg)

  if Types in cli.styles.settings:
    result.add " "
    if cli.longHelp:
      if f.typeRepr != "":
        result.add f.typeRepr.bbMarkup(cli.styles.typeRepr)
    else:
      if f.typeRepr != "":
        let offset = int(
          # BUG alignLeft isn't accounting for these '[['
          (f.typeRepr.len - f.typeRepr.replace("[[","").len) / 2
        )
        result.add f.typeRepr
          .alignLeft(
            cli.lengths.typeRepr + offset
          )
          .bbMarkup(cli.styles.typeRepr)
      else:
        result.add " ".repeat(cli.lengths.typeRepr)

  if not cli.longHelp:
    result.add " "

  if cli.longHelp:
    if f.defaultVal != "" and Defaults in cli.styles.settings:
      result.add " "
      result.add ("(default: " & f.defaultVal & ")")
        .bbMarkup(cli.styles.default)

    if f.required and Required in cli.styles.settings:
      result.add " "
      result.add "(required)".bbMarkup(cli.styles.required)

    let indentLen = 8

    if f.description != "":
      result.add "\n"
      result.add f.description.dedent().indent(indentLen) #

  else:
    if f.description != "":
      result.add f.description.splitLines().toSeq()[0].dedent().bbMarkup(cli.styles.flagDesc)

    if f.defaultVal != "" and Defaults in cli.styles.settings:
      result.add " "
      result.add ("(default: " & f.defaultVal & ")")
        .bbMarkup(cli.styles.default)

    if f.required and Required in cli.styles.settings:
      result.add " "
      result.add "(required)".bbMarkup(cli.styles.required)

func render*(cli: HwylCliHelp, subcmd: HwylSubCmdHelp): string =
  result.add "  "
  result.add subcmd.name.alignLeft(cli.lengths.subcmd).bbMarkup(cli.styles.subcmd)
  result.add " "
  result.add subcmd.desc.alignLeft(cli.lengths.subcmdDesc)

func renderFlags(cli: HwylCliHelp, flags: seq[HwylFlagHelp]): string =
  flags.mapIt(render(cli, it)).join("\n")

func flagsByGroup(flags: seq[HwylFlagHelp]): Table[string, seq[HwylFlagHelp]] =
  for flag in flags:
    let g = if flag.group.startsWith("_"): "" else: flag.group
    if result.hasKeyOrPut(g, @[flag]):
      result[g].add flag

func cmpFlagGroups(a, b: string): int =
  if a == "": return -1
  if b == "": return 1
  if a == "global": return 1
  if b == "global": return -1
  return cmp(a, b)

proc render*(cli: HwylCliHelp, flags: seq[HwylFlagHelp]): string =
  if FlagGroups notin cli.styles.settings:
    result.add "flags".bbMarkup(cli.styles.header)
    result.add ":\n"
    result.add renderFlags(cli, flags)
  else:
    let grouped = flagsByGroup(flags)
    let groups = grouped.keys().toSeq().sorted(cmpFlagGroups)
    for i, grp in groups:
      if i != 0: result.add "\n\n"
      let flags = grouped[grp]
      if grp != "":
        result.add fmt"{grp} flags".bbMarkup(cli.styles.header)
      else:
        result.add fmt"flags".bbMarkup(cli.styles.header)
      result.add ":\n"
      result.add renderFlags(cli, flags)

template render*(cli: HwylCliHelp): string =
  var parts: seq[string]

  if cli.header != "":
    parts.add cli.header
  if cli.usage != "":
    parts.add "usage".bbMarkup(cli.styles.header) & ":\n" & indent(cli.usage, 2 )
  if cli.description != "":
    parts.add cli.description
  if cli.subcmds.len > 0:
    parts.add "subcommands".bbMarkup(cli.styles.header) & ":\n" & cli.subcmds.mapIt(render(cli,it)).join("\n")
  if cli.flags.len > 0:
    parts.add render(cli, cli.flags)
  if cli.footer != "":
    parts.add cli.footer

  parts.join("\n\n")


proc bb*(cli: HwylCliHelp): BbString =
  result = bb(render(cli))


type
  Count* = object ## Count type for an incrementing flag
    val*: int
  KV*[X,Y] = object ## basic key value type
    key*: X
    val*: Y
  KVString* = KV[string, string]


iterator items*[X,Y](kvs: seq[KV[X,Y]]): (X, Y) =
  var i = 0
  while i < kvs.len:
    let kv = kvs[i]
    yield (kv.key, kv.val)
    inc i

proc `$`*(t: typedesc[KVString]): string =
  result.add "k(string):v(string)"

proc `$`*[X,Y](t: typedesc[KV[X, Y]]): string =
  result.add "k(" & $X & ")"
  result.add ":"
  result.add "v(" & $Y & ")"

proc `$`[X,Y](t: typedesc[seq[KV[X,Y]]]): string =
  "seq[" & $(KV[X,Y]) & "]"

proc `$`(c: Count): string = $c.val


# ----------------------------------------

type
  CliSetting* = enum
    IgnoreParent  ## Don't propagate parent settings to subcommands
    GenerateOnly, ## Don't attach root `runProc()` node
    NoHelpFlag,   ## Remove the builtin help flag
    ShowHelp,     ## If cmdline empty show help
    LongHelp,     ## Show more info with --help than -h
    NoNormalize,  ## Don't normalize flags and commands
    HideDefault,  ## Don't show default values
    InferShort    ## Autodefine short flags
    InferEnv      ## Autodefine env vars for flags

  CliFlagSetting* = enum
    HideDefault,   ## Don't show default values
    NoShort,       ## Counter option to Parent's InferShort
    NoEnv,         ## Counter option to Parent's InferEnv
    Required,      ## Flag must be used (or have default value)

  BuiltinFlag = object
    name*: string
    short*: char
    long*: string
    help*: NimNode
    node: NimNode
    defaultVal: NimNode
    settings*: HashSet[CliFlagSetting]

  CliFlag = object
    name*: string
    ident*: NimNode
    defaultVal*: NimNode
    typeNode*: NimNode
    node*: NimNode
    short*: char
    long*: string
    help*: NimNode
    group*: string
    env*: NimNode
    defined*: bool # if flag uses custom group it still
                   # needs to be added to cli in postParse
    settings*: HashSet[CliFlagSetting]
    fromParent: bool # default/envs don't need to be set for a parent flag

  Inherit = object
    settings: HashSet[CliSetting]
    flags: seq[string]
    groups: seq[string]

  CliHelp = object
    header*, footer*, description*, usage*, styles*: NimNode

  CliArg = object
    name: string
    ident: NimNode
    typeNode: NimNode

  # support custom console?
  CliCfg = object
    name*: string
    alias*: HashSet[string] # only supported in subcommands
    version*: NimNode
    stopWords*: seq[string]
    help: CliHelp
    defaultFlagType: NimNode
    settings*: HashSet[CliSetting]
    subName*: string # used for help generator
    subcommands: seq[CliCfg]
    preSub*, postSub*, pre*, post*, run*: NimNode
    hidden*: seq[string]
    args*: seq[CliArg]
    flags*: seq[CliFlag]
    builtinFlags*: seq[BuiltinFlag]
    flagDefs*: seq[CliFlag]
    inherit*: Inherit
    root*: bool

func hasSubcommands(c: CliCfg): bool = c.subcommands.len > 0


# template `<<<`(s: string) {.used.} =
#   let pos = instantiationInfo()
#   debugEcho "$1:$2" % [pos.filename, $pos.line]
#   debugEcho s

# some debug procs I use to wrap my ahead aroung the magic of *macro*
template `<<<`(n: NimNode) {.used.} =
  ## for debugging macros
  <<< ("TreeRepr:\n" & (treeRepr n))
  <<< ("Repr: \n" & (repr n))


template `<<<`(n: untyped) {.used.} =
  debugEcho n, "....................", instantiationInfo().line

template `<<<`(f: CliFlag) {.used.}=
  var s: string
  let fields = [
    ("name", f.name),
    ("long", f.long),
    ("short", $f.short),
    ("typeNode", f.typeNode.lispRepr),
    ("group", f.group)
  ]
  s.add "CliFlag(\n"
  for (k,v) in fields:
    s.add "  $1 = $2\n" % [k,v]
  s.add ")"
  <<< s


template err(c: CliCfg, msg: string) =
  ## quit with error while generating cli
  error "hwylcli: \nfailed to generate '" & c.name & "' cli: \n" & msg

# -- error reporting

func prettyRepr(n: NimNode): string =
  let r = n.repr
  let maxWidth = r.splitlines().mapIt(it.len).max()
  const padding = "│ "
  result.add padding & "\n"
  result.add indent(r, 1,padding)
  result.add "\n" & padding & "\n"
  result.add "╰"
  result.add "─".repeat(maxWidth + 2)

func err(c: CliCfg, node: NimNode, msg: string = "", instantiationInfo: tuple[filename: string, line: int, column: int]) =
  var fullMsg: string
  fullMsg.add node.prettyRepr() & "\n"
  fullMsg.add "parsing error ($1, $2) " % [instantiationInfo.filename, $instantiationInfo.line] 
  if msg != "":
    fullMsg.add ": " & msg
  c.err fullMsg

template err(c: CliCfg, node: NimNode, msg: string = "") =
  err c, node, msg, instantiationInfo()

template expectLen(c: CliCfg, node: NimNode, length: Natural) =
  if node.len != length:
    c.err node, "expected node to be length $1 not $2" % [$length, $node.len], instantiationInfo()

template expectKind(c: CliCfg, node: NimNode, kinds: varargs[NimNodeKind]) =
  if node.kind notin kinds:
    c.err node, "expected node kind to be one of: $1 but got $2" % [$kinds, $node.kind], instantiationInfo()

template unexpectedKind(c: CliCfg, node: NimNode) =
  c.err node, "unexpected node kind: $1" % $node.kind, instantiationInfo()


template parseCliSetting(s: string) =
  try:
    cfg.settings.incl parseEnum[CliSetting](s)
  except:
    cfg.err "unknown cli setting: " & s

func parseCliSettings(cfg: var CliCfg, node: NimNode) =
  case node.kind
  of nnkCommand:
    for n in node[1..^1]:
      parseCliSetting n.strVal
  of nnkCall:
    cfg.expectKind node[1], nnkStmtList
    for n in node[1]:
      parseCliSetting(n.strval)
  else: cfg.unexpectedKind node

template parseCliFlagSetting(s: string)=
  try:
    f.settings.incl parseEnum[CliFlagSetting](s)
  except:
    c.err "unknown cli flag setting: " & s

func parseCliFlagSettings(c: CliCfg, f: var CliFlag, node: NimNode) =
  case node.kind
  of nnkCommand:
    for n in node[1..^1]:
      parseCliFlagSetting(n.strVal)
  of nnkCall:
    c.expectKind node[1], nnkStmtList
    for n in node[1]:
      parseCliFlagSetting(n.strVal)
  else: c.unexpectedKind node


func getFlagParamNode(c: CliCfg, node: NimNode): NimNode =
  case node.kind
  of nnkStrLit, nnkTripleStrLit:
    result = node
  of nnkStmtList:
    result = node[0]
  of nnkCommand:
    result = node[1]
  of nnkPrefix: # NOTE: should i double check prefix value?
    result = node[1]
  else: c.unexpectedKind node

func parseFlagStmtList(c: CliCfg, f: var CliFlag, node: NimNode) =
  c.expectKind node, nnkStmtList

  for n in node:
    case n.kind
    of nnkCall, nnkCommand, nnkPrefix:
      let id = n[0].strVal
      case id
      of "help","?":
        f.help = c.getFlagParamNode(n[1])
      of "short", "-":
        let val = c.getFlagParamNode(n).strVal
        if val.len > 1:
          c.err "short flag must be a char"
        f.short = val[0].char
      of "*", "default":
        f.defaultVal = c.getFlagParamNode(n)
      of "i", "ident":
        f.ident = c.getFlagParamNode(n).strVal.ident
      of "T":
        f.typeNode = n[1]
      of "node":
        f.node = n[1]
      of "settings", "S":
        parseCliFlagSettings c, f, n
      of "group", "g":
        f.group = n[1].strVal
        f.defined = true # workaround postParse group implementation
      of "env", "E":
        f.env = n[1]
      else:
        c.err "unexpected setting: " & id

    # might be flag: "help"
    of nnkStrLit:
      if node.len != 1:
        c.err node, "expect only a string literal, are you missing a '?/help'"
      f.help = n


    else:
      c.unexpectedKind n

func getShortChar(c: CliCfg, n: NimNode): char =
  let val = n.strVal
  if val.len > 1:
    c.err n, "short flag must be a char not: " & val
  result = val[0].char

func parseCliFlagCall(c: var CliCfg, f: var CliFlag, nodes: seq[NimNode]) =

  template `<-`(target: untyped, node: NimNode) =
    if node != ident"_":
      target = node

  case nodes.len:

  # flag("help string")
  of 1:
    f.help <- nodes[0]

  # flag(T, "help string")
  of 2:
    f.typeNode <- nodes[0]
    f.help <- nodes[1]

  # flag(NimNode , T , "help string")
  of 3:
    f.defaultVal <- nodes[0]
    f.typeNode <- nodes[1]
    f.help <- nodes[2]

  else:
    c.err "unexpected number of parameters for flag"

func newFlag(cfg: var CliCfg, n: NimNode): CliFlag =
  cfg.expectKind n, nnkIdent, nnkStrLit, nnkAccQuoted

  case n.kind:
  of nnkIdent, nnkStrLit:
    result.name = n.strVal
  of nnkAccQuoted:
    result.name = collect(for c in n: c.strVal).join("")
  else: cfg.unexpectedKind n

  result.help = newLit("") # by default no string

  # assume a single character is a short flag
  if result.name.len == 1:
    result.short = result.name[0].char
  else:
    result.long = result.name

type FlagKind = enum
  Command       ## flag "help"
  CommandStmt   ## count "num": * 5
  InfixCommand  ## a | aflag "help"
  InfixCall     ## a | aflag("help")
  InfixStmt     ## a | aflag: ? "help"
  InfixCallStmt ## c | count ("some number"): * 5
  Stmt          ## count: * 5
  CallStmt      ## count("help"): * 5
  Call          ## count(5, int, "help")


func toFlagKind(c: CliCfg, n: NimNode): FlagKind =
  case n.kind:
  of nnkInfix:
    case n[^1].kind
    of nnkCommand:
      result = InfixCommand
    of nnkStmtList:
      case n[2].kind
      of nnkIdent:
        result = InfixStmt
      of nnkCall:
        result = InfixCallStmt
      else: c.err n, "failed to determine flag kind"
    of nnkCall:
      result = InfixCall
    else:
      c.err n, "failed to determine flag kind with short flag"
  of nnkCall:
    if n.len == 2 and n[1].kind == nnkStmtList:
      result = Stmt
    elif n[^1].kind == nnkStmtList:
      result = CallStmt
    else:
      result = Call
  of nnkCommand:
    if n.len == 2:
      result = Command
    elif n.len > 2 and n[^1].kind == nnkStmtList:
      result = CommandStmt
    else:
      c.err n, "failed to determine flag kind"
  else:
    c.unexpectedKind n

func parseCliFlag(
  c: var CliCfg,
  n: NimNode,
  group: string,
  short: char = '\x00'
) =
  var f : CliFlag


  let flagKind = c.toFlagKind n

  case flagKind
  of Stmt:
     f = c.newFlag n[0]
     parseFlagStmtList c, f, n[1]

  of InfixCommand:
    f = c.newFlag n[2][0]
    f.help = n[2][1]

  of InfixStmt:
    f = c.newFlag n[2]
    parseFlagStmtList c, f, n[^1]

  of InfixCallStmt:
    f = c.newFlag n[2][0]
    parseCliFlagCall c, f, n[^2][1..^1]
    parseFlagStmtList c, f, n[^1]

  of Call:
    f = c.newFlag n[0]
    parseCliFlagCall c, f, n[1..^1]

  of CallStmt:
    f = c.newFlag n[0]
    parseCliFlagCall c, f, n[1..^2]
    parseFlagStmtList c, f, n[^1]

  of InfixCall:
    f = c.newFlag n[2][0]
    parseCliFlagCall c, f, n[^1][1..^1]

  of Command:
    f = c.newFlag n[0]
    f.help = n[1]

  of CommandStmt:
    f = c.newFlag n[0]
    f.help = n[1]
    parseFlagStmtList c, f, n[^1]

  if short != '\x00':
    f.short = short

  f.ident = f.ident or f.name.ident
  if f.group == "":
    f.group = group

  c.flagDefs.add f

func inferShortFlags(cfg: var CliCfg) =
  ## supplement existing short flags based on initial characters of long flags
  let taken = cfg.flags.mapIt(it.short).toHashSet() - toHashSet(['\x00'])
  var candidates = cfg.flags.mapIt(it.long[0]).toHashSet() - taken
  for f in cfg.flags.mitems:

    if f.short != '\x00' or NoShort in f.settings: continue
    let c = f.long[0]
    if c in candidates:
      f.short = c
      candidates.excl c

func makeEnvVar(c: CliCfg, f: CliFlag): string =
  proc norm(s: string): string =
    s.toUpperAscii().replace(" ","_")
  const hwylCliEnvFormat {.strdefine.} = "{cli}_{flag}"
  let cli = norm(c.name)
  let flag = norm(f.name)
  fmt(hwylCliEnvFormat)

func inferEnvFlags(c: var CliCfg) =
  for f in c.flags.mitems:
    if f.env == nil and NoEnv notin f.settings:
      f.env = newLit(makeEnvVar(c, f))

func postParse(c: var CliCfg) =
  if c.name == "": # this should be unreachable
    c.err "missing required option: name"

  if c.args.len != 0 and c.subcommands.len != 0:
    c.err "args and subcommands are mutually exclusive"

  let defaultTypeNode = c.defaultFlagType or ident"bool"
  for f in c.flagDefs.mitems:
    if f.typeNode == nil:
      f.typeNode = defaultTypeNode
    if f.group in ["", "global"] or f.defined:
      c.flags.add f

  if c.args.len > 0:
    let count = c.args.filterIt(it.typeNode.kind == nnkBracketExpr).len
    if count > 1:
      c.err "more than one positional argument is variadic"

func parseCliFlags(cfg: var  CliCfg, node: NimNode) =
  var group: string
  cfg.expectKind node, nnkStmtList
  for n in node:

    case n.kind
    # start a new flag group
    # flags:
    #   [category]
    #   input "input flag"
    of nnkBracket:
      group = n[0].strVal
      continue

    # inherit parent flag or group
    # flags:
    #   ^config
    #   ^[category]
    of nnkPrefix:
      if
        n[0].kind != nnkIdent or
        n.len != 2 or
        n[1].kind notin [nnkBracket, nnkIdent, nnkStrLit]:
        cfg.err n, "unable to determine inherited flag/group"

      case n[1].kind
      of nnkBracket:
        cfg.inherit.groups.add n[1][0].strVal
      of nnkIdent, nnkStrLit:
        cfg.inherit.flags.add n[1].strval
      else: cfg.unexpectedKind n

    # flags:
    #   input "use input"
    #   count:
    #     T int
    #     ? "a number"
    #   output "some output":
    #     T string
    of nnkCall, nnkCommand:
      cfg.parseCliFlag n, group

    # flags:
    #   l | `long-flag` "flag with short using infix"
    #   n | `dry-run`("set dry-run"):
    #     ident dry
    of nnkInfix:
      cfg.expectKind n[0], nnkIdent
      if n[0].strVal != "|":
        cfg.err n, "unexpected infix operator in flags"
      cfg.expectKind n[2], nnkCall, nnkCommand, nnkAccQuoted, nnkIdent

      # need to make sure that this node getting passed here is stmt?
      cfg.parseCliFlag n, group, cfg.getShortChar(n[1])

    else: cfg.unexpectedKind n


func parseIdentLikeList(c: CliCfg, node: NimNode): seq[string] =
  case node.kind
  of nnkCommand:
    for n in node[1..^1]:
      c.expectKind n, nnkStrLit, nnkIdent
      result.add n.strVal
  of nnkCall:
    expectKind node[1], nnkStmtList
    for n in node[1]:
      c.expectKind n, nnkStrLit, nnkIdent
      result.add n.strVal
  else: c.unexpectedKind node

func parseCliBody(body: NimNode, name = "", root = false, settings = initHashSet[CliSetting]()): CliCfg

func isSubMarker(node: NimNode): bool =
  if node.kind != nnkBracket: return false
  if node.len != 1: return false
  if node[0].kind notin [nnkIdent, nnkStrLit, nnkInfix]:
    return false
  result = true

func sliceStmts(c: CliCfg, node: NimNode): seq[
  tuple[name: string, slice: Slice[int]]
] =

  if not isSubMarker(node[0]):
    c.err "expected a subcommand delimiting line"

  var
    name: string = node[0][0].strVal
    start = 1
  let nodeLen = node.len()

  for i in 1..<nodeLen:
    if i == nodeLen - 1:
      result.add (name, start..i)
    elif isSubMarker(node[i]):
      result.add (name, start..(i - 1))
      if node[i][0].kind == nnkInfix:
        name = (repr node[i][0]).replace(" ")
      else:
        name = node[i][0].strVal
      start = i + 1



func inheritFlags(child: var CliCfg, parent: CliCfg) =
  ## inherit flags/groups and settings from parent command
  var
    pflags: Table[string, CliFlag]
    pgroups: Table[string, seq[CliFlag]]
    flags: seq[string]
    groups: seq[string]

  flags &= child.inherit.flags
  groups &= child.inherit.groups

  for f in parent.flagDefs:
    var parentF = f
    parentF.fromParent = true
    pflags[f.name] = parentF
    if pgroups.hasKeyOrPut(f.group, @[parentF]):
      pgroups[f.group].add parentF

  if "global" in pgroups:
    groups.add "global"

  for f in flags:
    if f notin pflags:
      child.err "expected parent command to have flag: " & f
    else:
      child.flags.add pflags[f]
      # so subcommands can continue the inheritance
      child.flagDefs.add pflags[f]

  for g in groups:
    if g notin pgroups:
      child.err "expected parent command to have flag group " & g
    else:
      child.flags.add pgroups[g]
      # so subcommands can continue the inheritance
      child.flagDefs.add pgroups[g]

func inheritHelp(child: var CliCfg, parent: CliCfg) =
  ## fall back to parent styles for anything not defined
  for field, val1, val2 in fieldPairs(child.help, parent.help):
    if val1 == nil:
      val1 = val2

func inheritFrom(child: var CliCfg, parent: CliCfg) =
  inheritFlags child, parent
  inheritHelp child, parent

func parseCliSubcommands(cfg: var CliCfg, node: NimNode) =
  cfg.expectKind node[1], nnkStmtList

  for (name, s) in cfg.sliceStmts(node[1]):
    var subCfg = parseCliBody(
      nnkStmtList.newTree(node[1][s]), cfg.name & " " & name,
      settings = cfg.settings
    )
    subCfg.subName = name
    cfg.stopWords.add name
    cfg.stopWords.add subCfg.alias.toSeq()
    cfg.subcommands.add subCfg

func parseHiddenFlags(c: var CliCfg, node: NimNode) =
  template check =
    if n.kind notin [nnkStrLit, nnkIdent]:
      c.err "expected string literal or ident"
  case node.kind
  of nnkCommand:
    for n in node[1..^1]:
      check
      c.hidden.add n.strVal
  of nnkCall:
    expectKind node[1], nnkStmtList
    for n in node[1]:
      check
      c.hidden.add n.strVal
  else: assert false

func addBuiltinFlags(c: var CliCfg) =

  <<< c.name
  <<< c.settings

  # duplicated with below :/
  let shorts = c.flags.mapIt(it.short).toHashSet()

  let
    name = c.name.replace(" ", "")
    printHelpName = ident("print" & name & "Help")

  if NoHelpFlag notin c.settings:
    let helpDesc =
      if LongHelp in c.settings:
        newLit("print help  [faint](see more with --help)[/]")
      else:
        newLit("print help")

    let helpNode =
      if LongHelp in c.settings:
        quote do:
          `printHelpName`(hwylKey == "help"); quit 0
      else:
        quote do:
          `printHelpName`(); quit 0

    c.builtinFlags.add BuiltinFlag(
      name: "help",
      long: "help",
      help: helpDesc,
      short: if 'h' notin shorts: 'h' else: '\x00',
      node: helpNode
    )

  if c.version != nil:
    let version = c.version
    let versionNode = quote do:
      hecho `version`; quit 0

    c.builtinFlags.add BuiltinFlag(
      name:"version",
      long: "version",
      help: newLit("print version"),
      short: if 'V' notin shorts: 'V' else: '\x00',
      node: versionNode
    )


func parseCliAlias(cfg: var CliCfg, node: NimNode) =
  # node[0] is "alias"
  for n in node[1..^1]:
    case n.kind
    of nnkIdent, nnkStrLit:
      cfg.alias.incl n.strVal
    of nnkAccQuoted:
      let s = n.mapIt(it.strVal).join("")
      cfg.alias.incl s
    else: cfg.unexpectedKind n

func postPropagate(c: var CliCfg) =
  ## verify the cli is valid
  var
    short: Table[char, CliFlag]
    long: Table[string, CliFlag]

  for f in c.flags:
    if f.short != '\x00':
      if f.short in short:
        let conflict = short[f.short]
        c.err "conflicting short flags for: " & f.name & " and " & conflict.name

      else:
        short[f.short] = f

    if f.long == "": discard
    elif f.long in long:
      let conflict = long[f.long]
      c.err "conflicting long flags for: " & f.name & " and " & conflict.name
    else:
      long[f.long] = f

  if InferShort in c.settings:
    inferShortFlags c
  if InferEnv in c.settings:
    inferEnvFlags c

func propagate(c: var CliCfg) =
  for child in c.subcommands.mitems:
    # push the hooks to the lowest subcommand unless another one exists on the way
    if child.subcommands.len != 0:
      child.preSub = child.preSub or c.preSub
      child.postSub = child.postSub or c.postSub
    else:
      child.pre = c.preSub
      child.post = c.postSub

    child.inheritFrom(c)

    propagate child
    postPropagate child


func parseCliHelp(c: var CliCfg, node: NimNode) =
  ## some possible DSL inputs:
  ##
  ## ```
  ## help:
  ##  header NimNode -> string
  ##  usage NimNode -> string
  ##  description NimNode -> string
  ##  footer NimNode -> string
  ##  styles NimNode -> HwylCliStyles()
  ## ```
  ##
  ## ```
  ## help NimNode
  ## ```
  ##
  ## ```
  ## ... NimNode
  ## ```

  c.expectLen(node, 2)
  var help: CliHelp = c.help
  case node.kind:
  # help NimNode or ... NimNode
  of nnkPrefix, nnkCommand:
    help.description = node[1]
  # help:
  #   description NimNode
  #   usage: NimNode
  of nnkCall:
    if node[1].kind != nnkStmtList:
      c.err node, "expected list of arguments for help"
    for n in node[1]:
      c.expectLen n, 2
      let id = n[0].strVal
      var val: NimNode
      case n.kind
      of nnkCommand:
        val = n[1]
      of nnKCall:
        val = n[1][0]
      else: c.err n, "unexpected node for help: " & id & ", expected ident"

      case id:
      of "usage": help.usage = val
      of "description": help.description = val
      of "header": help.header = val
      of "footer": help.footer = val
      of "styles": help.styles = val
      else: c.err n, "unknown help option: " & id
  else: c.err node, "unexpected node for help, expected nnkCommand/nnkCall"

  c.help = help

func isSeq(arg: CliArg): bool =
  # NOTE: does this need to be more rigorous?
  arg.typeNode.kind == nnkBracketExpr

func parseCliArg(c: CliCfg, node: NimNode): CliArg =
  ## parse a single positional arg
  ## supported formats:
  ##
  ## ```
  ## input seq[string]
  ## ```
  ## ```
  ## other:
  ##   T string
  ##   ident notOther
  ## ```
  ##

  c.expectLen node, 2
  result.name = node[0].strVal
  case node[1].kind
  of nnkStmtList:
    for n in node[1]:
      let id = n[0].strVal
      var val: NimNode
      case n.kind:
      of nnkCommand:
        val = n[1]
      of nnkCall:
        # input seq[string]
        if n[1].len == 2:
          result.typeNode = n[1][1]
        val = n[1][0]
      # else: bad(n, id)
      else: c.err n, "unexpected node for positional '$1'" & id

      case id:
      of "T": result.typeNode = val
      of "ident": result.ident = val
      else: c.err n, "unknown positional parameter for $1: $2" % [result.name, id]

  of nnkIdent, nnkBracketExpr:
    result.typeNode = node[1]
  else:
    c.err node, "as positional"
  if result.ident == nil:
    result.ident = ident(result.name)

func parseCliArgs(c: var CliCfg, node: NimNode) =
  if node.kind != nnkStmtList:
    c.err node, "expected node kind nnkStmtList"
  for n in node:
    c.args.add parseCliArg(c, n)

func isNameNode(n: NimNode): bool =
  if n.kind notin [nnkCall, nnkCommand] or n.len != 2: return false
  if n[0].kind != nnKident: return false
  if n[0].strVal != "name": return false
  true

func parseCliBody(body: NimNode, name = "", root = false, settings = initHashSet[CliSetting]()): CliCfg =
  # Try to grab name first for better error messages
  #
  # NOTE: settings was added here as a workaround...to handle settings and builtinFlags
  if name == "":
    let n = body.findChild(it.isNameNode())
    if n == nil: error "name is a required property"
    result.name = $n[1]
  else:
    result.name = name
  result.root = root

  var subCommandNodes: seq[NimNode]

  for node in body:
    if node.kind notin [nnkCall, nnkCommand, nnkPrefix]:
      result.err node, "unexpected node kind: " & $node.kind
    let name = node[0].strVal
    case name:
      of "name": discard # should have been handled above
      of "alias":
        if root: result.err "alias not supported for root command"
        parseCliAlias(result, node)
      of "version", "V":
        result.version = node[1]
      of "usage", "?":
        result.help.usage = node[1]
      of "...", "help":
        parseCliHelp(result, node)
      of "flags":
        parseCliFlags(result, node[1])
      of "settings", "S":
        parseCliSettings(result, node)
      of "stopWords":
        result.stopWords = result.parseIdentLikeList(node)
      of "subcommands":
        subCommandNodes.add node
      of "hidden":
        parseHiddenFlags(result, node)
      of "run":
        result.run = node[1]
      of "preSub":
        result.preSub = node[1]
      of "postSub":
        result.postSub = node[1]
      of "defaultFlagType":
        result.defaultFlagType = node[1]
      of "positionals":
        parseCliArgs result, node[1]
      else:
        result.err "unknown hwylCli setting: " & name

  if IgnoreParent notin result.settings:
    result.settings = result.settings + settings - toHashSet([IgnoreParent])

  postParse result

  for node in subCommandNodes:
    parseCliSubcommands(result, node)

  # TODO: validate "required" flags exist here?
  result.addBuiltinFlags()

  if root:
    propagate(result)

  postPropagate result

func isBool(f: CliFlag | BuiltinFlag): bool =
  f.typeNode == ident"bool"

func isCount(f: CliFlag): bool =
  f.typeNode == ident"Count"

func isRequiredFlag(cfg: CliCfg, f: CliFlag): bool =
  result = (Required in f.settings and f.defaultVal == nil)
  if result and f.isBool:
    cfg.err "boolean flag `$1` can't be a required flag " % [f.long]

# TODO: deprecate builtinflag
func flagToTuple(c: CliCfg, f: BuiltinFlag): NimNode =
  let
    short =
      if f.short != '\x00': newLit($f.short)
      else: newLit("")
    long = newLit(f.long)
    help = f.help

    defaultVal =
      if (HideDefault in f.settings) or
        (HideDefault in c.settings):
        newLit""
      else:
        f.defaultVal or newLit""
    required = newLit(false)

  # BUG: if f.defaultVal is @[] `$` fails
  # but works with `newSeq[T]()`
  # could replace "defaultVal" with newSeq[T]()
  # under the hood when parsing type/val

  quote do:
    (`short`, `long`, `help`, "", bbEscape($`defaultVal`), "", `required`)


func flagToTuple(c: CliCfg, f: CliFlag): NimNode =
  let
    short =
      if f.short != '\x00': newLit($f.short)
      else: newLit""

    defaultVal =
      if (HideDefault in f.settings) or
        (HideDefault in c.settings) or
        f.defaultVal == nil:
        newLit""
      else:
        let val = f.defaultVal
        quote do:
          bbEscape($(`val`))

    required = newLit(c.isRequiredFlag(f))
    typeNode =
      if f.isBool: newLit""
      else:
        let t = f.typeNode
        quote do: bbEscape($`t`)

  # BUG: if f.defaultVal is @[] `$` fails
  # but works with `newSeq[T]()`
  # could replace "defaultVal" with newSeq[T]()
  # under the hood when parsing type/val

  result = nnkTupleConstr.newTree(
    short,
    newLit(f.long),
    f.help,
    typeNode,
    defaultVal,
    newLit(f.group),
    required,
  )

func flagsArray(cfg: CliCfg): NimNode =
  result = newTree(nnkBracket)
  for f in cfg.flags:
    if f.name in cfg.hidden: continue
    result.add cfg.flagToTuple(f)
  for f in cfg.builtinFlags:
    result.add cfg.flagToTuple(f)

func subCmdsArray(cfg: CliCfg): NimNode =
  result = newTree(nnkBracket)
  for s in cfg.subcommands:
    let cmd = newLit(s.subName)
    let aliases = newLit(s.alias.mapIt("($1)" % [it]).join(" "))
    let desc = s.help.description or newLit("")
    result.add quote do:
      (`cmd`, `aliases`, `desc`)

# is this one necessary?

proc hwylCliError*(msg: BbString) =
  quit $(bb("error ", "red") & msg)

proc hwylCliError*(msg: string) =
  quit $bb("error ", "red") & msg

# TODO: this function should not be handling styling!!!
# TODO: make this NimNode be a call to the defaultUsage below
# make this a function that accepts CliHelpStyles and use that as the call to HwlCLIhel
func defaultUsage(cfg: CliCfg, styles: NimNode): NimNode =
  var s = "[b]" & cfg.name & "[/]"
  if cfg.subcommands.len > 0:
    s.add " [bold italic]subcmd[/]"
  if cfg.args.len > 0:
    for arg in cfg.args:
      s.add " [bold italic]"
      s.add arg.name
      if arg.isSeq:
        s.add "..."

      s.add"[/]"
  s.add " [[[faint]flags[/]]"
  # newLit(s)

  let
    name = cfg.name
    hasSubcommands = cfg.subcommands.len > 0
    args = cfg.args.mapIt((it.name, it.isSeq))

  result = quote do:
    hwylDefaultUsage(
      name = `name`,
      hasSubcommands = `hasSubcommands`,
      args = `args`,
      styles = `styles`
    )

func hwylDefaultUsage*(
  name: string,
  hasSubcommands: bool,
  args: seq[tuple[name: string, isSeq: bool]],
  styles: HwylCliStyles
): string =
  ## generate a default BbMarkup usage string
  result.add name.bbMarkup(styles.name)

  if hasSubcommands:
    result.add " "
    result.add "subcmd".bbMarkup(styles.args)
  if args.len > 0:
    for arg in args:
      result.add " "
      var argStr = arg.name
      if arg.isSeq:
        argStr.add "..."
      result.add argStr.bbMarkUp(styles.args)
  result.add " [[flags]"

func generateCliHelpProc(cfg: CliCfg, printHelpName: NimNode): NimNode =
  let
    description = cfg.help.description or newLit""
    header = cfg.help.header or newLit""
    footer = cfg.help.footer or newLit""
    helpFlags = cfg.flagsArray()
    subcmds = cfg.subCmdsArray()
    styles = cfg.help.styles or (quote do: newHwylCliStyles())
    usage  = cfg.help.usage or defaultUsage(cfg, styles)

  # todo: pass on the LongHelp setting here somehow....
  result = quote do:
    proc `printHelpName`(longHelp = false) =
      let help =
          # use getEnv call here?
        newHwylCliHelp(
          usage = `usage`,
          header = `header`,
          footer = `footer`,
          description = `description`,
          subcmds = `subcmds`,
          flags = `helpFlags`,
          styles = `styles`,
          longHelp = longHelp
        )
      hecho help.render().bb()

proc checkVal(p: OptParser) =
  if p.val == "":
    hwylCliError(
      "expected value for flag: " & p.key.bb("bold")
    )

proc parse*(p: OptParser, target: var bool) =
  target = true

proc parse*(p: OptParser, target: var string) =
  checkVal p
  target = p.val

proc parse*(p: OptParser, target: var int) =
  checkVal p
  try:
    target = parseInt(p.val)
  except:
    hwylCliError(
      bbfmt"failed to parse value for [b]{p.key}[/] as integer: [b]{p.val}[/]"
    )

macro enumNames(a: typed): untyped =
  ## unexported macro copied from std/enumutils
  result = newNimNode(nnkBracket)
  for ai in a.getType[1][1..^1]:
    assert ai.kind == nnkSym
    result.add newLit ai.strVal

proc parse*[E: enum](p: OptParser, target: var E) =
  checkVal p
  try:
    target = parseEnum[E](p.val)
  except:
    let choices = enumNames(E).join(",")
    hwylCliError(
      bbfmt"failed to parse value for [b]{p.key}[/] as enum: [b]{p.val}[/] expected one of: " & choices
    )

proc parse*(p: OptParser, target: var float) =
  checkVal p
  try:
    target = parseFloat(p.val)
  except:
    hwylCliError(
      bbfmt"failed to parse value for [b]{p.key}[/] as float: [b]{p.val}[/]"
    )

proc parse*[T](p: var OptParser, target: var seq[T]) =
  checkVal p
  case p.sep
  of ",=", ",:":
    let baseVal = p.val
    for v in baseVal.split(","):
      p.val = v.strip()
      if p.val == "": continue
      var parsed: T
      parse(p, parsed)
      target.add parsed
  of "=",":","":
   var parsed: T
   parse(p, parsed)
   target.add parsed
  else: assert false


proc parse*(p: OptParser, target: var Count) =
  # if value set to that otherwise increment
  if p.val != "":
    var num: int
    parse(p, num)
    target.val = num
  else:
    inc target.val

proc extractKey(p: var OptParser): string =
  var i: int
  for c in p.val:
    if c notin {'=',':'}: inc i
    else: break
  if i == p.val.len:
    hwylCliError(
      "failed to parse key val flag" &
      "\nkey: " & p.key.bb("bold") &
      "\nval: " & p.val.bb("bold") &
      "\ndid you include a separator (= or :)?"
    )
  else:
    result = p.val[0..<i]
    p.key = p.key & ":" & result
    p.val = p.val[(i+1) .. ^1]

proc parse*[T](p: var OptParser, target: var KV[string, T]) =
  checkVal p
  let key = extractKey(p)
  target.key = key
  parse(p, target.val)

proc parseKeyVal[T](p: var OptParser, key: string, val: string,  target: var T, isEnv = false) =
  ## convience proc to reuse other parsers
  let ogKV = (p.key, p.val, p.sep)
  defer: (p.key, p.val, p.sep) = ogKV
  p.key = key
  p.val = val
  if isEnv and val.len > 0 and val[0] == ',':
      p.sep = ",="
  when T is bool:
    if parseBool(val):
      parse(p, target)
  else:
    parse(p, target)

func shortLongCaseStmt(cfg: CliCfg, printHelpName: NimNode, version: NimNode): NimNode =
  var caseStmt = nnkCaseStmt.newTree()
  if NoNormalize notin cfg.settings:
    caseStmt.add nnkCall.newTree(ident"optionNormalize", ident"hwylKey")
  else:
    caseStmt.add ident"hwylKey"

  caseStmt.add nnkOfBranch.newTree(newLit(""), quote do: hwylCliError("empty flag not supported currently"))

  for f in cfg.builtinFlags:
    var branch = nnkOfBranch.newTree()
    if f.long != "": branch.add(newLit(f.long))
    if f.short != '\x00': branch.add(newLit($f.short))
    branch.add f.node
    caseStmt.add branch

  # add flags
  for f in cfg.flags:
    var branch = nnkOfBranch.newTree()
    if f.long != "":
      branch.add newLit(
        if NoNormalize notin cfg.settings: optionNormalize(f.long)
        else: f.long
      )
    if f.short != '\x00': branch.add(newLit($f.short))
    let varName = f.ident
    let name = newLit(f.name)
    branch.add nnkStmtList.newTree(
      nnkCall.newTree(ident("incl"),ident("flagSet"),name),
      if f.node == nil: nnkCall.newTree(ident"parse", ident"p", varName)
      else: f.node
    )

    caseStmt.add branch

  caseStmt.add nnkElse.newTree(quote do: hwylCliError(bbfmt"unknown flag: [b]{hwylkey}"))

  result = nnkStmtList.newTree(caseStmt)


func getNoVals(cfg: CliCfg): tuple[long: NimNode, short: NimNode] =
  let flagFlags = cfg.flags.filterIt(it.isBool or it.isCount)
  let long =
    nnkBracket.newTree(
      (flagFlags.mapIt(it.long) & cfg.builtinFlags.mapIt(it.long)).filterIt(it != "").mapIt(newLit(it))
    )
  let short =
    nnkCurly.newTree(
      (flagFlags.mapIt(it.short) & cfg.builtinFlags.mapIt(it.short)).filterIt(it != '\x00').mapIt(newLit(it))
    )
  result = (nnkPrefix.newTree(ident"@",long), short)


func setVars(cfg: CliCfg): NimNode =
  ## generate all positinal variables and flags not covered in global module
  result = nnkVarSection.newTree()
  let flags =
    if cfg.root: cfg.flags
    else: cfg.flags.filterIt(it.group != "global")

  result.add flags.mapIt(
    nnkIdentDefs.newTree(it.ident, it.typeNode, newEmptyNode())
  )
  if cfg.args.len > 0:
    result.add cfg.args.mapIt(
      nnkIdentDefs.newTree(it.ident, it.typeNode, newEmptyNode())
    )
  if hasSubcommands cfg:
    result.add nnkIdentDefs.newTree(ident"subcmd", ident"string", newEmptyNode())

func literalFlags(f: CliFlag): NimNode =
  var flags: seq[string]
  if f.short != '\x00': flags.add "[b]" &  "-" & $f.short & "[/]"
  if f.long != "": flags.add "[b]" & "--" & f.long & "[/]"
  result = newLit(flags.join("|"))

type
  MultiArgKind = enum
    NoMulti, ## No positionals use seq[[T]]
    First, ## First positional uses seq[[T]]
    Last, ## Last positional uses seq[[T]]

func getMultiArgKind(cfg: CliCfg): MultiArgKind =
  if cfg.args.len == 1:
    if cfg.args[0].isSeq:
      return Last
    else:
      return NoMulti
  if cfg.args[0].isSeq:
    return First
  if cfg.args[^1].isSeq:
    return Last

func parseArgs(p: OptParser, target: var string) =
  target = p.key

func parseArgs[T](p: OptParser, target: var seq[T]) =
  var val: T
  parseArgs(p, val)
  target.add val

proc parseArgs*(arg: string, target: var float) =
  try: target = parseFloat(arg)
  except: hwylCliError(bbfmt"failed to parse as float: [b]{arg}")

func parseArgs*(arg: string, target: var string) =
  target = arg

proc parseArgs*(arg: string, target: var int) =
  try: target = parseInt(arg)
  except: hwylCliError(bbfmt"failed to parse as integer: [b]{arg}")

proc parseArgs*[E: enum](arg: string, target: var E) =
  try: target = parseEnum[E](arg)
  except:
    let choices = enumNames(E).join(",")
    hwylCliError(bbfmt"failed to parse as enum: [b]{arg}[/], expected one of: " & choices)

proc parseArgs*[T](arg: string, target: var seq[T]) =
  var val: T
  parseArgs(arg, val)
  target.add val

proc parseArgs*[T](args: seq[string], target: var seq[T]) =
  for arg in args:
    parseArgs(arg, target)


# TODO: rework conditionals and control flow here...
func genPosArgHandler(cfg: CliCfg, body: NimNode) =
  ## generate code to handle positional arguments
  let numArgs = cfg.args.len
  let maKind = cfg.getMultiArgKind()
  case maKind:
  of NoMulti:
    body.add quote do:
      if result.len > `numArgs`:
        hwylCliError("unexepected positional args, got: " & $result.len & ", expected: " & $`numArgs`)
      elif result.len < `numArgs`:
        hwylCliError("missing positional args, got: " & $result.len & ", expected: " & $`numArgs`)
    for i, namedArg in cfg.args.mapIt(it.name.ident):
      body.add quote do:
        parseArgs(result[`i`], `namedArg`)

  of First:
    body.add quote do:
      if result.len < `numArgs`:
        hwylCliError("missing positional args, got: " & $result.len & ", expected at least: " & $`numArgs`)
    for i, namedArg in cfg.args[1..^1].reversed().mapIt(it.ident):
      body.add quote do:
        parseArgs(result[^(1+`i`)], `namedArg`)

    let firstArg = cfg.args[0].ident
    body.add quote do:
      parseArgs(result[0..^(`numArgs`)], `firstArg`)

  of Last:
    body.add quote do:
      if result.len < (`numArgs` - 1):
        hwylCliError("missing positional args, got: " & $result.len & ", expected at least: " & $(`numArgs` - 1))
    for i, namedArg in cfg.args[0..^2].mapIt(it.ident):
      body.add quote do:
        parseArgs(result[`i`], `namedArg`)

    let lastArg = cfg.args[^1].ident
    body.add quote do:
      if result.len > `numArgs` - 1:
        parseArgs(result[(`numArgs`-1).. ^1],`lastArg`)

  body.add quote do:
    result = @[]


func addPostParseHook(cfg: CliCfg, body: NimNode) =
  ## generate block to set defaults and check for required flags
  ## and check for env vars

  let flagSet = ident"flagSet"
  let subcmd = ident"subcmd"
  var required, default, env: seq[CliFlag]

  for f in cfg.flags:
    if cfg.isRequiredFlag(f):
      required.add f
    elif f.defaultVal != nil and not f.fromParent:
      default.add f
    if f.env != nil and not f.fromParent:
      env.add f

  for f in required:
    let flagLit = f.literalFlags
    let name = newLit(f.name)
    body.add quote do:
      if `name` notin `flagSet`:
        hwylCliError("expected a value for flag: " & (`flagLit`).bb("bold"))

  for f in default:
    let
      name = newLit(f.name)
      target = f.ident
      defaultVal = f.defaultVal
    body.add quote do:
      if `name` notin `flagSet`:
        `target` = `defaultVal`

  for f in env:
    let
      name = newLit(f.name)
      target = f.ident
      envNode = f.env

    body.add quote do:
      if `name` notin `flagSet`:
        if existsEnv(`envNode`):
          parseKeyVal p, `name`, getEnv(`envNode`), `target`, true

  if hasSubcommands cfg:
    body.add quote do:
      if result.len == 0:
        hwylCliError("expected subcommand")
      `subcmd` = result[0]
      result = result[1..^1]


  elif cfg.args.len == 0:
    body.add quote do:
      if result.len > 0:
        hwylCliError("got unexpected positionals args: " & result.join(" ").bb("bold"))

  elif cfg.args.len > 0:
    genPosArgHandler cfg, body

func hwylCliImpl(cfg: CliCfg): NimNode

func genSubcommandHandler(cfg: CliCfg): NimNode =
  let subcmd = ident"subcmd"
  let subcmdOptions = cfg.subcommands.mapIt(
    it.subName.bbMarkup("b")
  ).join(", ").bb
  result = nnkStmtList.newTree()

  var subCommandCase = nnkCaseStmt.newTree()
  if NoNormalize notin cfg.settings:
    subCommandCase.add(quote do: optionNormalize(`subcmd`))
  else:
    subCommandCase.add(quote do: `subcmd`)

  for sub in cfg.subcommands:
    var branch = nnkOfBranch.newTree()
    branch.add newLit(optionNormalize(sub.subName))
    for a in sub.alias:
      branch.add newLit(optionNormalize(a))
    branch.add hwylCliImpl(sub)
    subcommandCase.add branch

  subcommandCase.add nnkElse.newTree(
    quote do:
      hwylCliError(
        "unknown subcommand: " &
        `subcmd`.bb("b") &
        " expected one of: " &
        `subcmdOptions`
      )
  )

  result.add subCommandCase

# TODO: collect all strings into a seq and handle prior to subcomamnd parsing?
# subcommands are really just a special case of positional args handling
func positionalArgsOfBranch(cfg: CliCfg): NimNode =
  result = nnkOfBranch.newTree(ident"cmdArgument")
  # TODO: utilize the NoPositional setting here?
  # if cfg.args.len == 0 and cfg.subcommands.len == 0:
  #   result.add quote do:
  #     hwylCliError("unexpected positional argument: " & p.key.bb("bold"))
  # else:
  result.add quote do:
    inc nArgs
    parseArgs(p, result)


func hwylCliImpl(cfg: CliCfg): NimNode =
  let
    version = cfg.version or newLit("")
    name = cfg.name.replace(" ", "")
    printHelpName = ident("print" & name & "Help")
    parserProcName = ident("parse" & name)
    posArgs = ident"posArgs"
    optParser = ident("p")
    cmdLine = ident"cmdLine"
    flagSet = ident"flagSet"
    nArgs = ident"nargs"
    (longNoVal, shortNoVal) = cfg.getNoVals()
    printHelpProc = generateCliHelpProc(cfg, printHelpName)
    varBlock= setVars(cfg)

  var
    parserBody = nnkStmtList.newTree()
    stopWords = nnkBracket.newTree(newLit("--"))

  for w in cfg.stopWords:
    stopWords.add newLit(w)

  stopWords = nnkPrefix.newTree(ident"@", stopWords)

  if cfg.flags.len > 0:
    parserBody.add quote do:
      var `flagSet`: HashSet[string]

  parserBody.add quote do:
    var `nArgs`: int

  parserBody.add(
    quote do:
      var `optParser` = initOptParser(
        @`cmdLine`,
        longNoVal = `longNoVal`,
        shortNoVal = `shortNoVal`,
        stopWords = `stopWords`,
        opChars = {','},
        longPfxOk = false,
      )
  )

  # TODO: first key needs to be normalized?
  # TODO: don't use getopt? use p.next() instead?
  parserBody.add nnkForStmt.newTree(
    ident"hwylKind", ident"hwylKey", ident"hwylVal",
    nnkCall.newTree(ident"getopt", optParser),
    nnkStmtList.newTree(
      nnkCaseStmt.newTree(
        ident"hwylKind",
        nnkOfBranch.newTree(ident("cmdError"), quote do: hwylCliError(p.message)),
        nnkOfBranch.newTree(ident("cmdEnd"), quote do:  hwylCliError("reached cmdEnd unexpectedly.")),
        positionalArgsOfBranch(cfg),
        nnkOfBranch.newTree(
          ident("cmdShortOption"), ident("cmdLongOption"),
          shortLongCaseStmt(cfg, printHelpName, version)
        )
      )
    )
  )


  if ShowHelp in cfg.settings:
    parserBody.add quote do:
      if commandLineParams().len == 0:
        `printHelpName`(); quit 1

  addPostParseHook(cfg, parserBody)

  let runProcName = ident("run" & name)
  let runBody = nnkStmtList.newTree()

  if cfg.pre != nil:
    runBody.add cfg.pre

  # args and subcommands need to be mutually exclusive -> implement using a CommandKind?
  if hasSubcommands cfg:
    runBody.add genSubcommandHandler(cfg)

  if cfg.run != nil:
    runBody.add cfg.run
  if cfg.post != nil:
    runBody.add cfg.post

  result = newTree(nnkStmtList)

  result.add quote do:
    # block:
      `printHelpProc`
      `varBlock`
      proc `parserProcName`(`cmdLine`: openArray[string] = commandLineParams()): seq[string] =
        `parserBody`

      proc `runProcName`(`cmdLine`: openArray[string] = commandLineParams()) =
        let `posArgs` {.used.} = `parserProcName`(`cmdLine`)
        `runBody`

  if cfg.root:
    if GenerateOnly notin cfg.settings:
      result.add quote do:
        `runProcName`()
  else:
    result.add quote do:
      `runProcName`(`posArgs`)

macro hwylCli*(body: untyped) =
  ## generate a CLI styled by `hwylterm` and parsed by `parseopt3`
  var cfg = parseCliBody(body, root = true)
  hwylCliImpl(cfg)

