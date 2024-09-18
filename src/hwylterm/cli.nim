## adapter to add hwylterm colors to cligen output
import std/[tables]
import cligen
import ./bbansi


type
  CligenStyle = object
    cmd: string = "bold cyan"
    descrip: string = ""
    dflval: string = "yellow"
    optkeys: string = "green"
    valtype: string =  "red"
    args: string = "italic"


proc helpAttr(styles: CligenStyle): Table[string, string] =
  {
    "cmd"      : toAnsiCode(styles.cmd),
    "clDescrip": toAnsiCode(styles.descrip),
    "clDflVal" : toAnsiCode(styles.dflval),
    "clOptKeys": toAnsiCode(styles.optkeys),
    "clValType": toAnsiCode(styles.valtype),
    "args"     : toAnsiCode(styles.args)
  }.toTable()

proc helpAttrOff(): Table[string,string] =
  let resetCode = toAnsiCode("reset")
  {
    "cmd"      : resetCode,
    "clDescrip": resetCode,
    "clDflVal" : resetCode,
    "clOptKeys": resetCode,
    "clValType": resetCode,
    "args"     : resetCode,
  }.toTable()

proc hwylCli*(
  clcfg: var ClCfg,
  styles: CligenStyle = CligenStyle(),
  useMulti: string = "${doc}[bold]Usage[/]:\n  $command {SUBCMD} [[sub-command options & parameters]\n\n[bold]subcommands[/]:\n$subcmds",
  useHdr: string = "[bold]usage[/]:\n  "
) =

  if clCfg.useMulti == "":
    clCfg.useMulti = $bb(useMulti)

  if clCfg.helpAttr.len == 0:
    clCfg.helpAttr = styles.helpAttr()
    clCfg.helpAttrOff = helpAttrOff()

  # clCfg.use does nothing?
  if clCfg.useHdr == "":
    clCfg.useHdr = $bb(useHdr)

