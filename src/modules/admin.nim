include base

const AdminUid = 170831732


module "Команды администратора":
  command "выключись", "выключение":
    answer "Выключаюсь..."
    log(fmt"Выключение по запросу администратора https://vk.com/id{msg.pid}")
    quit(0)