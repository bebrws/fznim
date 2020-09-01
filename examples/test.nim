import fznim
import sequtils
import terminal

var prompt = "Select one:"
var items = toSeq(1..5000)

var resultIndex = selectFromList(prompt, items)
eraseScreen()
echo "Result index is"
echo resultIndex  