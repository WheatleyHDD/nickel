# Стандартная библиотека
import macros
import strutils
import sequtils
# Свои модули
import handlers
import utils
import vkapi
import types

# Увеличивается с каждым новым обработчиком команды
# Создан для уникальных имён
var count {.compiletime.} = 1

template start*(body: untyped): untyped {.dirty.} =
  ## Шаблон для секции "start" в модуле, код внутри секции выполняется
  ## после запуска бота
  # Тут так же есть объект TomlTableRef, так как иначе не получилось бы добавить
  # эту процедуру к остальным хендлерам
  proc onStart(bot: VkBot, hiddenRawCfg: TomlTableRef): Future[bool] {.async.} =
    result = true
    body
  module.addStartHandler(onStart, false)

template startConfig*(body: untyped): untyped {.dirty.} =
  ## Шаблон для секции "startConfig" в модуле, код внутри секции выполняется
  ## после запуска бота. Передаёт объект config в модуль
  proc onStart(bot: VkBot, config: TomlTableRef): Future[bool] {.async.} =
    result = true
    body
  module.addStartHandler(onStart)

macro command*(cmds: openarray[string], body: untyped): untyped =
  let uniqName = newIdentNode("handler" & $count)
  var
    usage = newSeq[string]()
    procBody = newStmtList()
    start = 0
  # Если у нас есть `usage = something`
  if body[0].kind == nnkAsgn:
    start = 1
    let text = body[0][1]
    # Если это массив, например ["a", "b"]
    if text.kind == nnkBracket:
      for i in 0..<text.len:
        usage.add text[i].strVal
    # Если это строка, или строка с тройными кавычками
    elif text.kind == nnkStrLit or text.kind == nnkTripleStrLit:
      usage.add text.strVal
  let usageLit = newLit(usage)
  # Добавляем сам код обработчика
  for i in start..<body.len:
    procBody.add body[i]
  # Инкрементируем счётчик для уникальных имён
  inc count
  
  let
    # Создаём идентификационные ноды, чтобы Nim не изменял имя переменных
    api = ident("api")
    msg = ident("msg")
    procUsage = ident("usage")
    args = ident("args")
    text = ident("text")
    name = ident("name")
    module = ident("module")
  # Добавляем код к результату
  result = quote do:
    proc `uniqName`(`api`: VkApi, `msg`: Message) {.async.} =
      # Добавляем "usage" для того, чтобы использовать его внутри процедуры
      const `procUsage` = `usage`
      # Сокращение для "msg.cmd.args"
      template `args`: untyped = `msg`.cmd.args
      # Сокращение для получения текста (сразу всех аргументов)
      template `text`: untyped = `msg`.cmd.args.join(" ")
      # Вставляем само тело процедуры
      `procBody`
    # Команды, которые обрабатываются этим обработчиком
    const cmds = `cmds`
    `module`.addCmdHandler(`uniqName`, @cmds, @(`usageLit`))

macro module*(names: varargs[string], body: untyped): untyped =
  # Имя модуля (все строки, объединённые пробелом)
  let moduleName = names.mapIt(it.strVal).join(" ")
  template data(moduleName, body: untyped) {.dirty.} =
    # Отделяем модуль блоком для того, чтобы у разных
    # модулей в одном файле были разные области видимости
    block:
      # Получаем имя файла с текущим модулем
      const fname = instantiationInfo().filename.splitFile().name
      let module = newModule(moduleName, fname)
      # Добавляем наш модуль в таблицу всех модулей
      modules[moduleName] = module
      body
  result = getAst(data(moduleName, body))
