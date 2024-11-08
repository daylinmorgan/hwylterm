##[
  # HwylCli
]##

import std/[
  macros, os, sequtils,
  sets, strutils, tables,
  sugar
]
import ./[bbansi, parseopt3]
export parseopt3

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

type
  CliSetting = enum
    NoHelpFlag, NoArgsShowHelp
  CliFlag = object
    name*: string
    ident*: string
    default*: NimNode
    typeSym*: string
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
    required*: seq[string]
    globalFlags*: seq[CliFlag]

{.push hint[XDeclaredButNotUsed]:off .}
func peekNode(n: NimNode) =
  ## for debugging macros
  debugEcho treeRepr n
{.pop.}

# TODO: do i need this?
func newCliFlag(): CliFlag =
  result.help = newLit("")

template badNode = 
  error "unexpected node kind: " & $node.kind

func typeSymFromNode(node: NimNode): string = 
  case node.kind
  of nnkIdent, nnkStrLit:
    result = node.strVal
  of nnkBracketExpr:
    result = node[0].strVal & "[" & node[1].strVal & "]"
  else: badNode

func getOptTypeSym(node: NimNode): string =
  case node.kind:
  of nnkCommand:
    result = typeSymFromNode(node[1]) # [0] is T
  of nnkCall:
    result = typeSymFromNode(node[1][0]) # [1] is stmtlist [0] is the type
  else: error "unexpected node kind: " & $node.kind

func getOptOptNode(optOptValue: NimNode): NimNode = 
  case optOptValue.kind
  of nnkStrLit:
    result = optOptValue
  of nnkStmtList:
    result = optOptValue[0]
  of nnkCommand:
    result = optOptValue[1]
  of nnkPrefix: # NOTE: should i double check prefix value?
    result = optOptValue[1]
  else: error "unexpected node kind: " & $optOptValue.kind

# TODO: don't use the confusing name optOpts here and above
func parseOptOpts(opt: var CliFlag, optOpts: NimNode) =
  expectKind optOpts, nnkStmtList
  for optOpt in optOpts:
    case optOpt.kind
    of nnkCall, nnkCommand, nnkPrefix:
      case optOpt[0].strVal
      of "help","?":
        opt.help = getOptOptNode(optOpt[1])
      of "short", "-":
        let val = getOptOptNode(optOpt).strVal
        if val.len > 1:
          error "short flag must be a char"
        opt.short = val[0].char
      of "*", "default":
        opt.default = getOptOptNode(optOpt)
      of "i", "ident":
        opt.ident = getOptOptNode(optOpt).strVal
      of "T":
        opt.typeSym = getOptTypeSym(optOpt)
      else:
        error "unexpected option setting: " & optOpt[0].strVal
    else:
      error "unexpected option node type: " & $optOpt.kind

func startFlag(f: var CliFlag, n: NimNode) =
  f.name =
    case n[0].kind
    of nnkIdent, nnkStrLit: n[0].strVal
    of nnkAccQuoted: collect(for c in n[0]: c.strVal).join("")
    else: error "unexpected node kind for option"

  # assume a single character is a short flag
  if f.name.len == 1:
    f.short = f.name[0].char
  else:
    f.long = f.name

func parseCliFlag(n: NimNode): CliFlag =
  if n.kind notin [nnkCommand, nnkCall]:
    error "unexpected node kind: " & $n.kind

  # deduplicate these...
  result = newCliFlag()
  startFlag(result, n)
  # option "some help desc"
  if n.kind  == nnkCommand:
    result.help = n[1]
  # option:
  #   help "some help description"
  else:
    parseOptOpts(result, n[1])

  if result.ident == "":
    result.ident = result.name
  if result.typeSym == "":
    result.typeSym = "string"


func parseCliFlags(flags: NimNode): seq[CliFlag] =
  expectKind flags, nnkStmtList
  for f in flags:
    result.add parseCliFlag(f)

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


