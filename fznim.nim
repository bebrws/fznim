import terminal
import iup
import algorithm 
import strutils
import os
import posix

# type
#   ttysize* {.bycopy.} = object
#     ts_lines*: cushort
#     ts_cols*: cushort
#     ts_xxx*: cushort
#     ts_yyy*: cushort
# var ts:ttysize
# var r = ioctl(1, 1074295912, addr ts)
# var w = int(ts.ts_cols)

var w = terminalWidth()
var h = terminalHeight()

proc fdopen(f: cint, mode: cstring): File {.
    importc: "fdopen", header: "<stdio.h>", tags: [].}

proc freopen(filename, mode: cstring, stream: File): File {.
    importc: "freopen", nodecl.}    

proc c_fileno(f: File): cint {.
    importc: "fileno", header: "<fcntl.h>".}

# proc printf(formatstr: cstring) {.importc: "printf", varargs,
#                                   header: "<stdio.h>".}
                                  

proc fzfuzzyMatch*(pattern: string, str: string, longestItemLength: int) : tuple[score: int, matched: bool, highlighted: string] =
  var
    strIndex = 0
    patIndex = 0
    lastCharMatchedScore = 0
    score = 0
    numInRow = 0
    highlightedString = ""

  while (strIndex < str.len) and (patIndex < pattern.len):
    var
      patternChar = pattern[patIndex].toLowerAscii
      strChar     = str[strIndex].toLowerAscii

    # Ignore certain characters
    if patternChar in {'_', ' ', '.'}:
      patIndex += 1
      continue
    if strChar in {'_', ' ', '.'}:
      highlightedString &= str[strIndex]
      strIndex += 1
      continue

    if strIndex == 0 and patternChar == strChar:
      highlightedString &= "\e[1;39m" & str[strIndex] & "\e[00m"
      score += 3
      lastCharMatchedScore += 2
      patIndex += 1
      strIndex += 1
      numInRow += 1
    elif strChar == patternChar:
      highlightedString &= "\e[1;44m" & str[strIndex] & "\e[00m"
      score += int(longestItemLength/strIndex) * (if numInRow == 0: 1 else: (numInRow * 3))
      if lastCharMatchedScore != 0:
        lastCharMatchedScore += 2
        score += lastCharMatchedScore
      numInRow += 1
      strIndex += 1
      patIndex += 1
    else:
      if not (str[strIndex] in {'_', ' ', '.'}):
        lastCharMatchedScore = 0
      highlightedString &= str[strIndex]
      strIndex += 1
      numInRow = 0
  
  while strIndex < str.len and strIndex < (w - 4):
    highlightedString &= str[strIndex]
    strIndex += 1
      

  # if patIndex == pattern.len and patIndex == strIndex:
  #   score += 10

  result = (
    score:   max(0, int(score)),
    matched: (int(score) > 0),
    highlighted: highlightedString
  )
  


# Start of fznim

type
  ItemsMatch = tuple
    index: int
    item: string
    score: int

var oldSelLocation = 1
var matches: seq[ItemsMatch]
var itemsToSearch: seq[ItemsMatch]

proc colorEndOfString(str: string): string =
  var loc = str.rfind("\e[00m")
  var lastEndOfColor = if loc < 0: 0 else: loc
  if str.len > 3 and lastEndOfColor < str.len - 6 and lastEndOfColor >= 0:
    return str[0..(lastEndOfColor-1)] & "\e[1;39m" & str[lastEndOfColor+(if loc < 0: 0 else: 5)..str.len-1] & "\e[00m"
  else:
    return str

proc fuzzySearchItems(sel: int, answer: string, items: seq[string]): seq[tuple[index: int, item: string, score: int]] =
  # Create itemsToSearch which is a list of tuples containing the original index of a search item,
  # the search item itself, and the match score of how well the search item matched against the 
  # prompt "answer" that is being typed by the user
  matches = @[]
  itemsToSearch = @[]

  if len(answer) > 0:
    var maxLength: int = 0
    for index, item in items:
      if len(item) > maxLength:
        maxLength = len(item)
    for index, item in items:
      var strItem = $item
      let (score, matched, highlighted) = fzfuzzyMatch(answer, strItem, maxLength)
      if matched == true:
        matches.add((index: index, item: highlighted, score: score))
    matches.sort(proc(x: auto, y: auto): int = y.score - x.score)
    itemsToSearch = matches
  else:
    for index, item in items:
      itemsToSearch.add((index, item, index))

  for index, (originalIndex, item, score) in itemsToSearch:
    # newStr &= "\e[1;34m" & c & "\e[00m"
    var str = if sel == index: "\e[1;38m- \e[00m" & colorEndOfString(item) else: item
    itemsToSearch[index].item = str
  return itemsToSearch

