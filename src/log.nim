include base_imports
import logging
import macros

var logger* = newConsoleLogger()
addHandler(logger)
export logging

template log*(lvl: logging.Level, data: string): untyped =
  ## Шаблон для логгирования (С выводом места вызова этого шаблона)
  const 
    info = instantiationInfo()
    # Не пишем номера строк в release билде
    prefix = 
      when defined(release):
        "[$1] " % [info.filename]
      else:
        "[$1:$2] " % [info.filename, $info.line]
  logger.log(lvl, prefix & data)

template log*(data: string): untyped = log(lvlInfo, data)

proc fatalError*(data: string) = 
  ## Логгирует ошибку data с уровнем lvlFatal, и выключает бота
  log(lvlFatal, data)
  quit()

proc log*(msg: Message, command = false) = 
  ## Логгирует объект сообщения в консоль
  let frm = "https://vk.com/id" & $msg.pid
  # Если нужно логгировать команду
  if command:
    var args = ""
    if len(msg.cmd.args) > 0:
      args = "с аргументами " & toStr(msg.cmd.args)
    else:
      args = "без аргументов"
    log(lvlInfo, "$1 > Команда `$2` $3" % [frm, msg.cmd.name, args])
  else:
    log(lvlDebug, "Сообщение `$1` от $2" % [msg.body, frm])

macro logWithLevel*(lvl: Level, body: untyped): untyped = 
  result = newStmtList()
  for elem in body:
    result.add quote do:
      log(`lvl`, `elem`)