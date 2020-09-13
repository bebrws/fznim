# Author: Brad Barrows
# Copyright (c) 2020
# MIT License
#
# A command line tool written in nim that is similar to fzf but searches lines in 
# files returning the file selected
#
import strutils
import system
import terminal
import osproc
import strformat
import fznim
import system
import os
import re

proc isNotAscii(c: char): bool =
  return int(c) < 0 or int(c) > 127

if paramCount() != 2 and paramCount() != 3:
    echo fmt"Usage: {paramStr(0)} file-path-to-directory-to-search-files-from templated-string-to-execute-on-selection optionally-a-regex-string-to-check-if-filename-matches-with"
    echo "templated-string-to-execute-on-selection - Should include the string {-} which will have the filename that"
    echo "    selected line was in templated in to replace {-}"
    echo "    Optionally {_} can be used to template in line number"
    echo "    This templated string will then be executed upon selection uses a shell command"
    echo ""
    quit(1)

var fileLines: seq[tuple[lineNo: int, file: string, line: string]] = @[]
var justLines: seq[string] = @[]

fileLines  = @[]

var filenameEnd = ""
var searchFilePath = ""
var templateExecString = ""
if paramCount() == 2 or paramCount() == 3:
  searchFilePath = paramStr(1)
  templateExecString = paramStr(2)
if paramCount() == 3:
  filenameEnd = paramStr(3)

# todo check if file is bninary
var files: seq[string] = @[]
for file in walkDirRec searchFilePath:
  if filenameEnd.len != 0:
    if file.match re(filenameEnd):
      files.add(file)
  else:
    files.add(file)

for file in files:
  let fileContent = readFile(file)
  var isLikelyBinary = false
  for c in fileContent[0..min(fileContent.len-1, terminalWidth())]:
    if isNotAscii(c):
      isLikelyBinary = true   
  if not isLikelyBinary:
    var lineNo:int = 0
    for line in fileContent.splitLines:
      fileLines.add((lineNo, file, line))
      justLines.add(line)
      lineNo += 1

let resultIndex = selectFromList("Select line: ", justLines)

let fileLineSelected = fileLines[resultIndex]
if resultIndex != -1:
  templateExecString = templateExecString.replace("{-}", fileLineSelected.file)
  templateExecString = templateExecString.replace("{_}", $(fileLineSelected.lineNo + 1))
  let outp = execProcess(templateExecString)

system.quit(resultIndex)