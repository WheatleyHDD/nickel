include baseimports
import logging
import macros

var logger* = newConsoleLogger()
addHandler(logger)
export logging

template log*(lvl: logging.Level, data: string): untyped =
  ## Шаблон для логгирования (С выводом файла и строки)
  const 
    pos = instantiationInfo()
    addition = "[$1:$2] " % [pos.filename, $pos.line]
  logger.log(lvl, addition & data)

template log*(data: string): untyped = log(lvlInfo, data)

proc fatalError*(data: string) = 
  log(lvlFatal, data)
  quit()

proc log*(msg: Message, command = false) = 
  ## Логгирует объект сообщения в консоль
  let frm = "https://vk.com/id" & $msg.pid
  # Если нужно логгировать команду
  if command:
    var args = ""
    if len(msg.cmd.args) > 0:
      args = "с аргументами " & $msg.cmd.args
    else:
      args = "без аргументов"
    log(lvlInfo, "$1 > Команда `$2` $3" % [frm, msg.cmd.name, args])
  else:
    log(lvlDebug, "Сообщение `$1` от $2" % [msg.body, frm])

macro logWithLevel*(lvl: Level, body: untyped): untyped = 
  result = newStmtList()
  for elem in body:
    let data = quote do:
      log(`lvl`, `elem`)
    result.add data