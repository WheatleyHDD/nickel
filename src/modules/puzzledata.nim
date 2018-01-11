include base
import sequtils
import os
# Загружаем массив фактов из json файла (во время компиляции) и конвертируем
# в последовательность строк (сделано для уменьшения повторения кода)
template jsonToSeq(filename: string): untyped = 
  try:
    let data = readFile(filename)
    data.parseJson.getElems().mapIt(it.str)
  except:
    @[]

let
  facts = jsonToSeq("data/facts.json")
  puzzle = jsonToSeq("data/puzzle.json")

module "&#128161;", "Интересные факты":
  start:
    if not fileExists("data" / "facts.json"):
      log("Файл data/facts.json не найден.")
      return false
    
  command "факт", "факты":
    usage = "факт - отправляет интересный факт"
    answer rand(facts)

module "Случайные загадки":
  start:
    if not fileExists("data" / "puzzle.json"):
      log("Файл data/puzzle.json не найден.")
      return false
  
  command "загадка", "загадай":
    usage = "загадка - отправляет случайную загадку с ответом"
    answer rand(puzzle)