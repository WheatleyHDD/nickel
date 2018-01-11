include baseimports
import types
import utils
import sequtils
import queues
import macros

type
  # Кортеж для обозначения нашего запроса к API через метод VK API - execute
  MethodCall = tuple[myFut: Future[JsonNode], 
                     name: string,
                     params: StringTableRef]

const
  # Для авторизации от имени пользователя мы используем 
  # данные официального приложения ВКонтакте под iPhone
  AuthScope = "all"
  ClientId = "3140623"
  ClientSecret = "VeWdmVclDCtn6ihuP1nt"

proc postData*(client: AsyncHttpClient, url: string, 
               params: StringTableRef): Future[AsyncResponse] {.async.} =
  ## Делает POST запрос на {url} с параметрами {params}
  return await client.post(url, body=encode(params))

proc login*(login, password: string): string = 
  # Входит в VK через login и password, используя данные Android приложения
  let authParams = {"client_id": ClientId, 
                    "client_secret": ClientSecret, 
                    "grant_type": "password", 
                    "username": login, 
                    "password": password, 
                    "scope": AuthScope, 
                    "v": "5.60"}.toApi
  let 
    client = newHttpClient()
    # Кодируем параметры через url encode
    body = encode(authParams)
  try:
    # Посылаем запрос
    let data = client.postContent("https://oauth.vk.com/token", body = body)
    # Получаем наш authToken
    result = data.parseJson()["access_token"].str
  except OSError:
    log.error("Не могу авторизоваться, скорее всего нет доступа к интернету!")
    quit(1)
  log(lvlInfo, "Бот успешно авторизовался!")

proc newApi*(c: BotConfig): VkApi =
  ## Создаёт новый объект VkAPi и возвращает его
  # Создаём токен (либо авторизуем пользователя, либо берём из конфига)
  let token = if c.login != "": login(c.login, c.password) else: c.token
  # Возвращаем результат
  result = VkApi(token: token, fwdConf: c.forwardConf, isGroup: c.token.len > 0)

proc toExecute(methodName: string, params: StringTableRef): string {.inline.} = 
  ## Конвертирует вызов метода с параметрами в формат, необходимый для execute
  # Если нет параметров, нам не нужно их обрабатывать
  if params.len == 0:
    return "API." & methodName & "()"
  let
    # Получаем последовательность из параметров вызовы
    pairsSeq = toSeq(params.pairs)
    # Составляем последовательность аргументов к вызову API
    keyValSeq = pairsSeq.mapIt(
      "\"$1\":\"$2\"" % [
        it.key,
        # Заменяем \n на <br> и " на \"
        it.value.multiReplace(("\n", "<br>"), ("\"", "\\\""))
      ]
    )
  # Возвращаем полный вызов к API с именем метода и параметрами
  result = "API." & methodName & "({" & keyValSeq.join(", ") & "})"

# Создаём очередь запросов (по умолчанию делаем её из 32 элементов)
var requests = initQueue[MethodCall](32)

proc callMethod*(api: VkApi, methodName: string, params: StringTableRef = nil,
                 auth = true, flood = false, 
                 execute = true): Future[JsonNode] {.async, discardable.} = 
  ## Отправляет запрос к методу {methodName} с параметрами {params}
  ## и дополнительным {token} (по умолчанию отправляет его через execute)
  const
    BaseUrl = "https://api.vk.com/method/"
  
  let
    http = newAsyncHttpClient()
    # Используем токен только если для этого метода он нужен
    token = if auth: api.token else: ""
    # Создаём URL
    url = BaseUrl & "$1?access_token=$2&v=5.67&" % [methodName, token]
  # Переменная, в которую записывается ответ от API в JSON
  var jsonData: JsonNode
  # Если нужно использовать execute
  if execute:
    # Создаём future для получения информации
    let apiFuture = newFuture[JsonNode]("callMethod")
    # Добавляем его в очередь запросов
    requests.add((apiFuture, methodName, params))
    # Ожидаем получения результата от execute()
    jsonData = await apiFuture
  # Иначе - обычный вызов API
  else:
    let 
      # Отправляем запрос к API
      req = await http.postData(url, params)
      # Получаем ответ
      resp = await req.body
    # Если была ошибка о флуде, добавляем анти-флуд
    if flood:
      params["message"] = antiFlood() & "\n" & params["message"]
    # Парсим ответ от сервера
    jsonData = parseJson(resp)
  
  let response = jsonData.getOrDefault("response") 
  # Если есть секция response - нам нужно вернуть ответ из неё
  if response != nil:
    return response
  # Иначе - проверить на ошибки, и просто вернуть ответ, если всё хорошо
  else:
    let error = jsonData.getOrDefault("error")
    # Если есть какая-то ошибка
    if error != nil:
      case error["error_code"].getInt():
      # Слишком много одинаковых сообщений
      of 9:
        # await api.apiLimiter()
        return await callMethod(api, methodName, params, auth, flood = true)
      # Капча
      of 14:
        # TODO: Обработка капчи
        let 
          sid = error["captcha_sid"].str
          img = error["captcha_img"].str
        log.error("Капча $1 - $2" % [sid, img])
        params["captcha_sid"] = sid
        #params["captcha_key"] = key
        #return await callMethod(api, methodName, params, needAuth)
      else:
        log.error("Ошибка при вызове $1 - $2\n$3" % [methodName, 
                  error["error_msg"].str, $jsonData])
        
    else:
      # Если нет ошибки и поля response, просто возвращаем ответ
      return jsonData
  # Возвращаем пустой JSON объект
  return  %*{}

