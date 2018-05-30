include base

var admins = newSeq[int64]()

module "Команды администратора":
  startConfig:
    admins = config.getIntArray("admins")
  
  command "выключись", "выключение":
    if msg.pid in admins:
      answer "Выключаюсь..."
      notice "Shutdown sent by admin", admin_id = msg.pid
      quit(0)