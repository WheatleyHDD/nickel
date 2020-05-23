# Файл с различными помощниками

import macros, strtabs, times, strutils, random, os
import unicode, cgi, strformat

const
  # Таблица русских и английских символов (для конвертирования раскладки)
  English = ["Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P", "A", 
            "S", "D", "F", "G", "H", "J", "K", "L", "Z", "X", "C", 
            "V", "B", "N", "M", "q", "w", "e", "r", "t", "y", "u", 
            "i", "o", "p", "a", "s", "d", "f", "g", "h", "j", "k", 
            "l", "z", "x", "c", "v", "b", "n", "m", ":", "^", "~", 
            "`", "{", "[", "}", "]", "\"", "'", "<", ",", ">", ".", 
            ";", "?", "/", "&", "@", "#", "$"]
    
  Russian = ["Й", "Ц", "У", "К", "Е", "Н", "Г", "Ш", "Щ", "З", "Ф", 
            "Ы", "В", "А", "П", "Р", "О", "Л", "Д", "Я", "Ч", "С", 
            "М", "И", "Т", "Ь", "й", "ц", "у", "к", "е", "н", "г", 
            "ш", "щ", "з", "ф", "ы", "в", "а", "п", "р", "о", "л", 
            "д", "я", "ч", "с", "м", "и", "т", "ь", "Ж", ":", "Ё", 
            "ё", "Х", "х", "Ъ", "ъ", "Э", "э", "Б", "б", "Ю", "ю", 
            "ж", ",", ".", "?", "'", "№", ";"]

template convert(data: string, frm, to: openarray[string]): untyped =
  result = ""
  # Проходимся по UTF8 символам в строке
  for x in utf8(data):
    if not frm.contains(x):
      result.add x
      continue
    result.add to[frm.find(x)]

proc encode*(params: StringTableRef, isPost = true): string =
  ## Кодирует параметры $params для отправки POST или GET запросом
  result = if not isPost: "?" else: ""
  # Кодируем ключ и значение для URL (если есть параметры)
  if not params.isNil():
    for key, val in pairs(params):
      let 
        enck = cgi.encodeUrl(key)
        encv = cgi.encodeUrl(val)
      result.add(&"{enck}={encv}&")

proc toRus*(data: string): string = 
  ## Конвертирует строку в английской раскладке в русскую
  data.convert(English, Russian)

proc toEng*(data: string): string = 
  ## Конвертирует строку в русской раскладке в английскую
  data.convert(Russian, English)

macro unpack*(args: varargs[untyped]) =
  ## Распаковывает последовательность или массив
  ## Почти то же самое, что "a, b, c, d = list" в Python
  result = newStmtList()
  # Первый аргумент - сама последовательность или массив
  let arr = args[0]
  # Все остальные аргументы - названия переменных
  var i = 0
  for arg in args.children:
    if i > 0:
      result.add quote do:
        let `arg` = `arr`[`i` - 1]
    inc i

# Имена файлов из папки modules, которые не нужно импортировать автоматически
const IgnoreFilenames = ["base.nim", "help.nim"]

macro importPlugins*(): untyped =
  result = newStmtList()
  let folder = "src/modules"
  for kind, path in walkDir("src" / "modules"):
    if kind != pcFile: continue
    let filename = path.extractFilename()
    if filename in IgnoreFilenames: continue
    let toImport = filename.splitFile()
    if toImport.ext != ".nim" or "skip" in toImport.name: continue
    # Добавляем импорт этого модуля
    result.add parseExpr(&"import {folder}/{toImport.name}")
  # Импортируем help в самом конце, чтобы все остальные модули записали
  # свои команды в commands
  result.add parseExpr(&"import {folder}/help")

proc toApi*(keyValuePairs: varargs[tuple[key, val: string]]): StringTableRef 
            {.inline.} = 
  ## Возвращает новую строковую таблицу
  runnableExamples:
    # Пример использования
    let msg = {"message":"Hello", "peer_id": "123"}.toApi
  result = newStringTable(keyValuePairs, modeCaseInsensitive)

proc getMoscowTime*(): string =
  ## Возвращает время в формате день.месяц.год часы:минуты:секунды по МСК
  let curTime = now().utc + initTimeInterval(hours=3)
  result = format(curTime, "d'.'M'.'yyyy HH':'mm':'ss")

proc antiFlood*(): string =
  ## Служит для обхода антифлуда ВК (генерирует пять случайных букв)
  for x in 0 .. 4:
    result.add sample({'A' .. 'Z'})

template quotes*(data: string): string = "\"" & data & "\""

template fatalException*(data: untyped) {.dirty.} = 
  fatalError data, error = exc.msg