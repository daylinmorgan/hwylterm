# chooser

Interactive terminal item picker. Navigate with `j`/`k` or arrow keys, `Tab` to multi-select, `Enter` to confirm. Returns the selected items as a `seq[T]`.

```nim
import hwylterm/chooser

let files = @["main.nim", "config.nim", "utils.nim"]
let picked = choose(files)
echo "selected: ", picked
```

The optional `height` parameter controls how many items are visible at once (default `6`):

```nim
import hwylterm/chooser

let branch = choose(["main", "dev", "feature/x", "fix/y"], height = 3)
echo "switching to: ", branch[0]
```
