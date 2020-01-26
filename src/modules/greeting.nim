include base
import sequtils

var greetings: seq[string]

module "📞 Приветствие":
  startConfig:
    greetings = config["messages"].getElems().mapIt(it.getStr())
  
  command ["привет", "ку", "прив", "хей", "хэй", "qq", "халло", "хелло", "hi"]:
    usage = "привет - поприветствовать пользователя"
    answer sample(greetings)