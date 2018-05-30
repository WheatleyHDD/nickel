include base_imports
# Сортировка префиксов
import algorithm
import sequtils
# Парсинг конфигурации 
import parsetoml
# Стандартные конфигурации
import default_config

proc parseBotConfig*(): BotConfig =
  ## Парсит конфигурационные файлы бота или создаёт их при первом запуске
  const botCfg = "config" / "bot.toml"
  const moduleCfg = "config" / "modules.toml"
  try:
    createDir("config")
    let needCreate = not (existsFile(botCfg) or existsFile(moduleCfg))
    if not existsFile(botCfg):
      writeFile(botCfg, DefaultBotConfig)
    if not existsFile(moduleCfg):
      writeFile(moduleCfg, DefaultModulesConfig)
    if needCreate:
      fatalError "Created default configuration files, check `config` directory"
  except Exception as exc:
    fatalError "Can't create config files", error = exc.msg
  try:
    let data = parsetoml.parseFile(botCfg)
    #[Сортируем по длине префикса и переворачиваем последовательность, чтобы
    самые длинные префиксы были в начале. Это нужно для того, чтобы при
    наличиии нескольких префиксов разной длины, которые начинаются одинаково,
    выбирался самый подходящий]#
    let prefixes = data.getStringArray("Bot.prefixes").sortedByIt(it).reversed()
    let
      group = data.getTable("Group")
      user = data.getTable("User")
      bot = data.getTable("Bot")
      callback = data.getTable("CallbackApi")
      errors = data.getTable("Errors")
      messages = data.getTable("Messages")
      log = data.getTable("Logging")
    
    result = BotConfig(
      token: group.getString("token"),
      login: user.getString("login"),
      password: user.getString("password"),
      convertText: bot.getBool("try_convert"),
      reportErrors: errors.getBool("report"),
      fullReport: errors.getBool("complete_log"),
      errorMessage: messages.getString("error"),
      logMessages: log.getBool("messages"),
      logCommands: log.getBool("commands"),
      logErrors: log.getBool("errors"),
      prefixes: prefixes,
      useCallback: callback.getBool("enabled"),
      confirmationCode: callback.getString("code")
    )
    # Если в конфиге нет токена, или логин или пароль пустые
    if result.token == "" and (result.login == "" or result.password == ""):
      fatalError "No authentication data found in configuration"
    warn "Reading bot configuration from config/bot.json..."
    setLogLevel(parseEnum[LogLevel](log.getString("level")))
  except Exception as exc:
    fatalException "Can't load bot configuration"

proc parseModulesConfig*: TomlTableRef =
  ## Пытается спарсить общий файл конфигурации модулей, выходит при ошибке
  try: result = parsetoml.parseFile("config" / "modules.toml")
  except Exception as exc:
    fatalException "Can't read modules config file"

proc getModuleConfig*(global: TomlTableRef, m: Module): TomlTableRef =
  ## Получает секцию модуля из общей конфигурации модулей
  ## Возвращает кортеж (конфиг, ошибка).
  try: result = global.getTable(m.filename)
  # Записываем ошибку (если она произошла)
  except Exception as exc: 
    fatalException "Can't read modules config file"

proc log*(c: BotConfig) =
  ## Логгирует текущие настройки бота
  notice("Loaded bot configuration", 
    logMessages = c.logMessages,
    logCommands = c.logCommands,
    errorMsg = quotes(c.errorMessage), # Сообщение в кавычках
    reportErrors = c.reportErrors,
    logErrors = c.logErrors,
    fullErrorLog = c.fullReport,
    botPrefixes = toStr(c.prefixes)
  )