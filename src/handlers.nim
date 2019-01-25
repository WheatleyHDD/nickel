include base_imports
# Стандартная библиотека
import tables  # Таблицы (для соотношения команд с процедурами-обработчиками)
import sequtils
# Свои модули
import types  # Общие типы бота

var
  modules* = initTable[string, Module]()
  commands* = newSeq[ModuleCommand]()
  anyCommands* = newSeq[ModuleCommand]()
  useAnyCommands* = false

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
  Module(name: name, filename: fname, cmds: @[])

proc addCmdHandler*(m: Module, handler: ModuleFunction, 
                  cmds, usages: seq[string]) = 
  ## Процедура для создания ModuleCommand и его инициализации
  ## Пример - call.addCmdHandler("привет", "ку")
  let moduleCmd = ModuleCommand(cmds: cmds, usages: usages, call: handler)
  m.cmds.add(moduleCmd)
  if "" in cmds: 
    useAnyCommands = true
    anyCommands.add(m.cmds)
  else: commands.add(m.cmds)

proc addStartHandler*(m: Module, handler: OnStartProcedure, needCfg = true) =
  ## Добавляет к модулю процедуру, которая выполняется после запуска бота
  m.startProc = handler
  m.needCfg = needCfg

proc processCommand*(bot: VkBot, body: string): Command =
  ## Обрабатывает строку {body} и возвращает тип Command
  # Инициализируем список аргументов (даже если сообщение пустое)
  result = Command(name: "", args: @[])
  if body == "": return
  # Ищем префикс команды
  var 
    foundPrefix = false
    cmdPrefix = ""
  for prefix in bot.config.prefixes:
    # Если команда начинается с префикса в нижнем регистре
    if unicode.toLower(body).startsWith(prefix):
      foundPrefix = true
      cmdPrefix = prefix
      break
  # Если мы не нашли префикс - выходим
  if not foundPrefix: return
  # Получаем команду и аргументы - берём слайс строки body без префикса,
  # используем strip для удаления нежелательных пробелов в начале и конце,
  # делим строку на имя команды и значения
  let values = unicode.split(unicode.strip(body[len(cmdPrefix)..^1]))
  # Возвращаем первое слово из строки в нижнем регистре и аргументы
  result.name = values[0]
  result.args = values[1..^1]