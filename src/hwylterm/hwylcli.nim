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

]##

import std/[
  algorithm,
  macros, os, sequtils,
  sets, strutils, tables,
  sugar
]
import ./[bbansi, parseopt3]
export parseopt3, sets, bbansi

type
  HwylFlagHelp* = tuple
    short, long, description, defaultVal: string
  HwylSubCmdHelp* = tuple
    name, aliases, desc: string
  HwylCliStyleSetting = enum
    Aliases
  HwylCliStyles* = object
    header* = "bold cyan"
    flagShort* = "yellow"
    flagLong* = "magenta"
    flagDesc* = ""
    default* = "faint"
    required* = "red"
    cmd* = "bold"
    settings*: set[HwylCliStyleSetting] = {Aliases}
  HwylCliLengths = object
    subcmd*, subcmdDesc*, shortArg*, longArg*, descArg*, defaultVal*: int

  HwylCliHelp* = object
    header*, footer*, description*, usage*: string
    subcmds*: seq[HwylSubCmdHelp]
    flags*: seq[HwylFlagHelp]
    styles*: HwylCliStyles
    lengths*: HwylCliLengths

# NOTE: do i need both strips?
func firstLine(s: string): string =
  s.strip().dedent().strip().splitlines()[0]

func newHwylCliHelp*(
  header = "",
  usage = "",
  footer = "",
  description = "",
  subcmds: openArray[HwylSubCmdHelp] = @[],
  flags: openArray[HwylFlagHelp] = @[],
  styles = HwylCliStyles()
): HwylCliHelp =
  result.header = dedent(header).strip()
  result.footer = dedent(footer).strip()
  result.description = dedent(description).strip()
  if Aliases in styles.settings:
    result.subcmds =
      subcmds.mapIt((it.name & " " & it.aliases, it.aliases, it.desc.firstLine))
  else:
    result.subcmds =
      subcmds.mapIt((it.name, it.aliases, it.desc.firstLine))
  result.usage = dedent(usage).strip()
  result.flags = @flags
  result.styles = styles
  result.lengths.subcmd = 8 # TODO: incorporate into "styles?"
  for f in flags:
    result.lengths.shortArg = max(result.lengths.shortArg, f.short.len)
    result.lengths.longArg  = max(result.lengths.longArg, f.long.len)
    result.lengths.descArg  = max(result.lengths.descArg, f.description.len)
    result.lengths.defaultVal  = max(result.lengths.defaultVal, f.defaultVal.len)
  for s in result.subcmds:
    result.lengths.subcmd = max(result.lengths.subcmd, s.name.len)
    result.lengths.subcmdDesc = max(result.lengths.subcmdDesc, s.desc.len)


func render*(cli: HwylCliHelp, f: HwylFlagHelp): string =
  result.add "  "
  if f.short != "":
    result.add "[" & cli.styles.flagShort & "]"
    result.add "-" & f.short.alignLeft(cli.lengths.shortArg)
    result.add "[/" & cli.styles.flagShort & "]"
  else:
    result.add " ".repeat(1 + cli.lengths.shortArg)
  result.add " "
  if f.long != "":
    result.add "[" & cli.styles.flagLong & "]"
    result.add "--" & f.long.alignLeft(cli.lengths.longArg)
    result.add "[/" & cli.styles.flagLong & "]"
  else:
    result.add " ".repeat(2 + cli.lengths.longArg)

  result.add " "
  if f.description != "":
    result.add "[" & cli.styles.flagDesc & "]"
    result.add f.description
    result.add "[/" & cli.styles.flagDesc & "]"
    if f.defaultVal != "":
      result.add " "
      result.add "[" & cli.styles.default & "]"
      result.add "(" & f.defaultVal & ")"
      result.add "[/" & cli.styles.default & "]"


func render*(cli: HwylCliHelp, subcmd: HwylSubCmdHelp): string =
  result.add "  "
  result.add "[" & cli.styles.cmd & "]"
  result.add subcmd.name.alignLeft(cli.lengths.subcmd)
  result.add "[/]"
  result.add " "
  result.add subcmd.desc.alignLeft(cli.lengths.subcmdDesc)


