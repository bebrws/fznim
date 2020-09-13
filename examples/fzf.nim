# Author: Brad Barrows
# Copyright (c) 2020
# MIT License
#
# A nim FZF clone using the fznim library
#
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

var resultIndex = selectFromList("Select: ", lines)

eraseScreen()
echo "result index is: " & $resultIndex

system.quit(resultIndex)