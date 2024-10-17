
type
  BbStyleAbbr* = enum
    B, I, U

  BbStyle* = enum
    Reset,
    Bold, Faint, Italic, Underline, Blink,
    Reverse = 7, Conceal, Strike

func toStyle*(a: BbStyleAbbr): BbStyle =
  case a:
  of B: Bold
  of I: Italic
  of U: Underline

const bbReset* = "\e[0m"