# TODO: split this into separate procs to make overriding more fluid
template render*(cli: HwylCliHelp): string =
  var parts: seq[string]

  if cli.header != "":
    parts.add cli.header
  if cli.usage != "":
    var part: string
    part.add "[" & cli.styles.header & "]"
    part.add "usage[/]:\n"
    part.add indent(cli.usage, 2 )
    parts.add part
  if cli.description != "":
    parts.add cli.description
  if cli.subcmds.len > 0:
    var part: string
    part.add "[" & cli.styles.header & "]"
    part.add "subcommands[/]:\n"
    part.add cli.subcmds.mapIt(render(cli,it)).join("\n")
    parts.add part
  if cli.flags.len > 0:
    var part: string
    part.add "[" & cli.styles.header & "]"
    part.add "flags[/]:\n"
    part.add cli.flags.mapIt(render(cli, it)).join("\n")
    parts.add part
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

proc `$`(c: Count): string = $c.val

# ----------------------------------------

type
  CliSetting* = enum
    # Propagate,  ## Include parent command settings in subcommand
    GenerateOnly, ## Don't attach root `runProc()` node
    NoHelpFlag,   ## Remove the builtin help flag
    ShowHelp,     ## If cmdline empty show help
    NoNormalize,  ## Don't normalize flags and commands
    NoPositional, ## Raise error if any remaing positional arguments DEPRECATED
    HideDefault   ## Don't show default values
    # ExactArgs,    ## Raise error if missing positional argument

  CliFlagSetting* = enum
    HideDefault   ## Don't show default values

  BuiltinFlag = object
    name*: string
    short*: char
    long*: string
    help*: NimNode
    node: NimNode
    defaultVal: NimNode
    settings*: set[CliFlagSetting]

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
    inherited*: bool
    settings*: set[CliFlagSetting]

  Inherit = object
    settings: set[CliSetting]
    flags: seq[string]
    groups: seq[string]

  CliHelp = object
    header*, footer*, description*, usage*, styles*: NimNode

  CliArg = object
    name: string
    ident: NimNode
    typeNode: NimNode

  CliCfg = object
    name*: string
    alias*: HashSet[string] # only supported in subcommands
    version*: NimNode
    stopWords*: seq[string]
    help: CliHelp
    defaultFlagType: NimNode
    required*: seq[string]
    settings*: set[CliSetting]
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

func err(c: CliCfg, msg: string) =
  ## quit with error while generating cli
  error "\nfailed to generate '" & c.name & "' hwylcli: \n" & msg

template `<<<`(s: string) {.used.} =
  let pos = instantiationInfo()
  debugEcho "$1:$2" % [pos.filename, $pos.line]
  debugEcho s
  debugEcho "^^^^^^^^^^^^^^^^^^^^^"

# some debug procs I use to wrap my ahead aroung the magic of *macro*
template `<<<`(n: NimNode) {.used.} =
  ## for debugging macros
  <<< treeRepr n

func `<<<`(f: CliFlag) {.used.}=
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
    s.add "$1 = $2\n" % [k,v]
  s.add ")"
  <<< s


func bad(n: NimNode, argument: string = "") =
  var msg = "unexpected node kind: " & $n.kind
  if argument != "":
    msg &= " for argument: " & argument
  error msg

# could I deduplicate these somehow? template?

func parseCliSetting(s: string): CliSetting =
  try: parseEnum[CliSetting](s)
  except: error "unknown cli setting: " & s


func parseCliSettings(cfg: var CliCfg, node: NimNode) =
  case node.kind
  of nnkCommand:
    for n in node[1..^1]:
      cfg.settings.incl parseCliSetting(n.strVal)
  of nnkCall:
    expectKind node[1], nnkStmtList
    for n in node[1]:
      cfg.settings.incl parseCliSetting(n.strVal)
  else: assert false

func parseCliFlagSetting(s: string): CliFlagSetting =
  try: parseEnum[CliFlagSetting](s)
  except: error "unknown cli flag setting: " & s


func parseCliFlagSettings(f: var CliFlag, node: NimNode) =
  case node.kind
  of nnkCommand:
    for n in node[1..^1]:
      f.settings.incl parseCliFlagSetting(n.strVal)
  of nnkCall:
    expectKind node[1], nnkStmtList
    for n in node[1]:
      f.settings.incl parseCliFlagSetting(n.strVal)
  else: assert false

