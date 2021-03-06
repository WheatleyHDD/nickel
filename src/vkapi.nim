include base_imports
import types
import utils
import sequtils
import deques
import macros

type
  # Кортеж для обозначения нашего запроса к API через метод VK API - execute
  MethodCall = tuple[
    myFut: Future[JsonNode],
    name: string,
    params: StringTableRef
  ]

const
  # Данные официального приложения ВКонтакте на iPhone для авторизации.
  AuthScope = "all"
  ClientId = "3140623"
  ClientSecret = "VeWdmVclDCtn6ihuP1nt"

# Макрос для более удобного вызова VK API.
# Взято из https://github.com/vk-brain/nimvkapi
macro `@`*(api: VkApi, body: untyped): untyped =
  # Copy input, so we can modify it
  var input = copyNimTree(body)
  # Copy API object
  var api = api

  proc getData(node: NimNode): NimNode =
    # Table with API parameters
    var table = newNimNode(nnkTableConstr)
    let name = node[0].toStrLit
    let textName = $name
    for arg in node.children:
      # If it's a equality expression "abcd=something"
      if arg.kind == nnkExprEqExpr:
        # Convert key to string, and call $ for value to convert it to string
        table.add(newColonExpr(arg[0].toStrLit, newCall("$", arg[1])))
      # If it's something like "abcd=$somevalue" or "abcd=process(value)"
      elif arg.kind == nnkInfix and $arg[0] == "=$":
        table.add(newColonExpr(arg[1].toStrLit, newCall("$", arg[2])))
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
      inc i # increment index
  
  # If we're looking for that input
  if input.isNeeded(): return input.getData()
  else:
    # Find needed NimNode in input, and replace it here
    input.findNeeded()
    return input

proc postData*(client: AsyncHttpClient, url: string,
              params: StringTableRef): Future[AsyncResponse] {.async.} =
  ## Делает POST запрос на {url} с параметрами {params}
  result = await client.post(url, body = encode(params))

proc login*(login, password: string): string =
  ## Входит в VK через login и password, используя данные iPhone приложения

  let authParams = {
    "client_id": ClientId,
    "client_secret": ClientSecret,
    "grant_type": "password",
    "username": login,
    "password": password,
    "scope": AuthScope,
    "v": "5.124"
  }.toApi

  let
    client = newHttpClient()
    body = encode(authParams)

  try:
    let data = client.postContent("https://oauth.vk.com/token", body)
    # Получаем наш authToken
    result = data.parseJson()["access_token"].getStr()
  except OSError:
    fatalError "Can't connect to vk.com: check your internet connection"
  logInfo "Bot successfully logged in"

proc newApi*(c: BotConfig): VkApi =
  ## Создаёт новый объект VkAPi и возвращает его
  # Создаём токен (либо авторизуем пользователя, либо берём из конфига)
  let token = if c.login != "": login(c.login, c.password) else: c.token
  # Возвращаем результат
  result = VkApi(token: token, fwdConf: c.forwardConf,
      isGroup: c.token.len > 0)

proc toExecute(methodName: string, params: StringTableRef): string =
  ## Конвертирует вызов метода с параметрами в формат, необходимый для execute
  # Если нет параметров, нам не нужно их обрабатывать
  result = if params.len == 0:
    "API." & methodName & "()"
  else:
    let
      # Получаем последовательность из параметров вызовы
      pairsSeq = toSeq(params.pairs)
      # Составляем последовательность аргументов к вызову API
      keyValSeq = pairsSeq.mapIt(
        "\"$1\":\"$2\"" % [
          it.key,
          # Заменяем \n на <br> и " на \"
          it.value.multiReplace(("\n", "<br>"), ("\"", "\\\""))
      ])
    # Возвращаем полный вызов к API с именем метода и параметрами
    "API." & methodName & "({" & keyValSeq.join(", ") & "})"

# Создаём очередь запросов (по умолчанию делаем её из 32 элементов)
var requests = initDeque[MethodCall](32)

