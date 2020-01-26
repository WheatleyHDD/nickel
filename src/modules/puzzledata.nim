include base
import sequtils
import os

template jsonToSeq(filename: string): seq[string] = 
  readFile(filename).parseJson.getElems().mapIt(it.getStr())

# Загружаем факты и загадки во время запуска бота
var 
  facts: seq[string]
  puzzle: seq[string]

module "💡 Интересные факты":
  start:
    try:
      facts = jsonToSeq("data" / "facts.json")
    except:
      logWarn "Puzzle plugin data not found"
      return false
  command ["факт", "факты"]:
    usage = "факт - отправляет интересный факт"
    answer sample(facts)

module "Случайные загадки":
  start:
    try:
      puzzle = jsonToSeq("data" / "puzzle.json")
    except: 
      logWarn "Puzzle plugin data not found"
      return false
  command ["загадка", "загадай"]:
    usage = "загадка - отправляет случайную загадку с ответом"
    answer sample(puzzle)