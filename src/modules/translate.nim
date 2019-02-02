include base
import httpclient, unicode

const
  TranslateUrl = "https://translate.yandex.net/api/v1.5/tr.json/translate"
  LanguagesUrl = "https://translate.yandex.net/api/v1.5/tr.json/getLangs"

var apiKey = ""
let headers = newHttpHeaders(
  {"Content-type": "application/x-www-form-urlencoded"}
)
let langs = newStringTable()

proc callApi(url: string, params: StringTableRef): Future[JsonNode] {.async.} = 
  let client = newAsyncHttpClient()
  client.headers = headers
  result = parseJson await client.postContent(url, encode(params))

proc getLanguages() {.async.} = 
  let params = {"key": apiKey, "ui": "ru"}.newStringTable()
  let data = await LanguagesUrl.callApi(params)
  # Проходимся по словарю код_языка: отображаемое_имя
  for ui, display in data["langs"].getFields():
    # langs - таблица отображаемое_имя: код_языка
    langs[unicode.toLower(display.getStr())] = ui

proc translate(text, to: string): Future[string] {.async.} = 
  let params = {"key": apiKey, "text": text, "lang": to}.newStringTable()
  result = (await TranslateUrl.callApi(params))["text"][0].getStr()

module "🔤 Переводчик":
  startConfig:
    apiKey= config["key"].getStr()
    if apiKey == "":
      logWarn "API key for translation module is not specified"
      return false
    # Получаем список языков от Яндекса
    await getLanguages()
  
  command "переведи":
    usage = [
      "переведи на $язык $текст - перевести $текст на $язык", 
      "переведи $текст - перевести $текст на русский"
    ]
    if text.len > 600:
      answer "Слишком много текста!"
      return
    if args.len < 1:
      answer usage
      return
    var lang, data: string
    # Если команда - "переведи на русский hello"
    if args[0] == "на":
      lang = args[1]
      data = args[2..^1].join(" ")
    # Если команда - "переведи русский hello"
    elif langs.hasKey(args[0]):
      lang = args[0]
      data = args[1..^1].join(" ")
    # Если команда - "переведи hello"
    else:
      lang = "русский"
      data = args.join(" ")
    try: answer await data.translate(langs[lang])
    except: answer "Перевести данный текст не удалось!"