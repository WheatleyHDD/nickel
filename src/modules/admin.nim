include base
import sequtils

var admins = newSeq[int]()

module "Команды администратора":
  startConfig:
    admins = config["admins"].getElems().mapIt(it.getInt())
  
  command "выключись", "выключение":
    if msg.pid in admins:
      answer "Выключаюсь..."
      logNotice "Shutdown sent by admin", admin_id = msg.pid
      quit(0)