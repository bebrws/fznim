# Package

version       = "0.0.1"
author        = "Brad Barrows <bebrws@gmail.net>"
description   = "An fzf inspired command line interface for Nim"
license       = "MIT"

skipDirs = @["examples"]

requires "nim >= 1.3.0"

task examples, "Compiles the examples":
  exec "nim c -d:release examples/test.nim"