proc drawPromptItemsAndSelector(prompt: string, answer: string, itemsToSearch: seq[tuple[index: int, item: string, score: int]], sel: int): int =
  result = sel

  # The length of the list is the height of the window minus 1 line for the prompt and 2 lines for spacing at the bottom
  var shownListBottom = h - 1
  var shownListLength = shownListBottom - 2

  # Get the location where the selector will be rendered
  var selLocation = sel
  if sel + 1 > shownListBottom - 2:
    selLocation = shownListBottom - 2
  else:
    selLocation += 1

  if oldSelLocation != selLocation:
    setCursorPos(0, oldSelLocation)
    echo " "
    oldSelLocation = selLocation    

  var numberOfItemsToShowAfterStart = len(itemsToSearch) - 1
  var startOfItemsToStartShowingFrom = 0
  if len(itemsToSearch) > shownListLength:
    if sel > shownListLength:
      startOfItemsToStartShowingFrom = sel - shownListLength
      if len(itemsToSearch) - startOfItemsToStartShowingFrom > shownListLength:
        numberOfItemsToShowAfterStart = shownListLength
      else:
        numberOfItemsToShowAfterStart = len(itemsToSearch) - 1 - startOfItemsToStartShowingFrom
      if numberOfItemsToShowAfterStart + startOfItemsToStartShowingFrom < len(itemsToSearch):
        result = itemsToSearch[numberOfItemsToShowAfterStart + startOfItemsToStartShowingFrom].index
      else:
        result = -1
    else:
      numberOfItemsToShowAfterStart = shownListLength
      if sel != -1 and sel < len(itemsToSearch):
        result = itemsToSearch[sel].index
      else:
        result = -1

  var endOfItemsToShowTo = numberOfItemsToShowAfterStart + startOfItemsToStartShowingFrom

  #if oldStartOfItemsToStartShowingFrom != startOfItemsToStartShowingFrom or oldAnswer != answer:
  eraseScreen()
  # oldStartOfItemsToStartShowingFrom = startOfItemsToStartShowingFrom
  for index, val in itemsToSearch[startOfItemsToStartShowingFrom..endOfItemsToShowTo]:
    setCursorPos(2, (index + 1))
    if index == selLocation - 1:
      echo "\e[1;32m" & val.item & "\e[00m"
    else:
      echo val.item
    # echo val.item[0 .. min(val.item.len - 1, 160)]

  setCursorPos(0,0)
  echo prompt

  # if oldAnswer != answer:
    # oldAnswer = answer
  # Clear answer
  setCursorPos(len(prompt) + 1,0)
  var widthToClear = w - (len(prompt) + 1)
  echo " ".repeat(widthToClear)
    

  setCursorPos(len(prompt) + 1,0)
  var maxAnswerWidth = w - len(prompt) - 2
  if len(answer) < maxAnswerWidth:
    echo "\e[1;34m" & answer & "\e[00m"
  else:
    echo "\e[1;34m" & answer[0..maxAnswerWidth - 1] & "\e[00m"
  
  setCursorPos(0, selLocation)
  echo "\e[1;36m*\e[00m"

proc selectFromList*(prompt: string, items: seq): int =
  var shortenedItems: seq = @[]

  for i in items:
    var newItem = ""
    var strIndex = 0
    while strIndex < i.len and strIndex < (w - 4):
      newItem &= i[strIndex]
      strIndex += 1
    shortenedItems.add(newItem)

  var itemsSearched  = fuzzySearchItems(0, "", shortenedItems)

  if getFileInfo(stdin).id.file != 37:
    var stdindup = dup(c_fileno(stdin))
    var input = fdopen(stdindup, cstring("r"))
    discard freopen(ttyname(c_fileno(stdout)), cstring("r"), stdin)

  var sel = 0
  var answer = ""

  if w < len(prompt) or h < 4:
    return -1
  
  hideCursor()

  itemsSearched  = fuzzySearchItems(sel, "", shortenedItems)
  var _ = drawPromptItemsAndSelector(prompt, answer, itemsSearched, sel)

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
    elif ch == 3:
      # ctrl c was hit
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
      if sel < len(shortenedItems) - 1:
        newsel += 1
    elif int(ch) == 127:
      # Backspace was hit
      var newLength = len(answer)
      if len(answer) == 1:
        answer = ""
      elif len(answer) > 1:
        newLength = len(answer) - 2
        answer = answer[0..newLength]
      itemsSearched  = fuzzySearchItems(newsel, answer, shortenedItems)
      var _ = drawPromptItemsAndSelector(prompt, answer, itemsSearched, sel)
    elif isprint(ch) == true and controlKey == 0:
      answer &= char(ch)
      itemsSearched  = fuzzySearchItems(newsel, answer, shortenedItems)
      var _ = drawPromptItemsAndSelector(prompt, answer, itemsSearched, sel)
      # Must check sel again here because the list of items has now changed due to the answer fzy search
    if sel > len(itemsSearched) - 1:
      if len(itemsSearched) > 0:
        sel = len(itemsSearched) - 1
      else:
        sel = 0

    if sel != newsel and sel < len(itemsSearched):
      # setCursorPos(0, (sel + 1))
      # echo " "
      # setCursorPos(0, (newsel + 1))
      # echo "*"  
      sel = newsel
      itemsSearched  = fuzzySearchItems(newsel, answer, shortenedItems)
      var selection = drawPromptItemsAndSelector(prompt, answer, itemsSearched, sel)
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