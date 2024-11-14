##[
  # HwylCli
]##

import std/[
  macros, os, sequtils,
  sets, strutils, tables,
  sugar
]
import ./[bbansi, parseopt3]
export parseopt3, sets, bbansi

type
  HwylFlagHelp* = tuple
    short, long, description: string
  HwylSubCmdHelp* = tuple
    name, aliases, desc: string
  HwylCliStyleSetting = enum
    Aliases
  HwylCliStyles* = object
    header* = "bold cyan"
    flagShort* = "yellow"
    flagLong* = "magenta"
    flagDesc* = ""
    cmd* = "bold"
    settings*: set[HwylCliStyleSetting] = {Aliases}
  HwylCliHelp* = object
    header*, footer*, description*, usage*: string
    subcmds*: seq[HwylSubCmdHelp]
    flags*: seq[HwylFlagHelp]
    styles*: HwylCliStyles
    subcmdLen*, subcmdDescLen*, shortArgLen*, longArgLen*, descArgLen*: int

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
  # TODO: incorporate into "styles?"
  result.subcmdLen = 8
  for f in flags:
    result.shortArgLen = max(result.shortArgLen, f.short.len)
    result.longArgLen  = max(result.longArgLen, f.long.len)
    result.descArgLen  = max(result.descArgLen, f.description.len)
  for s in result.subcmds:
    result.subcmdLen = max(result.subcmdLen, s.name.len)
    result.subcmdDescLen = max(result.subcmdDescLen, s.desc.len)

func render*(cli: HwylCliHelp, f: HwylFlagHelp): string = 
  result.add "  "
  if f.short != "":
    result.add "[" & cli.styles.flagShort & "]"
    result.add "-" & f.short.alignLeft(cli.shortArgLen)
    result.add "[/" & cli.styles.flagShort & "]"
  else:
    result.add " ".repeat(1 + cli.shortArgLen)
  result.add " "
  if f.long != "":
    result.add "[" & cli.styles.flagLong & "]"
    result.add "--" & f.long.alignLeft(cli.longArgLen)
    result.add "[/" & cli.styles.flagLong & "]"
  else:
    result.add " ".repeat(2 + cli.longArgLen)

  result.add " "

  if f.description != "":
    result.add "[" & cli.styles.flagDesc & "]"
    result.add f.description
    result.add "[/" & cli.styles.flagDesc & "]"
  result.add "\n"

func render*(cli: HwylCliHelp, subcmd: HwylSubCmdHelp): string =
  result.add "  "
  result.add "[" & cli.styles.cmd & "]"
  result.add subcmd.name.alignLeft(cli.subcmdLen)
  result.add "[/]"
  result.add " "
  result.add subcmd.desc.alignLeft(cli.subcmdDescLen)
  result.add "\n"


# TODO: split this into separate procs to make overriding more fluid
func render*(cli: HwylCliHelp): string =
  if cli.header != "":
    result.add cli.header
    result.add "\n"
  if cli.usage != "":
    result.add "[" & cli.styles.header & "]"
    result.add "usage[/]:\n"
    result.add indent(cli.usage, 2 )
  result.add "\n"
  if cli.description != "":
    result.add "\n"
    result.add cli.description
    result.add "\n"
  if cli.subcmds.len > 0:
    result.add "\n"
    result.add "[" & cli.styles.header & "]"
    result.add "subcommands[/]:\n"
    for s in cli.subcmds:
      result.add cli.render(s)
  if cli.flags.len > 0:
    result.add "\n"
    result.add "[" & cli.styles.header & "]"
    result.add "flags[/]:\n"
    for f in cli.flags:
      result.add render(cli,f)
  if cli.footer != "":
    result.add cli.footer

proc bb*(cli: HwylCliHelp): BbString = 
  result = bb(render(cli))

# ----------------------------------------

type
  Count* = object ## Count type for an incrementing flag
    val*: int

type
  CliSetting* = enum
    # Propagate,  ## Include parent command settings in subcommand
    GenerateOnly, ## Don't attach root `runProc()` node
    NoHelpFlag,   ## Remove the builtin help flag
    ShowHelp,     ## If cmdline empty show help
    NoNormalize   ## Don't normalize flags and commands

  BuiltinFlag = object
    name*: string
    short*: char
    long*: string
    help*: NimNode
    node: NimNode

  CliFlag = object
    name*: string
    ident*: NimNode
    default*: NimNode
    typeNode*: NimNode
    short*: char
    long*: string
    help*: NimNode
    group*: string
    inherited*: bool

  Inherit = object
    settings: set[CliSetting]
    flags: seq[string]
    groups: seq[string]

  CliHelp = object
    header*, footer*, description*, usage*, styles*: NimNode

  CliCfg = object
    name*: string
    alias*: HashSet[string]
    stopWords*: seq[string]
    help: CliHelp
    hidden*: seq[string]
    subcommands: seq[CliCfg]
    settings*: set[CliSetting]
    preSub*, postSub*, pre*, post*, run*: NimNode
    subName*: string # used for help the generator
    version*: NimNode
    flags*: seq[CliFlag]
    builtinFlags*: seq[BuiltinFlag]
    flagDefs*: seq[CliFlag]
    required*: seq[string]
    inherit*: Inherit
    root*: bool

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
        f.default = getFlagParamNode(n)
      of "i", "ident":
        f.ident = getFlagParamNode(n).strVal.ident
      of "T":
        f.typeNode = n[1]
      else:
        error "unexpected setting: " & n[0].strVal
    else:
      bad(n, "flag params")