func getFlagParamNode(node: NimNode): NimNode = 
  case node.kind
  of nnkStrLit:
    result = node
  of nnkStmtList:
    result = node[0]
  of nnkCommand:
    result = node[1]
  of nnkPrefix: # NOTE: should i double check prefix value?
    result = node[1]
  else: bad(node, "flag param")

# TODO: also accept the form `flag: "help"`
func parseFlagParams(f: var CliFlag, node: NimNode) =
  expectKind node, nnkStmtList
  for n in node:
    case n.kind
    of nnkCall, nnkCommand, nnkPrefix:
      case n[0].strVal
      of "help","?":
        f.help = getFlagParamNode(n[1])
      of "short", "-":
        let val = getFlagParamNode(n).strVal
        if val.len > 1:
          error "short flag must be a char"
        f.short = val[0].char
      of "*", "default":
        f.defaultVal = getFlagParamNode(n)
      of "i", "ident":
        f.ident = getFlagParamNode(n).strVal.ident
      of "T":
        f.typeNode = n[1]
      of "node":
        f.node = n[1]
      of "settings", "S":
        parseCliFlagSettings(f, n)
      else:
        error "unexpected setting: " & n[0].strVal
    else:
      bad(n, "flag params")

func newFlag(f: var CliFlag, n: NimNode) =
  f.name =
    case n[0].kind
    of nnkIdent, nnkStrLit: n[0].strVal
    of nnkAccQuoted: collect(for c in n[0]: c.strVal).join("")
    else: error "unexpected node kind for option"

  f.help = newLit("") # by default no string

  # assume a single character is a short flag
  if f.name.len == 1:
    f.short = f.name[0].char
  else:
    f.long = f.name

func parseCliFlag(n: NimNode): CliFlag =
  if n.kind notin [nnkCommand, nnkCall]:
    bad(n, "flags")

  newFlag(result, n)
  # option "some help desc"
  if n.kind  == nnkCommand:
    result.help = n[1]
  # option:
  #   T string
  #   help "some help description"
  else:
    parseFlagParams(result, n[1])

  if result.ident == nil:
    result.ident = result.name.ident

func postParse(cfg: var CliCfg) =
  if cfg.name == "":
    error "missing required option: name"

  if cfg.args.len != 0 and cfg.subcommands.len != 0:
    error "args and subcommands are mutually exclusive"

  let defaultTypeNode = cfg.defaultFlagType or ident"bool"
  for f in cfg.flagDefs.mitems:
    if f.typeNode == nil:
      f.typeNode = defaultTypeNode
    if f.group in ["", "global"]:
      cfg.flags.add f

  if cfg.args.len > 0:
    let count = cfg.args.filterIt(it.typeNode.kind == nnkBracketExpr).len
    if count > 1:
      cfg.err "more than one positional argument is variadic"

func parseCliFlags(cfg: var  CliCfg, node: NimNode) =
  var group: string
  expectKind node, nnkStmtList
  for n in node:
    var flag: CliFlag
    case n.kind
    of nnkCall, nnkCommand:
      flag = parseCliFlag(n)
      flag.group = group
      cfg.flagDefs.add flag
    of nnkBracket:
      group = n[0].strVal
      continue
    of nnkPrefix:
      if
        n[0].kind != nnkIdent or
        n[0].strVal != "^" or
        n.len != 2 or
        n[1].kind notin [nnkBracket, nnkIdent, nnkStrLit]:
        error "unexpected node in flags: " & $n.kind

      case n[1].kind
      of nnkBracket:
        cfg.inherit.groups.add n[1][0].strVal
        # cfg.inheritFlags.add n[1][0].strVal
      of nnkIdent, nnkStrLit:
        cfg.inherit.flags.add n[1].strval
      else: bad(n, "flag")
    else: bad(n, "flag")


func parseIdentLikeList(node: NimNode): seq[string] =
  template check =
    if n.kind notin [nnkStrLit,nnkIdent]:
      error "expected StrLit or Ident, got:" & $n.kind
  case node.kind
  of nnkCommand:
    for n in node[1..^1]:
      check
      result.add n.strVal
  of nnkCall:
    expectKind node[1], nnkStmtList
    for n in node[1]:
      check
      result.add n.strVal
  else: assert false

func parseCliBody(body: NimNode, name: string = "", root: bool= false): CliCfg

func isSubMarker(node: NimNode): bool =
  if node.kind != nnkBracket: return false
  if node.len != 1: return false
  if node[0].kind notin [nnkIdent, nnkStrLit]:
    return false
  result = true

