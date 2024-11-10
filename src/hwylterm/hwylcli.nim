##[
  # HwylCli
]##

import std/[
  macros, os, sequtils,
  sets, strutils, tables,
  sugar
]
import ./[bbansi, parseopt3]
export parseopt3, sets

type
  HwylFlagHelp* = tuple
    short, long, description: string
  HwylSubCmdHelp* = tuple
    name, desc: string
  HwylCliStyles* = object
    hdr = "bold cyan"
    shortFlag = "yellow"
    longFlag = "magenta"
    descFlag = ""
    cmd = "bold"
  HwylCliHelp* = object
    usage*: string
    desc*: string
    subcmds: seq[HwylSubCmdHelp]
    flags*: seq[HwylFlagHelp]
    styles*: HwylCliStyles
    subcmdLen, subcmdDescLen, shortArgLen, longArgLen, descArgLen: int

# NOTE: do i need both strips?
func firstLine(s: string): string =
  s.strip().dedent().strip().splitlines()[0]
func newHwylCliHelp*(
  usage = "",
  desc = "",
  subcmds: openArray[HwylSubCmdHelp] = @[],
  flags: openArray[HwylFlagHelp] = @[],
  styles = HwylCliStyles()
): HwylCliHelp =
  result.desc = dedent(desc).strip()
  result.subcmds = 
    subcmds.mapIt((it.name, it.desc.firstLine))
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

func flagHelp(cli: HwylCliHelp, f: HwylFlagHelp): string =
  result.add "  "
  if f.short != "":
    result.add "[" & cli.styles.shortFlag & "]"
    result.add "-" & f.short.alignLeft(cli.shortArgLen)
    result.add "[/]"
  else:
    result.add " ".repeat(1 + cli.shortArgLen)

  result.add " "
  if f.long != "":
    result.add "[" & cli.styles.longFlag & "]"
    result.add "--" & f.long.alignLeft(cli.longArgLen)
    result.add "[/]"
  else:
    result.add " ".repeat(2 + cli.longArgLen)

  result.add " "

  if f.description != "":
    result.add "[" & cli.styles.descFlag & "]"
    result.add f.description
    result.add "[/]"
  result.add "\n"

func subCmdLine(cli: HwylCliHelp, subcmd: HwylSubCmdHelp): string =
  result.add "  "
  result.add "[" & cli.styles.cmd & "]"
  result.add subcmd.name.alignLeft(cli.subcmdLen)
  result.add "[/]"
  result.add " "
  result.add subcmd.desc.alignLeft(cli.subcmdDescLen)
  result.add "\n"

proc bbImpl(cli: HwylCliHelp): string =
  if cli.usage != "":
    result.add "[" & cli.styles.hdr & "]"
    result.add "usage[/]:\n"
    result.add indent(cli.usage, 2 )
  result.add "\n"
  if cli.desc != "":
    result.add "\n"
    result.add cli.desc
  result.add "\n"
  if cli.subcmds.len > 0:
    result.add "\n"
    result.add "[" & cli.styles.hdr & "]"
    result.add "subcommands[/]:\n"
    for s in cli.subcmds:
      result.add cli.subcmdLine(s)
  if cli.flags.len > 0:
    result.add "\n"
    result.add "[" & cli.styles.hdr & "]"
    result.add "flags[/]:\n"
    for f in cli.flags:
      result.add flagHelp(cli,f)

proc bb*(cli: HwylCliHelp): BbString = 
  result = bb(bbImpl(cli))

proc `$`*(cli: HwylCliHelp): string =
  result = $bb(cli)

# ----------------------------------------

type
  CliSetting = enum
    NoHelpFlag, NoArgsShowHelp
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
  CliCfg = object
    stopWords*: seq[string]
    styles: NimNode
    hidden*: seq[string]
    subcommands: seq[CliCfg]
    settings*: set[CliSetting]
    preSub*, postSub*, pre*, post*, run*: NimNode
    desc*: NimNode
    name*: string
    subName*: string # used for help the generator
    version*, usage*: NimNode
    flags*: seq[CliFlag]
    builtinFlags*: seq[BuiltinFlag]
    flagGroups: Table[string, seq[CliFlag]]
    required*: seq[string]
    inheritFlags*: seq[string]

{.push hint[XDeclaredButNotUsed]:off .}
# some debug procs I use to wrap my ahead aroung the magic of *macro*
func `<<<`(n: NimNode) =
  ## for debugging macros
  debugEcho treeRepr n
func `<<<`(s: string) =
  debugEcho s

