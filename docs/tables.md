# tables

Styled terminal tables backed by `BbString`. The `hwylTableBlock` macro is the easiest way to build a table — each line is a row, columns are tuple or bracket elements:

```nim
import hwylterm/tables

let t = hwylTableBlock:
  ("Name",              "Dept"                  )
  (bb"[bold]Alice",     "Engineering"           )
  ("Bob",               bb"[blue]Marketing"     )
  (bb"[bold]Carol",     "Sales"                 )

hecho t.render()
```

The first row is treated as the header. Borders default to rounded box style.

## Style options

Pass a `HwylTableStyle` to `render` to change the appearance:

```nim
import hwylterm/tables

let t = hwylTableBlock:
  ("ID", "Name",  "Status"        )
  ("1",  "Alice", bb"[green]ok"   )
  ("2",  "Bob",   bb"[red]failed" )

# ascii borders, row separators, alternating row styles
hecho t.render(HwylTableStyle(
  seps = HwylTableSepsByType[Ascii],
  rowSep = true,
  rowStyles = @["", "faint"],
))
```

See HwylTableSepType_ for available border styles (`None`, `Ascii`, `Box`, `BoxRounded`).

## Building a table incrementally

Use `addRow` to build a table row by row:

```nim
import hwylterm/tables

var t: HwylTable
t.addRow("Name", "Score")
for (name, score) in [("Alice", "95"), ("Bob", "87")]:
  t.addRow(name, score)

hecho t.render()
```
