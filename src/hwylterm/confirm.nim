import std/[strutils]
import ./bbansi

proc confirm*(
  question: string,
  prefix = "",
  suffix = ""
): bool =
  result = false
  stderr.write $(question & bb"[yellow] (Y/n) ")
  while true:
    let ans = readLine(stdin)
    case ans.strip().toLowerAscii():
    of "y","yes": return true
    of "n","no": return false
    else:
      stderr.write($bb("[red]Please answer Yes/no\nexpected one of [b]Y,yes,N,no "))
  stderr.write "\n"

when isMainModule:
  echo "Response: ", confirm("Is it working?")