func bad(n: NimNode, argument: string = "") =
  var msg = "unexpected node kind: " & $n.kind
  if argument != "":
    msg &= " for argument: " & argument
  error msg
{.pop.}

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
    result.typeNode = ident"string"

# TODO: change how this works?
func parseCliFlags(cfg: var  CliCfg, node: NimNode) =
  var group: string
  expectKind node, nnkStmtList
  for n in node:
    var flag: CliFlag
    case n.kind
    of nnkCall, nnkCommand:
      flag = parseCliFlag(n)
      if group == "":
        cfg.flags.add flag
      else:
        if group notin cfg.flagGroups: cfg.flagGroups[group] = @[flag]
        else: cfg.flagGroups[group].add flag
    of nnkBracket:
      group = n[0].strVal
      continue
    of nnkPrefix:
      if n[0].kind != nnkIdent and n[0].strVal != "^":
        error "unexpected node in flags: " &  $n.kind
      expectKind n[1], nnkBracket
      cfg.inheritFlags.add n[1][0].strVal
    # of nnkPrefix:
    #   if n[0].strVal != "---":
    #     bad(n[0], "flag group prefix")
    #   group = n[1].strVal
    #   continue
    else:  bad(n, "flag")

  debugEcho cfg.flagGroups.keys().toSeq()

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

func parseCliBody(body: NimNode, name: string = ""): CliCfg

func isSubMarker(node: NimNode): bool =
  if node.kind == nnkPrefix:
    if eqIdent(node[0], "---"):
      result = true

func sliceStmts(node: NimNode): seq[
  tuple[name: string, slice: Slice[int]]
] =
  if not isSubMarker(node[0]):
    error "expected a subcommand delimiting line"

  var
    name: string = node[0][1].strVal
    start = 1
  let nodeLen = node.len()

  for i in 1..<nodeLen:
    if i == nodeLen - 1:
      result.add (name, start..i)
    elif isSubMarker(node[i]):
      result.add (name, start..(i - 1))
      name = node[i][1].strVal
      start = i + 1


func addInheritedFlags(child: var CliCfg, parent: CliCfg, self = false) =
  let names = child.flags.mapIt(it.name)
  var groups: seq[string]
  if not self:
    groups.add child.inheritFlags

  # autoinherit the "global" flags
  if "global" in parent.flagGroups:
    groups.add "global"

  for g in groups:
    if g notin parent.flagGroups:
      debugEcho parent.flagGroups.keys().toSeq()
      error "expected flag group: " & g & " to exist in parent command"
    for f in parent.flagGroups[g]:
      if f.name in names:
        error "global flag " & f.name & " conflicts with command flag"
      child.flags.add f
 
func parseCliSubcommands(cfg: var CliCfg, node: NimNode) =
  expectKind node[1], nnkStmtList
  for (name, s) in sliceStmts(node[1]):
    cfg.stopWords.add name
    var subCfg = parseCliBody(
      nnkStmtList.newTree(node[1][s]), cfg.name & " " & name
    )
    subCfg.subName = name
    subCfg.addInheritedFlags(cfg)
    cfg.subcommands.add  subCfg

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

func parseCliBody(body: NimNode, name = ""): CliCfg =
  result.name = name
  for call in body:
    if call.kind  notin [nnkCall, nnkCommand, nnkPrefix]:
      error "unexpected node kind: " & $call.kind
    let name = call[0].strVal
    case name:
      of "name":
        expectKind call[1], nnkStrLit
        result.name = call[1].strVal
      of "version", "V":
        result.version = call[1]
      of "usage", "?":
        result.usage = call[1]
      of "description", "...":
        result.desc = call[1]
      of "flags":
        parseCliFlags(result, call[1])
      of "settings":
        parseCliSettings(result, call)
      of "stopWords":
        result.stopWords = parseIdentLikeList(call)
      of "subcommands":
        parseCliSubcommands(result, call)
      of "hidden":
        parseHiddenFlags(result, call)
      of "run":
        result.run = call[1]
      of "styles":
        result.styles = call[1]
      of "required":
        result.required = parseIdentLikeList(call)
      of "preSub":
        result.preSub = call[1]
      of "postSub":
        result.postSub = call[1]
      else:
        error "unknown hwylCli setting: " & name

  for sub in result.subcommands.mitems:
    sub.pre = result.preSub
    sub.post = result.postSub

  result.addInheritedFlags(result, self = true)

  if result.name == "":
    error "missing required option: name"

  result.addBuiltinFlags()

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
    let desc = s.desc or newLit("")
    result.add quote do:
      (`cmd`, `desc`)

proc hwylCliError(msg: string | BbString) = 
  quit $(bb("error ", "red") & bb(msg))

