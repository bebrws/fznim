import terminal
import iup
import algorithm 
import strutils
import os


proc dup(f: cint): cint {.
    importc: "dup", header: "<unistd.h>", tags: [].}

proc ttyname(f: cint): cstring {.
    importc: "ttyname", header: "<unistd.h>", tags: [].}

proc fdopen(f: cint, mode: cstring): File {.
    importc: "fdopen", header: "<stdio.h>", tags: [].}

proc freopen(filename, mode: cstring, stream: File): File {.
    importc: "freopen", nodecl.}    

proc c_fileno(f: File): cint {.
    importc: "fileno", header: "<fcntl.h>".}



proc fzfuzzyMatch*(pattern, str: cstring) : tuple[score: int, matched: bool] =
  var
    strIndex = 0
    patIndex = 0
    score:float = 0

  while (strIndex < str.len) and (patIndex < pattern.len):
    var
      patternChar = pattern[patIndex].toLowerAscii
      strChar     = str[strIndex].toLowerAscii

    # Ignore certain characters
    if patternChar in {'_', ' ', '.'}:
      patIndex += 1
      continue
    if strChar in {'_', ' ', '.'}:
      strIndex += 1
      continue

    if strIndex == 0 and patternChar == strChar:
      score += 3
      patIndex += 1
      strIndex += 1
    elif strChar == patternChar:
      score += 1 # float(float(1) * float(patIndex))
      strIndex += 1
      patIndex += 1
    else:
      strIndex += 1

  if patIndex == pattern.len and (strIndex == str.len or str[strIndex] notin Letters):
    score += 10

  result = (
    score:   max(0, int(score)),
    matched: (int(score) > 0),
  )
  


# Start of fznim

type
  ItemsMatch = tuple
    index: int
    item: string
    score: int

var itemsToSearch: seq[ItemsMatch]
var matches: seq[ItemsMatch]
var oldStartOfShow = -1
var oldAnswer = ""
var oldSelLocation = 1

proc drawPromptItemsAndSelector(prompt: string, answer: string, items: seq, sel: var int): int =
  var w = terminalWidth()
  var h = terminalHeight()

  var shownListBottom = h - 1
  var shownListLength = shownListBottom - 3

  itemsToSearch = @[]
  matches = @[]
  
  if len(answer) > 0:
    for index, item in items:
      var strItem = $item
      let (score, matched) = fzfuzzyMatch(string(answer), strItem)
      if matched == true:
        matches.add((index, strItem, score))
    matches.sort(proc(x: auto, y: auto): int = y.score - x.score)
    itemsToSearch = matches
  else:
    for index, item in items:
      itemsToSearch.add((index, $item, index))

  if sel > len(itemsToSearch) - 1:
    if len(itemsToSearch) > 0:
      sel = len(itemsToSearch) - 1
    else:
      sel = 0

  result = sel
    
  var numToShowAfterSStart = len(itemsToSearch) - 1
  var startOfShow = 0
  if len(itemsToSearch) > shownListLength:
    if sel > shownListLength:
      startOfShow = sel - shownListLength
      if len(itemsToSearch) - startOfShow > shownListLength:
        numToShowAfterSStart = shownListLength
      else:
        numToShowAfterSStart = len(itemsToSearch) - 1 - startOfShow
      if numToShowAfterSStart + startOfShow < len(itemsToSearch):
        result = itemsToSearch[numToShowAfterSStart + startOfShow].index
      else:
        result = -1
    else:
      numToShowAfterSStart = shownListLength
      if sel != -1 and sel < len(itemsToSearch):
        result = itemsToSearch[sel].index
      else:
        result = -1

  var endOfShow = numToShowAfterSStart + startOfShow

  var maxWidthOfItem = w - 4
  if oldStartOfShow != startOfShow or oldAnswer != answer:
    eraseScreen()
    oldStartOfShow = startOfShow
    for index, val in itemsToSearch[startOfShow..endOfShow]:
      setCursorPos(2, (index + 1))
      if len(val.item) < maxWidthOfItem:
        echo val.item
      else:
        echo val.item[0..maxWidthOfItem - 1]

  setCursorPos(0,0)
  echo prompt

  if oldAnswer != answer:
    oldAnswer = answer
    # Clear answer
    setCursorPos(len(prompt) + 1,0)
    var widthToClear = w - (len(prompt) + 1)
    echo " ".repeat(widthToClear)
    

  setCursorPos(len(prompt) + 1,0)
  var maxAnswerWidth = w - len(prompt) - 2
  if len(answer) < maxAnswerWidth:
    echo answer      
  else:
    echo answer[0..maxAnswerWidth - 1]



  var selLocation = sel
  if sel + 1 > shownListBottom - 2:
    selLocation = shownListBottom - 2
  else:
    selLocation += 1

  if oldSelLocation != selLocation:
    setCursorPos(0, oldSelLocation)
    echo " "
    oldSelLocation = selLocation    
  
  setCursorPos(0, selLocation)
  echo "*"   

proc selectFromList*(prompt: string, items: seq): int =

  if getFileInfo(stdin).id.file != 37:
    var stdindup = dup(c_fileno(stdin))
    var input = fdopen(stdindup, cstring("r"))
    discard freopen(ttyname(c_fileno(stdout)), cstring("r"), stdin)

  var sel = 0
  var answer = ""

  var w = terminalWidth()
  var h = terminalHeight()

  if w < len(prompt) or h < 4:
    return -1
  
  hideCursor()

  var _ = drawPromptItemsAndSelector(prompt, answer, items, sel)

  result = 0
  var controlKey = 0
  var takingInput = true
  var nextIsControlKey = false
  while takingInput:

    var ch: cint = 0
    try:
      ch = cint(getch())
    except EOFError:
      ch = 0

    var newsel = sel

    if ch == 13:
      # an enter key was hit
      takingInput = false
    elif ch == 113:
      # q was hit
      takingInput = false
    elif ch == 27 and controlKey == 0:
      controlKey = 1
    elif ch == 91 and controlKey == 1:
      controlKey = 2     
    elif ch == 65 and controlKey == 2:
      controlKey = 0
      if sel > 0:
        newsel -= 1
    elif ch == 66 and controlKey == 2:
      controlKey = 0
      if sel < len(items) - 1:
        newsel += 1
    elif int(ch) == 127:
      # Backspace was hit
      var newLength = len(answer)
      if len(answer) == 1:
        answer = ""
      elif len(answer) > 1:
        newLength = len(answer) - 2
        answer = answer[0..newLength]
      var _ = drawPromptItemsAndSelector(prompt, answer, items, sel)
    elif isprint(ch) == true and controlKey == 0:
      answer &= char(ch)
      var _ = drawPromptItemsAndSelector(prompt, answer, items, sel)
    
    if sel != newsel and sel < len(items):
      # setCursorPos(0, (sel + 1))
      # echo " "
      # setCursorPos(0, (newsel + 1))
      # echo "*"  
      sel = newsel
      var selection = drawPromptItemsAndSelector(prompt, answer, items, sel)
      if selection != -1:
        result = selection

    # Debug info for getch
    # setCursorPos(10, 14)
    # echo ch
    
  showCursor()


# Example usage:

# var prompt = "Select one:"
# var items = toSeq(1..5000)

# var resultIndex = selectFromList(prompt, items)
# eraseScreen()
# echo "RResult index is"
# echo resultIndex  