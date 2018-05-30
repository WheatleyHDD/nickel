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
  result = VkBot(
    api: newApi(config),
    lpData: LongPollData(),
    config: config,
    isGroup: config.token.len > 0
  )
  asyncCheck result.api.executeCaller()

proc stop(m: Module) = 
  modules.del(m.name)
  for cmd in m.cmds:
    # Удаляем команды этого модуля
    let idx = commands.find(cmd)
    if idx >= 0: commands.del(idx)
    let idxAny = anyCommands.find(cmd)
    if idxAny >= 0: anyCommands.del(idxAny)

proc initModules(bot: VkBot) {.async.} = 
  # Проходимся по всем модулям бота
  let allConfigs = parseModulesConfig()
  for name, module in modules:
    # Если у модуля нет процедуры запуска - пропускаем
    if module.startProc.isNil():
      continue
    # Если модулю нужен конфиг
    let cfg = if module.needCfg: allConfigs.getModuleConfig(module) else: nil
    # Выполняем процедуру запуска модуля
    let fut = module.startProc(bot, cfg)
    # Ожидаем её завершения
    yield fut
    # Если при запуске модуля произошла ошибка
    if fut.failed:
      try: raise fut.error
      except Exception as exc:
        let msg = fut.error.getStackTrace() & "\n" & exc.msg
        error "Can't initialize module", module = name, error = msg
        module.stop()
    # Если модуль не захотел включаться - тоже удаляем его из списка модулей
    elif fut.read() == false: module.stop()

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
  notice "Received shutdown request, stopping the bot..."
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
  # Выводим его значения (кроме логина, пароля и токена)
  cfg.log()
  info "VK authorization..."
  # Создаём новый объект бота на основе конфигурации
  let bot = newBot(cfg)
  # Устанавливаем хук на Ctrl+C, пока что бесполезен, но
  # может пригодиться в будущем (закрывать сессии к БД и т.д)
  setControlCHook(gracefulShutdown)
  info "Bot module statistics", command_count = len(commands)
  info "Bot successfully initialized"
  asyncCheck bot.startBot()
  runForever()