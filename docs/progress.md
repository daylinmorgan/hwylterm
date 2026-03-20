# progress

Progress bar iterator that wraps a sequence and renders a bar as items are consumed. It runs inside a `withSpinner`/`useSpinner` context so the bar animates smoothly.

```nim
import std/os
import hwylterm/progress

let items = (1..20).toSeq()
for item in progress(items):
  sleep 100
```

## Segments

By default the bar renders only the bar itself. Pass `segments` to `newProgress` to add a fraction counter or percentage:

```nim
import std/os
import hwylterm/progress

var pb = newProgress(segments = @[Bar, Fraction, Percent])
for item in pb.progress((1..20).toSeq()):
  sleep 100
```

See ProgressSegment_ for all options (`Bar`, `Fraction`, `Percent`).

## With an existing spinner

If you already have a `Spinny` from the `spin` module, pass it to `progress` to share the spinner:

```nim
import std/os
import hwylterm/[spin, progress]

withSpinner("processing"):
  for item in progress(spinner, (1..20).toSeq()):
    sleep 100
```
