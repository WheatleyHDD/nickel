include base_imports
import chronicles
export chronicles
import macros

template fatalError*(name: string, data: varargs[untyped]) = 
  ## Логгирует ошибку data с уровнем error и выключает бота
  fatal name, data
  quit()

proc log*(msg: Message, command = false) = 
  ## Логгирует объект сообщения в консоль
  let frm = $msg.pid
  # Если нужно логгировать команду
  if command:
    info("New command", sender_id = frm, 
      cmd = quotes(msg.cmd.name), args = toStr(msg.cmd.args)
    )
  else:
    debug "New message", sender_id = frm, text = msg.body