func addGlobalFlagsFrom(child: var CliCfg, parent: CliCfg) =
  let names = child.flags.mapIt(it.name)
  for f in parent.globalFlags:
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
    subCfg.addGlobalFlagsFrom(cfg)

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
      of "globalFlags":
        result.globalFlags = parseCliFlags(call[1])
      of "flags":
        result.flags = parseCliFlags(call[1])
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

  result.addGlobalFlagsFrom(result)

  if result.name == "":
    error "missing required option: name"

# TODO: here an elsewhere make help/version less special 
# and just append to "opts" at that point 
# check for h,V in existing opts and use if available

func flagsArray(cfg: CliCfg): NimNode =
  result = newTree(nnkBracket)

  for f in cfg.flags:
    if f.name in cfg.hidden: continue
    let
      help = f.help
      long = newLit(f.long)
      short =
        if f.short != '\x00': newLit($f.short)
        else: newLit("")
    result.add quote do:
      (`short`, `long`, `help`)


  if NoHelpFlag notin cfg.settings:
    result.add quote do:
      ("h", "help", "show this help")

  if cfg.version != nil:
    result.add quote do:
      ("V", "version", "print version")

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
    # name = newLit(cfg.name)
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

# NOTE: is there a better way to do this?
proc checkVarSet[T](name: string, target: T) =
  var default: T
  if target == default:
    hwylCliError("missing required flag: [b]" & name)

proc checkDefaultExists[T](target: T, key: string, val: string) =
  var default: T
  if target == default and val == "":
    hwylCliError("expected value for: [b]" & key)

proc tryParseInt(key: string, val: string): int =
  try:
    result = parseInt(val)
  except:
    hwylCliError(
      "failed to parse value for [b]" & key & "[/] as integer: [b]" & val
    )

func addOrOverwrite[T](target: var seq[T], default: seq[T], val: T) =
  if target != default:
    target.add val
  else:
    target = @[val]

func assignField(f: CliFlag): NimNode =
    let key = ident"key"
    let varName = ident(f.ident)

    case f.typeSym
    of "string":
      let value = ident"val"
      result = quote do:
        checkDefaultExists(`varName`, `key`, `value`)
        `varName` = `value`

    of "bool":
      let value = ident"true"
      result = quote do:
        `varName` = `value`

    of "int":
      let value = ident"val"
      result = quote do:
        checkDefaultExists(`varName`, `key`, `value`)
        `varName` = tryParseInt(`key`, `value`)

    of "seq[string]":
      let value = ident"val"
      let default = f.default or (quote do: @[])
      result = quote do:
        `varName`.addOrOverwrite(`default`, `value`)

    of "seq[int]":
      let value = ident"val"
      let default = f.default or (quote do: @[])
      result = quote do:
        `varName`.addOrOverwrite(`default`, tryParseInt(`value`))

    else: error "unable to generate assignment for fion, type: " & f.name & "," & f.typeSym

func shortLongCaseStmt(cfg: CliCfg, printHelpName: NimNode, version: NimNode): NimNode = 
  var caseStmt = nnkCaseStmt.newTree(ident("key"))
  caseStmt.add nnkOfBranch.newTree(newLit(""), quote do: hwylCliError("empty flag not supported currently"))

  if NoHelpFlag notin cfg.settings:
    caseStmt.add nnkOfBranch.newTree(
      newLit("h"), newLit("help"),
      quote do:
        `printHelpName`(); quit 0
    )

  if cfg.version != nil:
    caseStmt.add nnkOfBranch.newTree(
        newLit("V"), newLit("version"),
        quote do:
          echo `version`; quit 0
    )

  # add flags
  for f in cfg.flags:
    var branch = nnkOfBranch.newTree()
    if f.long != "": branch.add(newLit(f.long))
    if f.short != '\x00': branch.add(newLit($f.short))
    branch.add assignField(f)
    caseStmt.add branch

  caseStmt.add nnkElse.newTree(quote do: hwylCliError("unknown flag: [b]" & key))
  result = nnkStmtList.newTree(caseStmt)