proc callMethod*(api: VkApi, methodName: string, params: StringTableRef = nil,
                auth = true, flood = false,
                execute = true): Future[JsonNode] {.async.} =
  ## Делает запрос к методу {methodName} с параметрами {params}
  ## и дополнительным {token} (по умолчанию делает запрос через execute)
  result = %*{}

  const
    BaseUrl = "https://api.vk.com/method/"

  let
    http = newAsyncHttpClient()
    # Используем токен только если для этого метода он нужен
    token = if auth: api.token else: ""
    # Создаём URL
    url = &"{BaseUrl}{methodName}?access_token={token}&v=5.67&"
  var jsonData: JsonNode
  # Если нужно использовать execute
  if execute:
    # Создаём future для получения информации
    let apiFuture = newFuture[JsonNode]("callMethod")
    # Добавляем наш вызов в очередь запросов
    requests.addLast((apiFuture, methodName, params))
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
  
  let response = jsonData{"response"}
  let execErr = (methodName == "execute" and "execute_errors" in jsonData)
  # Если есть секция response - нам нужно вернуть ответ из неё
  if not response.isNil() and not execErr:
    return response
  # Иначе - проверить на ошибки, и просто вернуть ответ, если всё хорошо
  else:
    let errors = 
      if execErr: jsonData{"execute_errors"}.getElems(@[])
    else:
      @[jsonData{"error"}]
    # Если есть какая-то ошибка
    for error in errors:
      if error{"error_code"} != nil:
        case error["error_code"].getInt():
        # Слишком много одинаковых сообщений
        of 9:
          # await api.apiLimiter()
          return await callMethod(api, methodName, params, auth, flood = true)
        # Капча
        of 14:
          # TODO: Обработка капчи
          let
            sid = error["captcha_sid"].getStr()
            img = error["captcha_img"].getStr()
          logError "Captcha", sid = sid, image_link = img
          params["captcha_sid"] = sid
        #params["captcha_key"] = key
          #return await callMethod(api, methodName, params, needAuth)
        else:
          logError("VK API call error", apiMethod = methodName,
            error = error["error_msg"].getStr(), json = error
          )
    # Если нет ошибки и поля response, просто возвращаем ответ
    if errors.len == 0:
      return jsonData

proc executeCaller*(api: VkApi) {.async.} =
  ## Бесконечный цикл, проверяет последовательность запросов requests 
  ## для их выполнения через execute
  while true:
    await sleepAsync(350)
    if requests.len == 0: continue

    var
      # Последовательность вызовов API в виде VKScript
      items = newSeqOfCap[string](24)
      # Последовательность future
      futures = newSeqOfCap[Future[JsonNode]](24)
      # Максимальное кол-во запросов к API через execute минус 1
      count = 24
    # Пока мы не опустошим нашу очередь или лимит запросов кончится
    while requests.len != 0 and count != 0:
      # Получаем самый старый элемент
      let (fut, name, params) = requests.popFirst()
      # Добавляем в items вызов метода в виде строки кода VKScript
      items.add(toExecute(name, params))
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
      # Завершаем future с полученным результатом
      fut.complete(item)

proc attaches*(msg: Message, vk: VkApi): Future[seq[Attachment]] {.async.} =
  ## Получает аттачи сообщения {msg} используя объект API - {vk}
  result = @[]
  # Если у сообщения уже получены аттачи
  if len(msg.doneAttaches) > 0: return msg.doneAttaches
  msg.doneAttaches = @[]
  let msgData = await vk@messages.getById(message_ids = msg.id)
  # Если произошла ошибка при получении данных - ничего не возвращаем
  if msgData == %*{}: return
  let
    message = msgData["items"][0]
    attaches = message{"attachments"}
  # Если нет ни одного аттача
  if attaches.isNil(): return
  # Проходимся по всем аттачам
  for rawAttach in attaches.getElems():
    let typ = rawAttach["type"].getStr() # Тип аттача
    let attach = rawAttach[typ] # Сам аттач
    var link = "" # Ссылка на аттач (на фотографию, документ, или видео)
    case typ
    # Документ
    of "doc": link = attach["url"].getStr()
    of "video":
      # Ссылка с плеером видео (не работает от имени группы)
      try: link = attach["player"].getStr()
      except KeyError: discard
    of "photo":
      # Максимальное разрешение фотографии, которое мы нашли
      var biggestRes = 0
      # Проходимся по всем полям аттача
      for k, v in attach:
        if "photo_" in k:
          # Парсим разрешение фотографии
          let photoRes = parseInt(k[6..^1])
          # Если оно выше, чем остальные, берём его
          if photoRes > biggestRes:
            biggestRes = photoRes
            link = v.getStr()
    let
      # Если есть access_key - получаем его
      key = attach{"access_key"}.getStr("")
      resAttach = (typ, $attach["owner_id"].getInt(),
                  $attach["id"].getInt(), key, link)
    msg.doneAttaches.add(resAttach)
  return msg.doneAttaches

proc answer*(api: VkApi, msg: Message, body: string, attaches = "") {.async.} =
  ## Упрощённая процедура для ответа на сообщение {msg}
  let data = {"message": body, "peer_id": $msg.pid}.toApi
  # Если это конференция, пересылаем то сообщение, на которое мы ответили
  if msg.kind == msgConf and api.fwdConf: data["forward_messages"] = $msg.id
  # Если есть какие-то аттачи, добавляем их
  if attaches.len > 0: data["attachment"] = attaches
  discard await api.callMethod("messages.send", data)

template answer*(data: typed, atch = "", wait = false) {.dirty.} =
  ## Отправляет сообщение $data пользователю.
  ## Создано для использования в модулях, так как там неявно доступны объекты
  ## текущего сообщения и API
  template toSend: untyped {.dirty.} =
    when data is string: data else: data.join("\n")
  when wait:
    yield api.answer(msg, toSend, attaches = atch)
  else:
    asyncCheck api.answer(msg, toSend, attaches = atch)