proc executeCaller*(api: VkApi) {.async.} = 
  ## Бесконечный цикл, проверяет последовательность запросов requests 
  ## для их выполнения через execute
  while true:
    # Спим 350 мс
    await sleepAsync(350)
    # Если в очереди нет элементов
    if requests.len == 0:
      continue
    
    var 
      # Последовательность вызовов API в виде VKScript
      items: seq[string] = @[]
      # Последовательность future
      futures: seq[Future[JsonNode]] = @[]
      # Максимальное кол-во запросов к API через execute минус 1
      count = 24
    # Пока мы не опустошим нашу очередь или лимит запросов кончится
    while requests.len != 0 and count != 0:
      # Получаем самый старый элемент
      let (fut, name, params) = requests.pop()
      # Добавляем в items вызов метода в виде строки кода VKScript
      items.add name.toExecute(params)
      futures.add(fut)
      # Уменьшаем количество доступных запросов
      dec count
    # Составляем общий код VK Script
    let code = "return [" & items.join(", ") & "];"
    # Отправляем запрос (false - не отправлять его самого через execute)
    let answer = await api.callMethod("execute", {"code": code}.toApi, 
                                      execute = false)
    # Проходимся по результатам и futures
    for data in zip(answer.getElems(), futures):
      let (item, fut) = data
      # Завершаем future с результатом
      fut.complete(item)


proc attaches*(msg: Message, vk: VkApi): Future[seq[Attachment]] {.async.} =
  ## Получает аттачи сообщения {msg} используя объект API - {vk}
  result = @[]
  # Если у сообщения уже есть аттачи
  if msg.doneAttaches != nil:
    return msg.doneAttaches
  let 
    # Значения для запроса
    values = {"message_ids": $msg.id, "previev_length": "1"}.toApi
    msgData = await vk.callMethod("messages.getById", values)
  # Если произошла ошибка при получении данных - ничего не возвращаем
  if msgData == %*{}:
    return
  
  let 
    message = msgData["items"][0]
    attaches = message.getOrDefault("attachments")
  # Если нет ни одного аттача
  if attaches == nil:
    return
  # Проходимся по всем аттачам
  for rawAttach in attaches.getElems():
    let
      # Тип аттача
      typ = rawAttach["type"].str
      # Сам аттач
      attach = rawAttach[typ]
    var
      # Ссылка на аттач (на фотографию, документ, или видео)
      link = ""
    # Ищем ссылку на аттач
    case typ
    of "doc":
      # Ссылка на документ
      link = attach["url"].str
    of "video":
      # Ссылка с плеером видео (не работает от имени группы)
      try:
        link = attach["player"].str
      except KeyError:
        discard
    of "photo":
      # Максимальное разрешение фотографии, которое мы нашли
      var biggestRes = 0
      # Проходимся по всем полям аттача
      for k, v in pairs(attach):
        if "photo_" in k:
          # Парсим разрешение фотографии
          let photoRes = parseInt(k[6..^1])
          # Если оно выше, чем остальные, берём используем его
          if photoRes > biggestRes:
            biggestRes = photoRes
            link = v.str
    let
      # Если есть access_key - добавляем его, иначе - ничего не добавляем
      key = if "access_key" in attach: attach["access_key"].str else: ""
      resAttach = (typ, $attach["owner_id"].num, 
                  $attach["id"].num, key, link)
    # Добавляем аттач к результату
    result.add(resAttach)
  msg.doneAttaches = result

proc answer*(api: VkApi, msg: Message, body: string, attaches = "") {.async.} =
  ## Упрощённая процедура для ответа на сообщение {msg}
  let data = {"message": body, "peer_id": $msg.pid}.toApi
  # Если это конференция, пересылаем то сообщение, на которое мы ответили
  if msg.kind == msgConf and api.fwdConf: data["forward_messages"] = $msg.id
  # Если есть какие-то аттачи, добавляем их
  if attaches.len > 0: data["attachment"] = attaches
  discard await api.callMethod("messages.send", data)

template answer*(data: typed, atch = "", wait = false) {.dirty.} = 
  ## Отправляет сообщение $data пользователю
  let toSend = when data is string: data else: data.join("\n")
  when wait:
    yield api.answer(msg, toSend, attaches=atch)
  else:
    asyncCheck api.answer(msg, toSend, attaches=atch)

# https://github.com/TiberiumN/nimvkapi
macro `@`*(api: VkApi, body: untyped): untyped =
  # Copy input, so we can modify it
  var input = copyNimTree(body)
  # Copy API object
  var api = api

  proc getData(node: NimNode): NimNode =
    # Table with API parameters
    var table = newNimNode(nnkTableConstr)
    # Name of method call
    let name = node[0].toStrLit
    let textName = $name
    for arg in node.children:
      # If it's a equality expression "abcd=something"
      if arg.kind == nnkExprEqExpr:
        # Convert key to string, and call $ for value to convert it to string
        table.add(newColonExpr(arg[0].toStrLit, newCall("$", arg[1])))
    # Generate result
    result = quote do: 
      `api`.callMethod(`name`, `table`.toApi)
  
  template isNeeded(n: NimNode): bool = 
    ## Returns true if NimNode is something like 
    ## "users.get(user_id=1)" or "users.get()" or "execute()"
    n.kind == nnkCall and (n[0].kind == nnkDotExpr or $n[0] == "execute")
  
  proc findNeeded(n: NimNode) =
    var i = 0
    # For every children
    for child in n.children:
      # If it's the children we're looking for
      if child.isNeeded():
        # Modify our children with generated info
        n[i] = child.getData().copyNimTree()
      else:
        # Recursively call findNeeded on child
        child.findNeeded()
      inc i  # increment index
  
  # If we're looking for that input
  if input.isNeeded():
    # Generate needed info
    return input.getData()
  else:
    # Find needed NimNode in input, and replace it here
    input.findNeeded()
    return input