func defaultUsage(cfg: CliCfg): NimNode =
  var s = "[b]" & cfg.name & "[/]"
  if cfg.subcommands.len > 0:
    s.add " [bold italic]subcmd[/]"
  s.add " [[[faint]flags[/]]"
  newLit(s)

func generateCliHelperProc(cfg: CliCfg, printHelpName: NimNode): NimNode =
  let
    desc = cfg.desc or newLit("")
    usage  = cfg.usage or defaultUsage(cfg)
    helpFlags = cfg.flagsArray()
    subcmds = cfg.subCmdsArray()
    styles = cfg.styles or (quote do: HwylCliStyles())

  result = quote do:
    proc `printHelpName`() =
      echo newHwylCliHelp(
        desc = `desc`,
        usage = `usage`,
        subcmds = `subcmds`,
        flags = `helpFlags`,
        styles = `styles`,
      )

proc parse*(p: OptParser, key: string, val: string, target: var bool) =
  target = true

proc parse*(p: OptParser, key: string, val: string, target: var string) =
  target = val

proc parse*(p: OptParser, key: string, val: string, target: var int) =
  try:
    target = parseInt(val)
  except:
    hwylCliError(
      "failed to parse value for [b]" & key & "[/] as integer: [b]" & val
    )

proc parse*(p: OptParser, key: string, val: string, target: var float) =
  try:
    target = parseFloat(val)
  except:
    hwylCliError(
      "failed to parse value for [b]" & key & "[/] as float: [b]" & val
    )

proc parse[T](p: OptParser, key: string, val: string, target: var seq[T]) =
  var parsed: T
  parse(p, key, val, parsed)
  target.add parsed

func shortLongCaseStmt(cfg: CliCfg, printHelpName: NimNode, version: NimNode): NimNode = 
  var caseStmt = nnkCaseStmt.newTree(ident("key"))
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
    if f.long != "": branch.add(newLit(f.long))
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

func getNoVals(cfg: CliCfg): tuple[long: NimNode, short: NimNode] =
  let boolFlags = cfg.flags.filterIt(it.isBool)
  let long =
    nnkBracket.newTree(
      (boolFlags.mapIt(it.long) & cfg.builtinFlags.mapIt(it.long)).filterIt(it != "").mapIt(newLit(it))
    )
  let short =
    nnkCurly.newTree(
      (boolFlags.mapIt(it.short) & cfg.builtinFlags.mapIt(it.short)).filterIt(it != '\x00').mapIt(newLit(it))
    )
  result = (nnkPrefix.newTree(ident"@",long), short)

func setFlagVars(cfg: CliCfg): NimNode =
  result = nnkVarSection.newTree().add(
    cfg.flags.mapIt(
      nnkIdentDefs.newTree(it.ident, it.typeNode, newEmptyNode())
    )
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

func hwylCliImpl(cfg: CliCfg, root = false): NimNode =
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
    printHelperProc = generateCliHelperProc(cfg, printHelpName)
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
    var `flagSet`: HashSet[string]

  parserBody.add(
    quote do:
      var `optParser` = initOptParser(
        @`cmdLine`,
        longNoVal = `longNoVal`,
        shortNoVal = `shortNoVal`,
        stopWords = `stopWords`
      )
  )

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

  if NoArgsShowHelp in cfg.settings:
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
    var handleSubCommands = nnkStmtList.newTree()
    handleSubCommands.add quote do:
      if `args`.len == 0:
        hwylCliError("expected subcommand")

    var subCommandCase = nnkCaseStmt.newTree(
      quote do: `args`[0]
    )
    for sub in cfg.subcommands:
      subCommandCase.add nnkOfBranch.newTree(
        newLit(sub.subName),
        hwylCliImpl(sub)
      )

    subcommandCase.add nnkElse.newTree(
      quote do:
        hwylCliError("unknown subcommand " & `args`[0])
    )

    runBody.add handleSubCommands.add subCommandCase

  result.add quote do:
    # block:
      `printHelperProc`
      `flagVars`
      proc `parserProcName`(`cmdLine`: openArray[string] = commandLineParams()): seq[string] =
        `parserBody`

      proc `runProcName`(`cmdLine`: openArray[string] = commandLineParams()) =
        let `args` = `parserProcName`(`cmdLine`)
        `runBody`

  if root:
    result.add quote do:
      `runProcName`()
  else:
    result.add quote do:
      `runProcName`(`args`[1..^1])

macro hwylCli*(body: untyped) =
  ## generate a CLI styled by `hwylterm` and parsed by `parseopt3`
  var cfg = parseCliBody(body)
  hwylCliImpl(cfg, root = true)