func startFlag(f: var CliFlag, n: NimNode) =
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

  startFlag(result, n)
  # option "some help desc"
  if n.kind  == nnkCommand:
    result.help = n[1]
  # option:
  #   help "some help description"
  else:
    parseFlagParams(result, n[1])

  if result.ident == nil:
    result.ident = result.name.ident
  if result.typeNode == nil:
    result.typeNode = ident"bool"

# TODO: change how this works?
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

  cfg.flags = cfg.flagDefs.filterIt(it.group in ["", "global"])

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

func propagate(c: var CliCfg) =
  for child in c.subcommands.mitems:
    child.pre = c.preSub
    child.post = c.postSub
    child.inheritFrom(c)
    propagate(child)



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
      of "settings":
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
      else:
        error "unknown hwylCli setting: " & name

  if result.name == "":
    error "missing required option: name"

  # TODO: validate "required" flags exist here
  result.addBuiltinFlags()

  if root:
    propagate(result)

func flagToTuple(f: CliFlag | BuiltinFlag): NimNode =
  let
    short =
      if f.short != '\x00': newLit($f.short)
      else: newLit("")
    long = newLit(f.long)
    help = f.help
  quote do:
    (`short`, `long`, `help`)

func flagsArray(cfg: CliCfg): NimNode =
  result = newTree(nnkBracket)
  for f in cfg.flags:
    if f.name in cfg.hidden: continue
    result.add f.flagToTuple()
  for f in cfg.builtinFlags:
    result.add f.flagToTuple()

func subCmdsArray(cfg: CliCfg): NimNode =
  result = newTree(nnkBracket)
  for s in cfg.subcommands:
    let cmd = newLit(s.subName)
    let aliases = newLit(s.alias.mapIt("($1)" % [it]).join(" "))
    let desc = s.help.description or newLit("")
    result.add quote do:
      (`cmd`, `aliases`, `desc`)

proc hwylCliError*(msg: string | BbString) =
  quit $(bb("error ", "red") & bb(msg))

func defaultUsage(cfg: CliCfg): NimNode =
  var s = "[b]" & cfg.name & "[/]"
  if cfg.subcommands.len > 0:
    s.add " [bold italic]subcmd[/]"
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
  <<< usage
  result = quote do:
    proc `printHelpName`() =
      echo bb(render(newHwylCliHelp(
        header = `header`,
        footer = `footer`,
        usage = `usage`,
        description = `description`,
        subcmds = `subcmds`,
        flags = `helpFlags`,
        styles = `styles`,
      )))

proc preParseCheck(key: string, val: string) =
  if val == "":
    hwylCliError(
      "expected value for flag: [b]" & key
    )

proc parse*(p: OptParser, key: string, val: string, target: var bool) =
  target = true

proc parse*(p: OptParser, key: string, val: string, target: var string) =
  preParseCheck(key, val)
  target = val

proc parse*(p: OptParser, key: string, val: string, target: var int) =
  preParseCheck(key, val)
  try:
    target = parseInt(val)
  except:
    hwylCliError(
      "failed to parse value for [b]" & key & "[/] as integer: [b]" & val
    )

macro enumNames(a: typed): untyped =
  ## unexported macro copied from std/enumutils
  result = newNimNode(nnkBracket)
  for ai in a.getType[1][1..^1]:
    assert ai.kind == nnkSym
    result.add newLit ai.strVal

proc parse*[E: enum](p: OptParser, key: string, val: string, target: var E) =
  preParseCheck(key, val)
  try:
    target = parseEnum[E](val)
  except:
    let choices = enumNames(E).join(",")
    hwylCliError(
      "failed to parse value for [b]" & key & "[/] as enum: [b]" & val & "[/] expected one of: " & choices
    )

proc parse*(p: OptParser, key: string, val: string, target: var float) =
  preParseCheck(key, val)
  try:
    target = parseFloat(val)
  except:
    hwylCliError(
      "failed to parse value for [b]" & key & "[/] as float: [b]" & val
    )

proc parse*[T](p: OptParser, key: string, val: string, target: var seq[T]) =
  preParseCheck(key, val)
  var parsed: T
  parse(p, key, val, parsed)
  target.add parsed

proc parse*(p: OptParser, key: string, val: string, target: var Count) =
  # if value set to that otherwise increment
  if val != "":
    var num: int
    parse(p, key, val, num)
    target.val = num
  else:
    inc target.val

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
    branch.add quote do:
      flagSet.incl `name`
      parse(p, key, val, `varName`)

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

