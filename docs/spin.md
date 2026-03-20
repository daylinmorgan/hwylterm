# spin

Animated terminal spinner backed by a background thread. The simplest usage is the `withSpinner` template, which starts the spinner, runs a block, then stops it automatically.

```nim
import std/os
import hwylterm/spin

withSpinner("loading..."):
  sleep 2000
```

Use `spinner.setText` inside the block to update the message while running:

```nim
import std/os
import hwylterm/spin

withSpinner("step 1"):
  sleep 500
  spinner.setText("step 2")
  sleep 500
  spinner.setText("done")
  sleep 500
```

To pick a specific spinner style, use the `with` template:

```nim
import std/os
import hwylterm/spin

Moon.with("loading..."):
  sleep 2000
```

See SpinnerKind_ for all available styles.