func sliceStmts(node: NimNode): seq[
  tuple[name: string, slice: Slice[int]]
] =

  if not isSubMarker(node[0]):
    error "expected a subcommand delimiting line"

  var
    name: string = node[0][0].strVal
    start = 1
  let nodeLen = node.len()

  for i in 1..<nodeLen:
    if i == nodeLen - 1:
      result.add (name, start..i)
    elif isSubMarker(node[i]):
      result.add (name, start..(i - 1))
      name = node[i][0].strVal
      start = i + 1


func inheritFrom(child: var CliCfg, parent: CliCfg) =
  ## inherit settings from parent command
  var
    pflags: Table[string, CliFlag]
    pgroups: Table[string, seq[CliFlag]]
    flags: seq[string]
    groups: seq[string]

  flags &= child.inherit.flags
  groups &= child.inherit.groups

  for f in parent.flagDefs:
    pflags[f.name] = f
    if f.group in pgroups:
      pgroups[f.group].add f
    else:
      pgroups[f.group] = @[f]
 
  if "global" in pgroups:
    groups.add "global"

  for f in flags:
    if f notin pflags:
      error "expected parent command to have flag: " & f
    else:
      child.flags.add pflags[f]
      # so subcommands can continue the inheritance
      child.flagDefs.add pflags[f]

  for g in groups:
    if g notin pgroups:
      error "expected parent command to have flag group " & g
    else:
      child.flags.add pgroups[g]
      # so subcommands can continue the inheritance
      child.flagDefs.add pgroups[g]

func parseCliSubcommands(cfg: var CliCfg, node: NimNode) =
  expectKind node[1], nnkStmtList
  for (name, s) in sliceStmts(node[1]):
    var subCfg = parseCliBody(
      nnkStmtList.newTree(node[1][s]), cfg.name & " " & name
    )
    subCfg.subName = name
    cfg.stopWords.add name
    cfg.stopWords.add subCfg.alias.toSeq()
    cfg.subcommands.add subCfg

func parseHiddenFlags(cfg: var CliCfg, node: NimNode) =
  template check =
    if n.kind notin [nnkStrLit, nnkIdent]:
      error "expected string literal or ident"
  case node.kind
  of nnkCommand:
    for n in node[1..^1]:
      check
      cfg.hidden.add n.strVal
  of nnkCall:
    expectKind node[1], nnkStmtList
    for n in node[1]:
      check
      cfg.hidden.add n.strVal
  else: assert false

func addBuiltinFlags(cfg: var CliCfg) =
  # duplicated with below :/
  let shorts = cfg.flags.mapIt(it.short).toHashSet()

  let 
    name = cfg.name.replace(" ", "")
    printHelpName = ident("print" & name & "Help")
 
  if NoHelpFlag notin cfg.settings:
    let helpNode = quote do:
      `printHelpName`(); quit 0
    cfg.builtinFlags.add BuiltinFlag(
      name: "help",
      long: "help",
      help: newLit("show this help"),
      short: if 'h' notin shorts: 'h' else: '\x00',
      node: helpNode
    )

  if cfg.version != nil:
    let version = cfg.version
    let versionNode = quote do:
      echo `version`; quit 0

    cfg.builtinFlags.add BuiltinFlag(
      name:"version",
      long: "version",
      help: newLit("print version"),
      short: if 'V' notin shorts: 'V' else: '\x00',
      node: versionNode
    )


func pasrseCliAlias(cfg: var CliCfg, node: NimNode) =
  # node[0] is "alias"
  for n in node[1..^1]:
    case n.kind
    of nnkIdent, nnkStrLit:
      cfg.alias.incl n.strVal
    of nnkAccQuoted:
      let s = n.mapIt(it.strVal).join("")
      cfg.alias.incl s
    else: bad(n, "alias")

