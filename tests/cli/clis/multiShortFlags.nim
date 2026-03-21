## Single-letter flag names are automatically short-only — no long form is generated.
import hwylterm, hwylterm/hwylcli

hwylCli:
  name "multiple-short-flags"
  flags:
    a "first short"
    b "second short"
  run:
    echo a, b
