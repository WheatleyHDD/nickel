# Различные команды, которые слишком малы для того, чтобы помещать их в
# отдельный модули
include base

module "📚 Хелперы":
  command "id", "ид":
    usage = "ид - узнать ID пользователя (нужно переслать его сообщение)"
    # Если пользователь не переслал никаких сообщений
    if msg.fwdMessages == @[]:
      answer usage
      return
    # Если у нас есть user id в пересланных сообщениях (callback api)
    var id = msg.fwdMessages[0].userId
    # Получаем user id через VK API
    if id == 0:
      let inf = await api@messages.getById(message_ids=msg.fwdMessages[0].msgId)
      id = inf["items"][0]["user_id"].getInt()

    answer "ID этого пользователя - " & $id
  
  command "сократи", "short", "сокр":
    usage = "сократи <ссылка> - сократить ссылку через vk.cc"
    let data = await api@utils.getShortLink(url=text)
    answer &"""Ваша ссылка: https://vk.cc/{data["key"].getStr()}"""
  
  command "инфо", "стата", "статистика":
    const 
      gitRev = 
        # Если в данной папке есть репозиторий и есть git клиент
        if dirExists(".git") and gorgeEx("git status")[1] == 0:
          staticExec("git rev-parse HEAD")
        else: "неизвестно"
    
    answer fmt"""Nickel - бот для ВКонтакте на Nim
    Автор - vk.com/yardanico
    Git-ревизия - {gitRev}
    Скомпилирован {CompileDate} в {CompileTime}
    Обработано команд: {cmdCount}
    Принято сообщений: {msgCount}
    """.unindent