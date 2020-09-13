# Package

version       = "0.0.1"
author        = "Brad Barrows <bebrws@gmail.net>"
description   = "An fzf inspired command line interface for Nim"
license       = "MIT"

skipDirs = @["examples"]

requires "nim >= 1.0.0"

# when install ncurses through nimble I got an error due to a name variable being set in the ncurses nimble file
# to make this package distributable I am going to just include the ncurses.nim file in my repo
#requires "nim >= 1.0.0", "ncurses >= 1.0.0"

task examples, "Compiles the examples":
  exec "nim c -d:release examples/test.nim"
  exec "nim c -d:release examples/fzf.nim"  