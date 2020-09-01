import terminal
import iup
import algorithm 
import strutils
import math


# Start of fuzzysearch from nim codebase:
# =====================================================
# Nim -- a Compiler for Nim. https://nim-lang.org/

# Copyright (C) 2006-2020 Andreas Rumpf. All rights reserved.

# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:

# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

# [ MIT license: http://www.opensource.org/licenses/mit-license.php ]

const
  MaxUnmatchedLeadingChar = 3
  ## Maximum number of times the penalty for unmatched leading chars is applied.

  HeadingScaleFactor = 0.5
  ## The score from before the colon Char is multiplied by this.
  ## This is to weight function signatures and descriptions over module titles.


type
  ScoreCard = enum
    StartMatch           = -100 ## Start matching.
    LeadingCharDiff      = -3   ## An unmatched, leading character was found.
    CharDiff             = -1   ## An unmatched character was found.
    CharMatch            = 0    ## A matched character was found.
    ConsecutiveMatch     = 5    ## A consecutive match was found.
    LeadingCharMatch     = 10   ## The character matches the beginning of the
                                ## string or the first character of a word
                                ## or camel case boundary.
    WordBoundryMatch     = 20   ## The last ConsecutiveCharMatch that
                                ## immediately precedes the end of the string,
                                ## end of the pattern, or a LeadingCharMatch.


proc fuzzyMatch*(pattern, str: cstring) : tuple[score: int, matched: bool] =
  var
    scoreState = StartMatch
    headerMatched = false
    unmatchedLeadingCharCount = 0
    consecutiveMatchCount = 0
    strIndex = 0
    patIndex = 0
    score = 0

  template transition(nextState) =
    scoreState = nextState
    score += ord(scoreState)

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

    # Since this algorithm will be used to search against Nim documentation,
    # the below logic prioritizes headers.
    if not headerMatched and strChar == ':':
      headerMatched = true
      scoreState = StartMatch
      score = int(floor(HeadingScaleFactor * float(score)))
      patIndex = 0
      strIndex += 1
      continue

    if strChar == patternChar:
      case scoreState
      of StartMatch, WordBoundryMatch:
        scoreState = LeadingCharMatch

      of CharMatch:
        transition(ConsecutiveMatch)

      of LeadingCharMatch, ConsecutiveMatch:
        consecutiveMatchCount += 1
        scoreState = ConsecutiveMatch
        score += ord(ConsecutiveMatch) * consecutiveMatchCount

        if scoreState == LeadingCharMatch:
          score += ord(LeadingCharMatch)

        var onBoundary = (patIndex == high(pattern))
        if not onBoundary and strIndex < high(str):
          let
            nextPatternChar = toLowerAscii(pattern[patIndex + 1])
            nextStrChar     = toLowerAscii(str[strIndex + 1])

          onBoundary = (
            nextStrChar notin {'a'..'z'} and
            nextStrChar != nextPatternChar
          )

        if onBoundary:
          transition(WordBoundryMatch)

      of CharDiff, LeadingCharDiff:
        var isLeadingChar = (
          str[strIndex - 1] notin Letters or
          str[strIndex - 1] in {'a'..'z'} and
          str[strIndex] in {'A'..'Z'}
        )

        if isLeadingChar:
          scoreState = LeadingCharMatch
          #a non alpha or a camel case transition counts as a leading char.
          # Transition the state, but don't give the bonus yet; wait until we verify a consecutive match.
        else:
          transition(CharMatch)
      patIndex += 1

    else:
      case scoreState
      of StartMatch:
        transition(LeadingCharDiff)

      of ConsecutiveMatch:
        transition(CharDiff)
        consecutiveMatchCount = 0

      of LeadingCharDiff:
        if unmatchedLeadingCharCount < MaxUnmatchedLeadingChar:
          transition(LeadingCharDiff)
        unmatchedLeadingCharCount += 1

      else:
        transition(CharDiff)

    strIndex += 1

  if patIndex == pattern.len and (strIndex == str.len or str[strIndex] notin Letters):
    score += 10

  result = (
    score:   max(0, score),
    matched: (score > 0),
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

proc hideCursorInCorner(): void =
  var w = terminalWidth()
  var h = terminalHeight()
  setCursorPos(w,h)

proc drawPromptItemsAndSelector(prompt: string, answer: string, items: seq, sel: var int): int =
  var w = terminalWidth()
  var h = terminalHeight()

  var shownListBottom = h - 2
  var shownListLength = shownListBottom - 3

  itemsToSearch = @[]
  matches = @[]
  
  if len(answer) > 0:
    for index, item in items:
      var strItem = $item
      let (score, matched) = fuzzymatch(answer, strItem)
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
  var sel = 0
  var answer = ""
  var ws = $terminalWidth()
  var hs = $terminalHeight()

  var w = terminalWidth()
  var h = terminalHeight()
  
  hideCursor()

  var _ = drawPromptItemsAndSelector(prompt, answer, items, sel)

  result = 0
  var controlKey = 0
  var takingInput = true
  var nextIsControlKey = false
  while takingInput:
    var ch = cint(getch())

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