include base_imports

# Свои модули
import handlers  # Обработка команд
import message  # Обработка сообщения
import vkapi  # VK API
import utils  # Утилиты

using
  bot: VkBot
  api: VkApi

proc getLongPollUrl(bot) =
  ## Получает URL для Long Polling на основе данных bot.lpData
  const 
    UrlFormat = "https://$1?act=a_check&key=$2&ts=$3&wait=25&mode=2&version=3"
  let data = bot.lpData
  bot.lpUrl = UrlFormat % [data.server, data.key, $data.ts]

proc getLongPollApi(api): Future[LongPollData] {.async.} = 
  ## Возвращает значения Long Polling от VK API
  let params = {"use_ssl":"1", "lp_version": "3"}.toApi
  result = to(await api.callMethod(
    "messages.getLongPollServer", params, execute = false), 
    LongPollData
  )

proc initLongPolling*(bot; failNum = 0) {.async.} =
  ## Инициализирует данные или обрабатывает ошибку Long Polling сервера
  let data = await bot.api.getLongPollApi()
  case failNum
    of 0: bot.lpData = data
    of 1: bot.lpData.ts = data.ts
    of 2: bot.lpData.key = data.key
    of 3:
      bot.lpData.key = data.key
      bot.lpData.ts = data.ts
    else: discard
  # Обновляем URL Long Polling'а
  bot.getLongPollUrl()

proc processLpMessage(bot; event: seq[JsonNode]) {.async.} =
  ## Обрабатывает сырое событие нового сообщения
  # Распаковываем значения из события
  event.unpack(msgId, flags, peerId, ts, text, attaches)

  # Конвертируем число в set значений enum'а Flags
  let msgFlags = cast[set[Flags]](flags.getInt())
  # Если мы же и отправили это сообщение - его обрабатывать не нужно
  if Flags.Outbox in msgFlags: return
  # Заменяем некоторые символы и обрабатываем команду
  let cmd = bot.processCommand(text.getStr().multiReplace(
    {"<br>": "\n", "&quot;": ""}
  ))
  var fwdMessages = newSeq[ForwardedMessage]()
  # Если есть пересланные сообщения
  if "fwd" in attaches:
    for fwdMsg in attaches["fwd"].getStr().split(","):
      let data = fwdMsg.split("_")
      fwdMessages.add ForwardedMessage(msgId: data[1])
  # Создаём объект Message
  let message = Message(
      # Тип сообщения - если есть поле "from" - беседа, иначе - ЛС
      kind: if "from" in attaches: msgConf else: msgPriv,
      id: msgId.getInt(),  # ID сообщения
      pid: peerId.getInt(),  # ID отправителя
      timestamp: ts.getBiggestInt(),  # Когда было отправлено сообщение
      # Тема сообщения
      cmd: cmd,  # Объект команды 
      body: text.getStr(),  # Тело сообщения
      fwdMessages: fwdMessages  # Пересланные сообщения
    )
  # Если это конференция, то добавляем ID пользователя, который
  # отправил это сообщение
  if message.kind == msgConf:
    message.cid = attaches["from"].getStr().parseInt()
  asyncCheck bot.checkMessage(message)
  
proc mainLoop*(bot) {.async.} = 
  ## Главный цикл Long Polling (тут происходит получение новых событий)
  var http = newAsyncHttpClient()
  while true:
    bot.getLongPollUrl()
    let jsonData = parseJson(await http.getContent(bot.lpUrl))
    let failed = jsonData{"failed"}.getInt(-1)
    if failed != -1:
      await bot.initLongPolling(failed)
      continue
    # Проверяем, есть ли поле updates, и если нет - отправляем запрос заново
    if "updates" notin jsonData: continue
    for event in jsonData["updates"]:
      let
        elems = event.getElems()
        (eventType, eventData) = (elems[0].getInt(), elems[1..^1])
      case eventType:
        # Код события 4 - у нас новое сообщение
        of 4: asyncCheck bot.processLpMessage(eventData)
        # Другие события нам пока что не нужны :)
        else: discard
    # Обновляем метку времени
    bot.lpData.ts = jsonData["ts"].getInt()