import system
import terminal
import fznim
import system

proc c_fseek(f: File, offset: int64, whence: cint): cint {.
    importc: "fseeko", header: "<stdio.h>", tags: [].}

proc rl*(): tuple[line: string, eof: bool]   =
  result.eof = false
  result.line = ""
  var l:string
  try:
    if not stdin.readLine(l):
        result.eof = true
    else:
        result.line = l
  except EOFError:
    result.eof = true

var lines: seq[string] = @[]

while true:
  var (l, eof) = rl()
  if eof:
      break
  else:
    lines.add(l)

discard c_fseek(stdin, 0, 0)

var resultIndex = selectFromList("Select: ", lines)

eraseScreen()

system.quit(resultIndex)