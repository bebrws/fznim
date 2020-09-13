# FZNIM - FZF in nim

Have you used fzf before but wanted to script something a little too complicated to easily do with zsh or bash?

FZNIM is a library providing a fuzzy string search command line interface prompt which acts just like fzf.

There is an example fzf clone written in nim and a tool showing some example usage called fzgrep which will search all lines in all files in the directory provided returning the file with the selected line.

![An animated gif of the fzf like usage of fznim](fznim.gif)

[I have more information at the blog](https://bradbarrows.com/post/fznim)


To use this try:

```
nimble install -y
nim c examples/fzf.nim  
find ./ | examples/fzf
```

or an example of a tool that could be made with fznim:

```
nimble install -y
nim c examples/fzgrep.nim
./examples/fzgrep ./ "code -g {-}:{_}"  
```