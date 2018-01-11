include baseimports
# Стандартная библиотека
import tables  # Таблицы (для соотношения команд с процедурами-обработчиками)
import sequtils
# Свои модули
import types  # Общие типы бота

var
  # Таблица имя_модуля: модуль
  modules* = initTable[string, Module]()
  commands* = newSeq[ModuleCommand]()

proc contains*(cmds: seq[ModuleCommand], name: string): bool = 
  ## Проверяет, находится ли команда name в командах модуля
  cmds.anyIt(name in it.cmds)

proc `[]`*(cmds: seq[ModuleCommand], name: string): ModuleCommand = 
  ## Возвращает объект ModuleCommand по имени команды
  for cmd in cmds:
    if name in cmd.cmds:
      return cmd

proc newModule*(name, fname: string): Module = 
  ## Создаёт новый модуль с названием name
  new(result)
  result.name = name
  result.filename = fname
  result.cmds = @[]
  result.anyCommands = @[]

proc addCmdHandler*(handler: ModuleFunction, name: string, 
                    cmds, usages: seq[string]) = 
  ## Процедура для создания ModuleCommand и его инициализации
  ## Пример - call.handle("привет", "ку"), где call - это ModuleFunction
  let module = modules[name]
  # Создаём объект команды
  let moduleCmd = ModuleCommand(cmds: cmds, usages: usages, call: handler)
  # Если это пустая команда - она реагирует на любые команды
  if cmds[0] == "": module.anyCommands.add handler
  else: module.cmds.add moduleCmd
  commands.add moduleCmd

proc addStartHandler*(name: string, handler: OnStartProcedure, needCfg = true) =
  ## Добавляет к модулю процедуру, которая выполняется после запуска бота
  modules[name].startProc = handler
  modules[name].needCfg = needCfg

proc processCommand*(bot: VkBot, body: string): Command =
  ## Обрабатывает строку {body} и возвращает тип Command
  # Если тело сообщения пустое
  if body.len == 0:
    return
  # Ищем префикс команды
  var foundPrefix: string
  for prefix in bot.config.prefixes:
    # Если команда начинается с префикса в нижнем регистре
    if unicode.toLower(body).startsWith(prefix):
      foundPrefix = prefix
      break
  # Если мы не нашли префикс - выходим
  if foundPrefix.isNil():
    return
  # Получаем команду и аргументы - берём слайс строки body без префикса,
  # используем strip для удаления нежелательных пробелов в начале и конце,
  # делим строку на имя команды и значения
  let values = body[len(foundPrefix)..^1].strip().split()
  let (name, args) = (values[0], values[1..^1])
  # Возвращаем первое слово из строки в нижнем регистре и аргументы
  return Command(name: unicode.toLower(name), args: args)
