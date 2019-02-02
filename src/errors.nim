include base_imports
import utils, vkapi

proc runCatch*(exec: ModuleFunction, bot: VkBot, msg: Message) = 
  ## Выполняет процедуру обработки команды модулем с проверкой
  ## на ошибки и их выводом
  var future = exec(bot.api, msg)
  future.callback =
    proc () {.gcsafe.} =
      # Если future завершилась без ошибок - всё хорошо
      if not future.failed: return
      # Составляем полный лог ошибки
      let errorMsg = future.error.getStackTrace() & "\n" & future.error.msg 
      # Анти-флуд
      let rnd = antiFlood() & "\n"
      # Сообщение, котороые мы пошлём
      var errorMessage = rnd & bot.config.errorMessage & "\n"
      if bot.config.fullReport: errorMessage &= "\n" & errorMsg
      if bot.config.logErrors: logError "Error!", info = errorMsg
      if bot.config.reportErrors: asyncCheck bot.api.answer(msg, errorMessage)