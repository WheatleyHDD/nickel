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
      log("Файл data/puzzle.json не найден.")
      return false
  command "факт", "факты":
    usage = "факт - отправляет интересный факт"
    answer rand(facts)

module "Случайные загадки":
  start:
    try:
      puzzle = jsonToSeq("data" / "puzzle.json")
    except: 
      log("Файл data/puzzle.json не найден.")
      return false
  command "загадка", "загадай":
    usage = "загадка - отправляет случайную загадку с ответом"
    answer rand(puzzle)