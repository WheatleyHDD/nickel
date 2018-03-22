include base_imports
import sequtils  # Работа с последовательностями
# Свои модули
import utils  # Макрос unpack (взят со stackoverflow)
import types  # Общие типы бота
import vkapi  # Реализация VK API
import config # Парсинг файла конфигурации
import errors  # Обработка ошибок
import handlers  # Таблица {команда: плагин} и макросы
import log  # Логгирование
import user_long_poll  # Работа с User Long Polling
import callback_api  # Работа с Callback API
importPlugins()  # Импортируем все модули из папки modules

proc newBot(config: BotConfig): VkBot =
  ## Возвращает новый объект VkBot на основе токена
  let
    api = newApi(config)
    lpData = LongPollData()
    isGroup = config.token.len > 0
  # Запускаем бесконечный цикл отправки запросов через execute
  asyncCheck api.executeCaller()
  return VkBot(api: api, lpData: lpData, config: config, isGroup: isGroup)


proc parserModuleConfig(cfg: var JsonNode, module: Module) = 
  try:
    cfg = loadModuleConfig(module.filename)
  except:
    log(lvlError, fmt"Произошла ошибка при чтении {module.filename}.json:")
    log(lvlError, "\n" & getCurrentExceptionMsg())
    
proc initModules(bot: VkBot) {.async.} = 
  # Проходимся по всем модулям бота
  for name, module in modules:
    # Если у модуля нет процедуры запуска - пропускаем
    if module.startProc.isNil():
      continue
    var cfg: JsonNode
    # Если модулю нужен конфиг
    if module.needCfg:
      parserModuleConfig(cfg, module)
      # Если не получилось спарсить конфиг - "выключаем" модуль
      if cfg.isNil():
        modules.del(name)
        continue
    # Выполняем процедуру запуска модуля
    let fut = module.startProc(bot, cfg)
    # Ожидаем её завершения
    yield fut
    # Если при запуске модуля произошла ошибка
    if fut.failed:
      # Вызываем её
      try:
        raise fut.error
      except:
        let msg = fut.error.getStackTrace() & "\n" & getCurrentExceptionMsg()
        log(lvlError, fmt"При запуске модуля {name} произошла ошибка:\n{msg}")
        modules.del(name)
    elif fut.read == false:
      # Если модуль не захотел включаться - тоже удаляем его из списка модулей
      modules.del(name)

proc startBot(bot: VkBot) {.async.} =
  ## Инициализирует Long Polling или Callback API, модули 
  # и запускает приём сообщений
  await bot.initModules()
  if not bot.config.useCallback:
    await bot.initLongPolling()
    await bot.mainLoop()
  else:
    await bot.initCallbackApi()
  
proc gracefulShutdown() {.noconv.} =
  ## Выключает бота с ожиданием 500мс (срабатывает на Ctrl+C)
  notice("Выключение бота...")
  sleep(500)
  quit(0)

when isMainModule:
  when defined(windows):
     # Если мы на Windows - устанавливаем кодировку UTF-8 при запуске бота
    discard execShellCmd("chcp 65001")
    # И очищаем консоль
    discard execShellCmd("cls")
  # Парсим конфиг
  let cfg = parseBotConfig()
  # Выводим его значения (кроме логина, пароля, и токена)
  cfg.log()
  log(lvlInfo, "Авторизация в ВК...")
  # Создаём новый объект бота на основе конфигурации
  let bot = newBot(cfg)
  # Устанавливаем хук на Ctrl+C, пока что бесполезен, но
  # может пригодиться в будущем (закрывать сессии к БД и т.д)
  setControlCHook(gracefulShutdown)
  logWithLevel(lvlInfo):
    ("Общее количество загруженных команд - " & $len(commands))
    ("Бот успешно запущен и ожидает новых команд!")
  asyncCheck bot.startBot()
  runForever()