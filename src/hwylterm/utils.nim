import std/[os, terminal]

type
  BbMode* = enum
    On, NoColor, Off

proc checkColorSupport(): BbMode =
  when defined(bbansiOff):
    return Off
  when defined(bbansiNoColor):
    return NoColor
  else:
    if os.getEnv("HWYLTERM_FORCE_COLOR") != "":
      return On
    if os.getEnv("NO_COLOR") != "":
      return NoColor
    if not isatty(stdout):
      return Off

let bbMode* = checkColorSupport()