func setFlagVars(cfg: CliCfg): NimNode =
  ## generate all variables not covered in global module
  result = nnkVarSection.newTree()
  let flags =
    if cfg.root: cfg.flags
    else: cfg.flags.filterIt(it.group != "global")

  result.add flags.mapIt(
          nnkIdentDefs.newTree(it.ident, it.typeNode, newEmptyNode())
        )

func literalFlags(f: CliFlag): NimNode =
  var flags: seq[string]
  if f.short != '\x00': flags.add "[b]" &  "-" & $f.short & "[/]"
  if f.long != "": flags.add "[b]" & "--" & f.long & "[/]"
  result = newLit(flags.join("|"))

func addPostParseCheck(cfg: CliCfg, body: NimNode) =
  ## generate block to set defaults and check for required flags
  let flagSet = ident"flagSet"
  var required, default: seq[CliFlag]

  for f in cfg.flags:
    if f.name in cfg.required and f.default == nil:
      required.add f
    elif f.default != nil:
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
      default = f.default
    body.add quote do:
      if `name` notin `flagSet`:
        `target` = `default`

func hwylCliImpl(cfg: CliCfg): NimNode

func genSubcommandHandler(cfg: CliCfg): NimNode =
  let args = ident"args"
  result = nnkStmtList.newTree()
  result.add quote do:
    if `args`.len == 0:
      hwylCliError("expected subcommand")

  var subCommandCase = nnkCaseStmt.newTree()
  if NoNormalize notin cfg.settings:
    subCommandCase.add(quote do: optionNormalize(`args`[0]))
  else:
    subCommandCase.add(quote do: `args`[0])

  for sub in cfg.subcommands:
    var branch = nnkOfBranch.newTree()
    branch.add newLit(optionNormalize(sub.subName))
    for a in sub.alias:
      branch.add newLit(optionNormalize(a))
    branch.add hwylCliImpl(sub)
    subcommandCase.add branch

  subcommandCase.add nnkElse.newTree(
    quote do:
      hwylCliError("unknown subcommand: [b]" & `args`[0])
  )

  result.add subCommandCase



func hwylCliImpl(cfg: CliCfg): NimNode =
  let
    version = cfg.version or newLit("")
    name = cfg.name.replace(" ", "")
    printHelpName = ident("print" & name & "Help")
    parserProcName = ident("parse" & name)
    args = ident"args"
    optParser = ident("p")
    cmdLine = ident"cmdLine"
    flagSet = ident"flagSet"
    kind = ident"kind"
    key = ident"key"
    val = ident"val"
    (longNoVal, shortNoVal) = cfg.getNoVals()
    printHelpProc = generateCliHelpProc(cfg, printHelpName)
    flagVars = setFlagVars(cfg)

  result = newTree(nnkStmtList)

  var
    parserBody = nnkStmtList.newTree()
    stopWords = nnkBracket.newTree(newLit("--"))

  for w in cfg.stopWords:
    stopWords.add newLit(w)

  stopWords = nnkPrefix.newTree(ident"@", stopWords)

  # should this a CritBitTree?
  parserBody.add quote do:
    var `flagSet` {.used.}: HashSet[string]

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
  # TODO: first key needs to be normalized
  parserBody.add nnkForStmt.newTree(
    kind, key, val,
    nnkCall.newTree(nnkDotExpr.newTree(optParser,ident("getopt"))),
    nnkStmtList.newTree(
      # # for debugging..
      # quote do:
      #   echo `kind`,"|",`key`,"|",`val`
      # ,
      nnkCaseStmt.newTree(
        kind,
        nnkOfBranch.newTree(ident("cmdError"), quote do: hwylCliError(p.message)),
        nnkOfBranch.newTree(ident("cmdEnd"), quote do: assert false),
        # TODO: add nArgs to change how cmdArgument is handled ...
        nnkOfBranch.newTree(ident("cmdArgument"),
          quote do:
            result.add `key`
        ),
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

  let runProcName = ident("run" & name)
  let runBody = nnkStmtList.newTree()
  addPostParseCheck(cfg, parserBody)
  # move to proc?
  if cfg.pre != nil:
    runBody.add cfg.pre
  if cfg.run != nil:
    runBody.add cfg.run
  if cfg.post != nil:
    runBody.add cfg.post

  if cfg.subcommands.len > 0:
    runBody.add genSubcommandHandler(cfg)

  result.add quote do:
    # block:
      `printHelpProc`
      `flagVars`
      proc `parserProcName`(`cmdLine`: openArray[string] = commandLineParams()): seq[string] =
        `parserBody`

      proc `runProcName`(`cmdLine`: openArray[string] = commandLineParams()) =
        let `args` {.used.} = `parserProcName`(`cmdLine`)
        `runBody`

  if cfg.root:
    if GenerateOnly notin cfg.settings:
      result.add quote do:
        `runProcName`()
  else:
    result.add quote do:
      `runProcName`(`args`[1..^1])

macro hwylCli*(body: untyped) =
  ## generate a CLI styled by `hwylterm` and parsed by `parseopt3`
  var cfg = parseCliBody(body, root = true)
  hwylCliImpl(cfg)

