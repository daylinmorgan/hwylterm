# confirm

Prompt the user for a yes/no answer on stderr. Returns `true` for `y`/`yes` and `false` for `n`/`no` (case-insensitive). Reprompts on any other input.

```nim
import hwylterm/confirm

if confirm("Delete all files?"):
  echo "deleting..."
else:
  echo "aborted"
```
