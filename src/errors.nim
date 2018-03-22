include base_imports
import utils, vkapi

proc runCatch*(exec: ModuleFunction, bot: VkBot, msg: Message) = 
  ## Выполняет процедуру обработки команды модулем с проверкой
  ## на ошибки и их выводом
  var future = exec(bot.api, msg)
  future.callback =
    proc () {.gcsafe.} =
      # Если future завершилась без ошибок - всё хорошо
      if not future.failed:
        return
      var exceptionMsg = future.error.msg
      # Составляем полный лог ошибки
      let errorMsg = future.error.getStackTrace() & "\n" & exceptionMsg 
      # Анти-флуд
      let rnd = antiFlood() & "\n"
      # Сообщение, котороые мы пошлём
      var errorMessage = rnd & bot.config.errorMessage & "\n"
      if bot.config.fullReport:
        # Если нужно, добавляем полный лог ошибки
        errorMessage &= "\n" & errorMsg
      if bot.config.logErrors:
        # Если нужно писать ошибки в лог
        log(lvlError, "\n" & errorMsg)
      # Отправляем сообщение об ошибке (если нужно)
      if bot.config.reportErrors:
        asyncCheck bot.api.answer(msg, errorMessage)