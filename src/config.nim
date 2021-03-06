include base_imports
import algorithm
import parsetoml

proc parseBotConfig*(): BotConfig =
  ## Парсит конфигурационные файлы бота или создаёт их при первом запуске
  if not existsDir("config"):
    fatalError "Move 'config_default' to 'config' and edit config files!"
  const botCfg = "config" / "bot.toml"
  try:
    let data = parsetoml.parseFile(botCfg)
    #[Сортируем по длине префикса и переворачиваем последовательность, чтобы
    самые длинные префиксы были в начале. Это нужно для того, чтобы при
    наличиии нескольких префиксов разной длины, которые начинаются одинаково,
    выбирался самый подходящий]#
    var prefixes: seq[string]
    for elem in data["Bot"]["prefixes"].getElems():
      prefixes.add(elem.getStr())
    prefixes = prefixes.sortedByIt(it)

    # Пока что не работает из-за проблемы в компиляторе
    # let prefixes = data["Bot.prefixes"].getElems().mapIt(it.getStr()).sortedByIt(it).reversed()
    let
      group = data["Group"].getTable()
      user = data["User"].getTable()
      bot = data["Bot"].getTable()
      callback = data["CallbackApi"].getTable()
      errors = data["Errors"].getTable()
      messages = data["Messages"].getTable()
      log = data["Logging"].getTable()
    
    result = BotConfig(
      token: group["token"].getStr(),
      login: user["login"].getStr(),
      password: user["password"].getStr(),
      convertText: bot["try_convert"].getBool(),
      forwardConf: bot["forward_conf"].getBool(),
      reportErrors: errors["report"].getBool(),
      fullReport: errors["complete_log"].getBool(),
      errorMessage: messages["error"].getStr(),
      logMessages: log["messages"].getBool(),
      logCommands: log["commands"].getbool(),
      logErrors: log["errors"].getBool(),
      prefixes: prefixes,
      useCallback: callback["enabled"].getBool(),
      confirmationCode: callback["code"].getStr()
    )
    useColors = bot["use_colors"].getBool()
    # Если в конфиге нет токена, или логин или пароль пустые
    if result.token == "" and (result.login == "" or result.password == ""):
      fatalError "No authentication data found in configuration"
    logWarn "Reading bot configuration from config/bot.toml..."
    logLevel = parseEnum[LogLevel](log["level"].getStr())
  except Exception as exc:
    fatalException "Can't load bot configuration"

proc parseModulesConfig*: TomlValueRef =
  ## Пытается спарсить общий файл конфигурации модулей, выходит при ошибке
  try: 
    result = parsetoml.parseFile("config" / "modules.toml")
  except Exception as exc:
    fatalException "Can't read modules config file"

proc getModuleConfig*(global: TomlValueRef, m: Module): TomlTableRef =
  ## Получает секцию модуля из общей конфигурации модулей
  ## Возвращает кортеж (конфиг, ошибка).
  try: result = global[m.filename].getTable()
  # Записываем ошибку (если она произошла)
  except Exception as exc:
    fatalException "Can't read modules config file"

proc log*(c: BotConfig) =
  ## Логгирует текущие настройки бота
  logNotice("Loaded bot configuration",
    logMessages = c.logMessages,
    logCommands = c.logCommands,
    errorMsg = quotes(c.errorMessage), # Сообщение в кавычках
    reportErrors = c.reportErrors,
    logErrors = c.logErrors,
    fullErrorLog = c.fullReport,
    botPrefixes = $c.prefixes
  )