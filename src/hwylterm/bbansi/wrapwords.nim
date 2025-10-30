# modified from std/wrapwords

import std/[strutils, unicode]

proc findMarkupEnd(s: string; start: int; limit: int): int =
  ## Returns the index after the closing ']' if a complete markup tag exists at start,
  ## otherwise returns start (no tag found)
  ## Handles escaped brackets: \[ and [[ are not treated as markup
  if start < limit and s[start] == '[':
    # Check for escaped [[
    if start + 1 < limit and s[start + 1] == '[':
      return start  # Not a markup tag
    # Check for \[ escape (backslash before bracket)
    if start > 0 and s[start - 1] == '\\':
      return start  # Not a markup tag
    var j = start + 1
    while j < limit and s[j] != ']': inc(j)
    if j < limit and s[j] == ']':
      return j + 1
  return start

proc olen(s: string; start, lastExclusive: int): int =
  ## Count visible length, skipping BbMarkup tags and accounting for escape sequences
  var i = start
  result = 0
  while i < lastExclusive:
    # Check for backslash escape
    if s[i] == '\\' and i + 1 < lastExclusive and s[i + 1] == '[':
      # \[ will render as [, so skip the backslash but count the bracket
      inc i
      inc result
      let L = graphemeLen(s, i)
      inc i, L
      continue

    # Check for [[ escape
    if s[i] == '[' and i + 1 < lastExclusive and s[i + 1] == '[':
      # [[ will render as [, so skip first bracket and count the second
      inc i
      inc result
      let L = graphemeLen(s, i)
      inc i, L
      continue
    # Check for real markup tag
    let markupEnd = findMarkupEnd(s, i, lastExclusive)
    if markupEnd > i:
      # Found markup tag, skip it
      i = markupEnd
      continue
    inc result
    let L = graphemeLen(s, i)
    inc i, L

func wrapWordsBbMarkup*(
  s: string,
  maxLineWidth = 80,
  splitLongWords = true,
  seps: set[char] = Whitespace,
  newLine = "\n"
): string =
  ## Word wraps `s` preserving BbMarkup.
  result = newStringOfCap(s.len + s.len shr 6)
  var spaceLeft = maxLineWidth
  var lastSep = ""

  var i = 0
  while true:
    var j = i
    let isSep = j < s.len and s[j] in seps
    # Don't treat characters inside markup as separators
    while j < s.len and (s[j] in seps) == isSep:
      let markupEnd = findMarkupEnd(s, j, s.len)
      if markupEnd > j:
        # If we were looking for separators and hit markup, stop here
        if isSep: break
        # If looking for non-seps, skip the whole tag
        j = markupEnd
        continue
      inc(j)
    if j <= i: break

    if isSep:
      lastSep.setLen 0
      for k in i..<j:
        if s[k] notin {'\L', '\C'}: lastSep.add s[k]
      if lastSep.len == 0:
        lastSep.add ' '
        dec spaceLeft
      else:
        spaceLeft = spaceLeft - olen(lastSep, 0, lastSep.len)
    else:
      let wlen = olen(s, i, j)
      if wlen > spaceLeft:
        if splitLongWords and wlen > maxLineWidth:
          var k = 0
          while k < j - i:
            # Handle markup tags in long words
            let markupEnd = findMarkupEnd(s, i + k, j)
            if markupEnd > i + k:
              # Copy the complete tag
              for n in (i+k)..<markupEnd: result.add s[n]
              k = markupEnd - i
              continue
            if spaceLeft <= 0:
              spaceLeft = maxLineWidth
              result.add newLine
            dec spaceLeft
            let L = graphemeLen(s, k+i)
            for m in 0 ..< L: result.add s[i+k+m]
            inc k, L
        else:
          spaceLeft = maxLineWidth - wlen
          result.add(newLine)
          for k in i..<j: result.add(s[k])
      else:
        spaceLeft = spaceLeft - wlen
        result.add(lastSep)
        for k in i..<j: result.add(s[k])
    i = j

when isMainModule:
  doAssert "123456789012345678[blue]9012345[/]67890".wrapWordsBbMarkup(20) == "123456789012345678[blue]90\n12345[/]67890"
