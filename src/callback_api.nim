include base_imports
# Стандартная библиотека
import asynchttpserver  # Асинхронный HTTP сервер

# Свои модули
import handlers  # Обработка команд
import message  # Обработка сообщения
import vkapi  # VK API
import utils  # Утилиты

var
  server = newAsyncHttpServer()
  bot: VkBot

proc processCallbackData(data: JsonNode) {.async.} = 
  ## Обрабатывает событие от Callback API
  # Получаем объект данного события
  let obj = data["object"]
  # Проверяем тип события
  case data["type"].getStr()
  # Новое сообщение
  of "message_new":
    # Тело сообщения
    let msgBody = obj["body"].getStr()
    # Собираем user_id пересланных сообщений (если они есть)
    var fwdMessages = newSeq[ForwardedMessage]()
    let rawFwd = obj.getOrDefault("fwd_messages")
    if not rawFwd.isNil():
      for msg in rawFwd.getElems():
        fwdMessages.add ForwardedMessage(userId: msg["user_id"].getInt())
    
    # Создаём объект сообщения
    let message = Message(
        kind: msgPriv,  # Callback API - только приватные сообщения
        id: obj["id"].getInt(),  # ID сообщения
        pid: obj["user_id"].getInt(),  # ID отправителя
        timestamp: obj["date"].getBiggestInt(),  # Когда было отправлено сообщение
        cmd: bot.processCommand(msgBody),  # Объект команды 
        body: msgBody,  # Тело сообщения
        fwdMessages: fwdMessages  # Пересланные сообщения
      )
    # Отправляем сообщение на обработку
    asyncCheck bot.checkMessage(message)

proc processRequest(req: Request) {.async, gcsafe.} =
  ## Обрабатывает запрос к серверу
  var data: JsonNode
  # Пытаемся спарсить JSON тела запроса
  try: data = parseJson(req.body)
  # Не получилось - игнорируем
  except: return
  if data["type"].getStr() == "confirmation":
    # Отвечаем кодом для активации
    await req.respond(Http200, bot.config.confirmationCode)
  else:
    # Обрабатываем сообщение дальше
    asyncCheck processCallbackData(data)
  # Отвечаем "ok" (обязательное условие Callback API)
  await req.respond(Http200, "ok")

proc initCallbackApi*(self: VkBot) {.async.} = 
  # Копируем ссылку на объект бота к себе
  bot = self
  # Запускаем сервер на 5000 порту
  asyncCheck server.serve(Port(5000), processRequest)
