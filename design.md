# design

A dump for fleshing out in-progress/future design ideas.

## tables

a table can like the others build off of bbansi to support some basic ansi rendering.
to do this effectively I may need to pull in unicode and unicode_db.

but the general idea would probably be something like:

```nim
var table = newHwylTable(style = Ansi)
table.addColumn(name = "movie")
table.addColumn(name = "box office")
table.addSep()
table.addRow "Avatar", "2,923,706,026"
table.addRow "Avengers: Endgame", "2,797,501,328"

echo table
```
resulting in:

```txt
| movie             |  box office   |
|-------------------|---------------|
| Avatar            | 2,923,706,026 |
| Avengers: Endgame | 2,797,501,328 |
```

A good table API could be reused by `hwylcli` using a borderless table for flags and commands
