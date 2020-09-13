# FZNIM

Have you used fzf before but wanted to script something a little too complicated to easily do with zsh or bash?

FZNIM is a fuzzy string search command line interface prompt which acts very similar to fzf.

It is still a work in progress but I thought I would share in case anyone was trying to script any command line interfaces and might be looking for something similar

![An animated gif of the fzf like usage of fznim](fznim.gif)

[I have more information at the blog](https://bradbarrows.com/post/fznim)


To use this try:

```
nimble install -y
nim c examples/fzf.nim  
find ./ | examples/fzf
```