include baseimports
 # Сортирование префиксов
import algorithm
import sequtils 

const
  FileCreatedMessage = """Был создан файл конфигурации settings.json. Пожалуйста, 
измените настройки на свои!"""

  NoLoginMessage = "Вы не указали данные для входа в settings.json!"

  ConfigLoadMessage = """Не удалось загрузить конфигурацию. 
Если у вас есть settings.json, попробуйте его удалить и запустить бота заново."""

  LoadMessage = "Загрузка настроек из settings.json..."

  DefaultSettings = """{
    "group": {
      "token": ""
    },
    "user": {
      "login": "",
      "password": ""
    },
    "bot": {
      "prefixes": ["бот", "бот,", "!"],
      "try_convert": true,
      "forward_conf": true
    },
    "callback_api": {
      "enabled": false,
      "code": "code"
    },
    "errors": {
      "report": true,
      "complete_log": true
    },
    "messages": {
      "on_error": "Произошла ошибка при выполнении бота:"
    },
    "log": {
      "format": "[$time][$levelid]",
      "level": "lvlInfo",
      "on_error": true,
      "on_message": true,
      "on_command": true
    }
  }"""

proc parseBotConfig*(): BotConfig =
  ## Парсинг settings.ini, создаёт его, если его нет, возвращает объект конфига
  const botCfg = "config" / "bot.json"
  if not existsFile(botCfg):
    open(botCfg, fmWrite).write(DefaultSettings)
    fatalError(FileCreatedMessage)
  try:
    let data = parseFile(botCfg)
    let prefixSeq = data["bot"]["prefixes"].elems.mapIt(it.str)
    # Сортируем по длине префикса, и переворачиваем последовательность, чтобы
    # самые длинные префиксы были в начале
    let prefixes = prefixSeq.sortedByIt(it).reversed()
    let
      # Секция группы
      group = data["group"]
      # Секция пользователя
      user = data["user"]
      # Секция бота
      bot = data["bot"]
      # Секция Callback API
      callback = data["callback_api"]
      # Секция ошибок
      errors = data["errors"]
      # Секция сообщений
      messages = data["messages"]
      # Секция логгирования
      log = data["log"]
      c = BotConfig(
        # Токен
        token: group["token"].getStr(),
        # Логин пользователя
        login: user["login"].getStr(),
        # Пароль пользователя
        password: user["password"].getStr(),
        # Нужно ли проверять на некорректную раскладку
        convertText: bot["try_convert"].getBool(),
        # Нужно ли пересылать сообщения, на которые отвечает бот в беседе
        forwardConf: bot["forward_conf"].getBool(),
        # Нужно ли отправлять пользователям сообщение об ошибке
        reportErrors: errors["report"].getBool(),
        # Отправлять ли пользователям полный лог ошибки
        fullReport: errors["complete_log"].getBool(),
        # Сообщение, которое выводится при ошибке бота
        errorMessage: messages["on_error"].getStr(),
        # Нужно ли логгировать сообщения
        logMessages: log["on_message"].getBool(),
        # Нужно ли логгировать команды
        logCommands: log["on_command"].getBool(),
        # Логгировать ли ошибки в консоль
        logErrors: log["on_error"].getBool(),
        # Префиксы, с помощью которых можно выполнять команды
        prefixes: prefixes,
        # Использовать ли Callback API
        useCallback: callback["enabled"].getBool(),
        # Код для подтверждения Callback API
        confirmationCode: callback["code"].getStr()
      )
    # Если в конфиге нет токена, или логин или пароль пустые
    if c.token == "" and (c.login == "" or c.password == ""):
      fatalError(NoLoginMessage)
    logger.levelThreshold = parseEnum[Level](log["level"].getStr())
    logger.fmtStr = log["format"].str
    log(lvlWarn, LoadMessage)
    return c
  except:
    # Если произошла какая-то ошибка при загрузке конфига
    fatalError(ConfigLoadMessage & "\nОшибка: " & getCurrentExceptionMsg())

proc loadModuleConfig*(name: string): JsonNode = 
  parseFile("config" / name & ".json")

proc log*(c: BotConfig) =
  ## Выводит объект настроек бота $config
  logWithLevel(lvlNotice):
    ("Логгировать сообщения - " & $c.logMessages)
    ("Логгировать команды - " & $c.logCommands)
    ("Сообщение при ошибке - \"" & $c.errorMessage & "\"")
    ("Отправлять ошибки пользователям - " & $c.reportErrors)
    ("Выводить ошибки в консоль - " & $c.logErrors)
    ("Отправлять полный лог ошибки пользователям - " & $c.fullReport)
    ("Используемые префиксы - " & $c.prefixes)