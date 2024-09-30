import std/[logging, strutils]
export logging

import ./bbansi

var
  handlers {.threadvar.}: seq[Logger]

#[
Level* = enum ## \
    lvlAll,     ## All levels active
    lvlDebug,   ## Debug level and above are active
    lvlInfo,    ## Info level and above are active
    lvlNotice,  ## Notice level and above are active
    lvlWarn,    ## Warn level and above are active
    lvlError,   ## Error level and above are active
    lvlFatal,   ## Fatal level and above are active
    lvlNone     ## No levels active; nothing is logged
]#

type
  FancyConsoleLogger* = ref object of Logger
    ## A logger that writes log messages to the console.
    ##
    ## Create a new ``FancyConsoleLogger`` with the `newFancyConsoleLogger proc
    ## <#newConsoleLogger>`_.
    ##
    useStderr*: bool ## If true, writes to stderr; otherwise, writes to stdout
    flushThreshold*: Level ## Only messages that are at or above this
                           ## threshold will be flushed immediately
    fmtPrefix: string
    fmtSep: string
    fmtStrs: array[Level, string]


const
  defaultFlushThreshold = when NimMajor >= 2:
      when defined(nimV1LogFlushBehavior): lvlError else: lvlAll
    else:
      when defined(nimFlushAllLogs): lvlAll else: lvlError
  ## The threshold above which log messages to file-like loggers
  ## are automatically flushed.
  ##
  ## By default, only error and fatal messages are logged,
  ## but defining ``-d:nimFlushAllLogs`` will make all levels be flushed

proc genFmtStr(
  fmtPrefix, fmtSep, fmtSuffix, levelStyle: string,
  level: Level
): string =
  var parts: seq[string]
  if fmtPrefix != "": parts.add fmtPrefix
  parts.add $LevelNames[level].bb(levelStyle)
  return parts.join(fmtSep) & fmtSuffix


proc newFancyConsoleLogger*(
  levelThreshold = lvlAll,
  fmtPrefix = "",
  fmtSep = "|",
  fmtSuffix = "| ",
  useStderr = true,
  flushThreshold = defaultFlushThreshold,
  debugStyle = "faint",
  infoStyle = "bold",
  noticeStyle = "bold",
  warnStyle = "bold yellow",
  errorStyle = "bold red",
  fatalStyle = "bold red"
): FancyConsoleLogger =
  ## Creates a new `FancyConsoleLogger<#ConsoleLogger>`_.
  new result
  ## log needs to be gcsafe so we pregenerate the log formats when making the handler
  let fmtStrs: array[Level, string] = [
      genFmtStr(fmtPrefix, fmtSep, fmtSuffix, ""         , lvlAll),
      genFmtStr(fmtPrefix, fmtSep, fmtSuffix, debugStyle , lvlDebug),
      genFmtStr(fmtPrefix, fmtSep, fmtSuffix, infoStyle  , lvlInfo),
      genFmtStr(fmtPrefix, fmtSep, fmtSuffix, noticeStyle, lvlNotice),
      genFmtStr(fmtPrefix, fmtSep, fmtSuffix, warnStyle  , lvlWarn),
      genFmtStr(fmtPrefix, fmtSep, fmtSuffix, errorStyle , lvlError),
      genFmtStr(fmtPrefix, fmtSep, fmtSuffix, fatalStyle , lvlFatal),
      genFmtStr(fmtPrefix, fmtSep, fmtSuffix, ""         , lvlNone)
  ]
  result.fmtPrefix = fmtPrefix
  result.fmtSep = fmtSep
  result.levelThreshold = levelThreshold
  result.flushThreshold = flushThreshold
  result.useStderr = useStderr
  result.fmtStrs = fmtStrs


method log*(logger: FancyConsoleLogger, level: Level, args: varargs[string, `$`]) {.gcsafe.} =
  ## Logs to the console with the given `FancyConsoleLogger<#ConsoleLogger>`_ only.
  ##
  ## This method ignores the list of registered handlers.
  ##
  ## Whether the message is logged depends on both the ConsoleLogger's
  ## ``levelThreshold`` field and the global log filter set using the
  ## `setLogFilter proc<#setLogFilter,Level>`_.
  ##
  ## **Note:** Only error and fatal messages will cause the output buffer
  ## to be flushed immediately by default. Set ``flushThreshold`` when creating
  ## the logger to change this.

  if level >= logger.levelThreshold:
    let ln = substituteLog(logger.fmtStrs[level], level, args)
    when defined(js): {.fatal: "handler does not support JS".}
    try:
      let handle =
        if logger.useStderr: stderr
        else: stdout
      writeLine(handle, ln)
      if level >= logger.flushThreshold: flushFile(handle)
    except IOError:
      discard

proc addHandlers*(handler: Logger) =
  handlers.add(handler)

template errorQuit*(args: varargs[string, `$`]) =
  error args
  quit QuitFailure

template fatalQuit*(args: varargs[string, `$`]) =
  fatal args
  quit QuitFailure