func getNoVals(cfg: CliCfg): tuple[long: NimNode, short: NimNode] =
  var long = nnkBracket.newTree()
  var short = nnkCurly.newTree()

  if NoHelpFlag notin cfg.settings:
    long.add newLit("help")
    short.add newLit('h')

  if cfg.version != nil:
    long.add newLit("version")
    short.add newLit('V')

  for f in cfg.flags:
    if f.typeSym == "bool":
      if f.long != "":
        long.add newLit(f.long)
      if f.short != '\x00':
        short.add newLit(f.short)

  result = (nnkPrefix.newTree(ident"@",long), short)

func setFlagVars(cfg: CliCfg): NimNode =
  result = nnkVarSection.newTree()
  # TODO: generalize this better... 

  for f in cfg.flags:
    let
      t =
        if f.typeSym == "seq[string]": nnkBracketExpr.newTree(newIdentNode("seq"),newIdentNode("string"))
        elif f.typeSym == "seq[int]" : nnkBracketExpr.newTree(newIdentNode("seq"),newIdentNode("string"))
        else: ident(f.typeSym)
      val =
        if f.default == nil: newEmptyNode() # use default here
        else: f.default

    result.add nnkIdentDefs.newTree(ident(f.ident), t, val)

func addRequiredFlagsCheck(cfg: CliCfg, body: NimNode) =
  let requirdFlags = cfg.flags.filterIt(it.name in cfg.required and it.default == nil)
  for f in requirdFlags:
    let name = newLit(f.name)
    let flag = ident(f.ident)
    body.add quote do:
      checkVarSet(`name`, `flag`)

func hwylCliImpl(cfg: CliCfg, root = false): NimNode =

  let
    version = cfg.version or newLit("")
    name = cfg.name.replace(" ", "")
    printHelpName = ident("print" & name & "Help")
    parserProcName = ident("parse" & name)

  result = newTree(nnkStmtList)

  let
    printHelperProc = generateCliHelperProc(cfg, printHelpName)
    flagVars = setFlagVars(cfg)

  # result.add setFlagVars(cfg)

  var parserBody = nnkStmtList.newTree()
  let
    optParser = ident("p")
    cmdLine = ident"cmdLine"
    (longNoVal, shortNoVal) = cfg.getNoVals()

  var stopWords = nnkBracket.newTree(newLit("--"))
  for w in cfg.stopWords:
    stopWords.add newLit(w)
  stopWords = nnkPrefix.newTree(ident"@", stopWords)

  parserBody.add(
    quote do:
      var `optParser` = initOptParser(
        @`cmdLine`,
        longNoVal = `longNoVal`,
        shortNoVal = `shortNoVal`,
        stopWords = `stopWords`
      )
  )

  let
    kind = ident"kind"
    key = ident"key"
    val = ident"val"

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
        nnkOfBranch.newTree(ident("cmdArgument"), quote do: result.add `key`),
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
  addRequiredFlagsCheck(cfg, runBody)
  # move to proc?
  if cfg.pre != nil:
    runBody.add cfg.pre
  if cfg.run != nil:
    runBody.add cfg.run
  if cfg.post != nil:
    runBody.add cfg.post

  # let runBody = cfg.run or nnkStmtList.newTree(nnkDiscardStmt.newTree(newEmptyNode()))

  let args = ident"args"

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

when isMainModule:
  import std/strformat
  hwylCli:
    name "hwylterm"
    ... "a description of hwylterm"
    globalFlags:
      config:
        T seq[string]
        ? "path to config file"
        * @["config.yml"]
    flags:
      check:
        T bool
        ? "load config and exit"
        - c
    run:
      echo "hello from the main command"
      echo fmt"{config=}, {check=}"
    subcommands:
      --- a
      ... "the \"a\" subcommand"
      flags:
        `long-flag` "some help"
        flagg       "some other help"
      run:
        echo "hello from hwylterm sub command!"
      --- b
      ... """
      some "B" command

      a longer mulitline description that will be visibil in the subcommand help
      it will automatically be "bb"'ed [bold]this is bold text[/]
      """
      flags:
        aflag:
          T bool
          ? "some help"
        bflag:
          ? "some other flag?"
          * "wow"
      run:
        echo "hello from hwylterm sub `b` command"
        echo aflag, bflag