func postPropagateCheck(c: CliCfg) =
  ## verify the cli is valid
  var
    short: Table[char, CliFlag]
    long: Table[string, CliFlag]

  for f in c.flags:
    if f.short != '\x00':
      if f.short in short:
        let conflict = short[f.short]
        c.err "conflicting short flags for: " & f.name & " and " & conflict.name
        # hwylCliImplError c, (
        #   "conflicting short flags for: " & f.name & " and " & conflict.name
        # )

      else:
        short[f.short] = f

    if f.long in long:
      let conflict = long[f.long]
      c.err "conflicting long flags for: " & f.name & " and " & conflict.name
    else:
      long[f.long] = f

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
    postPropagateCheck child


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
  ## `

  expectLen node, 2
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
      error "expected list of arguments for help"
    for n in node[1]:
      expectLen n, 2
      let id = n[0].strVal
      var val: NimNode
      case n.kind
      of nnkCommand:
        val =n[1]
      of nnKCall:
        val = n[1][0]
      else: bad(n, id)
      case id:
      of "usage": help.usage = val
      of "description": help.description = val
      of "header": help.header = val
      of "footer": help.footer = val
      of "styles": help.styles = val
      else: error "unknown help option: " & id
  else: bad(node, "help")
  c.help = help

func badNode(c: CliCfg, node: NimNode, msg: string) =
  c.err "unexpected node kind: " & $node.kind & "\n" & msg

func isSeq(arg: CliArg): bool =
  # NOTE: does this need to be more rigorous?
  arg.typeNode.kind == nnkBracketExpr

func parseCliArg(c: CliCfg, node: NimNode): CliArg =
  expectLen node, 2
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
      else: bad(n, id)
      case id:
      of "T": result.typeNode = val
      of "ident": result.ident = val
      else: c.err("unknown cli param: " & id & "provided for arg: " & result.name)
  of nnkIdent, nnkBracketExpr:
    result.typeNode = node[1]
  else:
    c.badNode(node[1], "parsing cli arg: " & result.name)
  if result.ident == nil:
    result.ident = ident(result.name)

func parseCliArgs(c: var CliCfg, node: NimNode) =
  if node.kind != nnkStmtList:
    bad(node, "expected node kind nnkStmtList")
  for n in node:
    c.args.add parseCliArg(c, n)

func parseCliBody(body: NimNode, name = "", root = false): CliCfg =
  result.name = name
  result.root = root
  for node in body:
    if node.kind  notin [nnkCall, nnkCommand, nnkPrefix]:
      error "unexpected node kind: " & $node.kind
    let name = node[0].strVal
    case name:
      of "name":
        expectKind node[1], nnkStrLit
        result.name = node[1].strVal
      of "alias":
        if root: error "alias not supported for root command"
        pasrseCliAlias(result, node)
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
        result.stopWords = parseIdentLikeList(node)
      of "subcommands":
        parseCliSubcommands(result, node)
      of "hidden":
        parseHiddenFlags(result, node)
      of "run":
        result.run = node[1]
      of "required":
        result.required = parseIdentLikeList(node)
      of "preSub":
        result.preSub = node[1]
      of "postSub":
        result.postSub = node[1]
      of "defaultFlagType":
        result.defaultFlagType = node[1]
      of "positionals":
        parseCliArgs result, node[1]
      else:
        error "unknown hwylCli setting: " & name

  postParse result

  # TODO: validate "required" flags exist here?
  result.addBuiltinFlags()

  if root:
    propagate(result)

func flagToTuple(c: CliCfg, f: CliFlag | BuiltinFlag): NimNode =
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

  # BUG: if f.defaultVal is @[] `$` fails
  # but works with `newSeq[T]()`
  # could replace "defaultVal" with newSeq[T]()
  # under the hood when parsing type/val

  quote do:
    (`short`, `long`, `help`, bbEscape($`defaultVal`))

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
  quit $(bb("error ", "red") & bb(msg))

func defaultUsage(cfg: CliCfg): NimNode =
  # TODO: attempt to handle pos args
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
  newLit(s)

func generateCliHelpProc(cfg: CliCfg, printHelpName: NimNode): NimNode =
  let
    description = cfg.help.description or newLit""
    header = cfg.help.header or newLit""
    footer = cfg.help.footer or newLit""
    usage  = cfg.help.usage or defaultUsage(cfg)
    helpFlags = cfg.flagsArray()
    subcmds = cfg.subCmdsArray()
    styles = cfg.help.styles or (quote do: HwylCliStyles())

  result = quote do:
    proc `printHelpName`() =
      let help =
        newHwylCliHelp(
          header = `header`,
          footer = `footer`,
          usage = `usage`,
          description = `description`,
          subcmds = `subcmds`,
          flags = `helpFlags`,
          styles = `styles`,
        )
      echo help.render().bb()

