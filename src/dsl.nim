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
  # Тут так же есть объект JsonNode, так как иначе не получилось бы добавить эту
  # процедуру к остальным хендлерам
  proc onStart(bot: VkBot, hiddenRawCfg: JsonNode): Future[bool] {.async.} = 
    result = true
    body
  addStartHandler(name, onStart, false)

template startConfig*(body: untyped): untyped {.dirty.} = 
  ## Шаблон для секции "startConfig" в модуле, код внутри секции выполняется
  ## после запуска бота. Передаёт объект config в модуль
  proc onStart(bot: VkBot, config: JsonNode): Future[bool] {.async.} = 
    result = true
    body
  addStartHandler(name, onStart)

template startConfig*(typ: untyped, body: untyped): untyped {.dirty.} = 
  ## Шаблон для секции "startConfig" в модуле, код внутри секции выполняется
  ## после запуска бота. Отличается от предыдущего тем, что принимает тип,
  ## в который должна быть превращена конфигурация
  proc onStart(bot: VkBot, rawCfg: JsonNode): Future[bool] {.async.} = 
    let config = json.to(rawCfg, typ)
    result = true
    body
  addStartHandler(name, onStart)
  
macro command*(cmds: varargs[string], body: untyped): untyped =
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
  # Добавляем сам код обработчика
  for i in start..<body.len:
    procBody.add body[i]
  # Инкрементируем счётчик для уникальных имён
  inc count
  
  let
    # Создаём идентификационные ноды, чтобы Nim не изменял имя переменных
    api = newIdentNode("api")
    msg = newIdentNode("msg")
    procUsage = newIdentNode("usage")
    args = newIdentNode("args")
    text = newIdentNode("text")
    name = newIdentNode("name")
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
    addCmdHandler(`uniqName`, `name`, @cmds, @(`usage`))

macro module*(names: varargs[string], body: untyped): untyped = 
  # Добавляем в модули имя нашего модуля (все строки объединённые с пробелом)
  let moduleName = names.mapIt(it.strVal).join(" ")
  template data(moduleName, body: untyped) {.dirty.} = 
    # Отделяем модуль блоком для того, чтобы у разных
    # модулей были разные области видимости
    block:
      # Получаем имя файла с текущим модулем
      const fname = instantiationInfo().filename.splitFile().name
      # Добавляем наш модуль в таблицу всех модулей
      modules[moduleName] = newModule(moduleName, fname)
      let name = moduleName
      body
  result = getAst(data(moduleName, body))
  