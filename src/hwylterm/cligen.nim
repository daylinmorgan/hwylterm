##[
  # Hwylterm cligen adapter

  Adapter to add hwylterm colors to cligen output.
]##

import std/[tables]
import ./bbansi

template tryImport*(x, body) =
  when not (compiles do: import x): body else: import x
tryImport pkg/cligen:
  {.fatal: "hwylterm/cli requires cligen>=1.7.5".}


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

const
  useMulti = "${doc}[bold]Usage[/]:\n  $command {SUBCMD} [[sub-command options & parameters]\n\n[bold]Subcommands[/]:\n$subcmds"
  useHdr = "[bold]Usage[/]:\n  "
  use = "$command $args\n${doc}[bold]Options[/]:\n$options"

proc hwylCli*(
  clcfg: var ClCfg,
  styles: CligenStyle = CligenStyle(),
  useMulti: string = useMulti,
  useHdr: string = useHdr,
  use: string = use,
) =

  if clCfg.useMulti == "":
    clCfg.useMulti = $bb(useMulti)
  if clCfg.helpAttr.len == 0:
    clCfg.helpAttr = styles.helpAttr()
    clCfg.helpAttrOff = helpAttrOff()
  # this currently has no effect
  if clCfg.use == "":
    clCfg.use = $bb(use)
  if clCfg.useHdr == "":
    clCfg.useHdr = $bb(useHdr)