proc checkVal(p: OptParser) =
  if p.val == "":
    hwylCliError(
      "expected value for flag: [b]" & p.key
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
      "failed to parse value for [b]" & p.key & "[/] as integer: [b]" & p.val
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
      "failed to parse value for [b]" & p.key & "[/] as enum: [b]" & p.val & "[/] expected one of: " & choices
    )

proc parse*(p: OptParser, target: var float) =
  checkVal p
  try:
    target = parseFloat(p.val)
  except:
    hwylCliError(
      "failed to parse value for [b]" & p.key & "[/] as float: [b]" & p.val
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

func shortLongCaseStmt(cfg: CliCfg, printHelpName: NimNode, version: NimNode): NimNode =
  var caseStmt = nnkCaseStmt.newTree()
  if NoNormalize notin cfg.settings:
    caseStmt.add nnkCall.newTree(ident"optionNormalize", ident"key")
  else:
    caseStmt.add ident"key"

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

  caseStmt.add nnkElse.newTree(quote do: hwylCliError("unknown flag: [b]" & key))

  result = nnkStmtList.newTree(caseStmt)

func isBool(f: CliFlag): bool =
  f.typeNode == ident"bool"

func isCount(f: CliFlag): bool =
  f.typeNode == ident"Count"


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
  except: hwylCliError("failed to parse as float: [b]" & arg)

func parseArgs*(arg: string, target: var string) =
  target = arg

proc parseArgs*(arg: string, target: var int) =
  try: target = parseInt(arg)
  except: hwylCliError("failed to parse as integer: [b]" & arg)

proc parseArgs*[E: enum](arg: string, target: var E) =
  try: target = parseEnum[E](arg)
  except:
    let choices = enumNames(E).join(",")
    hwylCliError("failed to parse as enum: [b]" & arg & "[/], expected one of: " & choices)

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
  let flagSet = ident"flagSet"
  let subcmd = ident"subcmd"
  var required, default: seq[CliFlag]

  for f in cfg.flags:
    if f.name in cfg.required and f.defaultVal == nil:
      required.add f
    elif f.defaultVal != nil:
      default.add f

  for f in required:
    let flagLit = f.literalFlags
    let name = newLit(f.name)
    body.add quote do:
      if `name` notin `flagSet`:
        hwylCliError("expected a value for flag: " & `flagLit`)

  for f in default:
    let
      name = newLit(f.name)
      target = f.ident
      defaultVal = f.defaultVal
    body.add quote do:
      if `name` notin `flagSet`:
        `target` = `defaultVal`


  if hasSubcommands cfg:
    body.add quote do:
      if result.len == 0:
        hwylCliError("expected subcommand")
      `subcmd` = result[0]
      result = result[1..^1]


  elif cfg.args.len == 0:
    body.add quote do:
      if result.len > 0:
        hwylCliError("got unexpected positionals args: [b]" & result.join(" "))

  elif cfg.args.len > 0:
    genPosArgHandler cfg, body

func hwylCliImpl(cfg: CliCfg): NimNode

func genSubcommandHandler(cfg: CliCfg): NimNode =
  let subcmd = ident"subcmd"
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
      hwylCliError("unknown subcommand: [b]" & `subcmd`)
  )

  result.add subCommandCase

# TODO: collect all strings into a seq and handle prior to subcomamnd parsing?
# subcommands are really just a special case of positional args handling
func positionalArgsOfBranch(cfg: CliCfg): NimNode =
  result = nnkOfBranch.newTree(ident"cmdArgument")
  # TODO: utilize the NoPositional setting here?
  # if cfg.args.len == 0 and cfg.subcommands.len == 0:
  #   result.add quote do:
  #     hwylCliError("unexpected positional argument: [b]" & p.key)
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
        opChars = {','}
      )
  )

  # TODO: first key needs to be normalized?
  # TODO: don't use getopt? use p.next() instead?
  parserBody.add nnkForStmt.newTree(
    ident"kind", ident"key", ident"val",
    # nnkCall.newTree(nnkDotExpr.newTree(optParser,ident("getopt"))),
    nnkCall.newTree(ident"getopt", optParser),
    nnkStmtList.newTree(
      # # for debugging..
      # quote do:
      #   echo `kind`,"|",`key`,"|",`val`
      # ,
      nnkCaseStmt.newTree(
        ident"kind",
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

