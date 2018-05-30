include base_imports
# Стандартная библиотека
import sequtils
# Свои модули
import vkapi  # VK API
import errors  # Обработка ошибок бота
import types  # Общие типы бота
import utils  # Утилиты
import handlers  # Парсинг команд

var 
  msgCount* = 0
  cmdCount* = 0

proc processMessage*(bot: VkBot, msg: Message) {.async.} =
  ## Обрабатывает сообщение: логгирует, передаёт события плагинам
  let 
    cmdText = msg.cmd.name
    rusConverted = toRus(cmdText)
    engConverted = toEng(cmdText)
  var command = false
  # Увеличиваем счётчик сообщений
  inc msgCount
  # TODO: Уменьшить повторение кода в обработке раскладки
  if commands.contains(cmdText): command = true

  elif commands.contains(rusConverted):
    msg.cmd.name = rusConverted
    msg.cmd.args.applyIt it.toRus()
    command = true

  elif commands.contains(engConverted):
    msg.cmd.name = engConverted
    msg.cmd.args.applyIt it.toEng()
    command = true
  if command:
    inc cmdCount
    if bot.config.logCommands: msg.log(command = true)
    # Выполняем процедуру модуля асинхронно с хэндлером ошибок
    runCatch(commands[msg.cmd.name].call, bot, msg)
  else:
    if useAnyCommands: # Если есть хотя бы один обработчик любых сообщений
      for cmd in anyCommands: runCatch(cmd.call, bot, msg)
    # Если это не команда, и нужно логгировать сообщения
    if bot.config.logMessages: msg.log()

proc checkMessage*(bot: VkBot, msg: Message) {.async.} = 
  ## Выполняет обработку сообщения и проверяет ошибки
  let processResult = bot.processMessage(msg)
  yield processResult
  # Если сообщение не удалось обработать
  if processResult.failed:
    let rnd = antiFlood() & "\n"
    # Сообщение, котороые мы пошлём
    var errorMessage = rnd & bot.config.errorMessage & "\n"
    if bot.config.fullReport:
      # Если нужно, добавляем полный лог ошибки
      errorMessage &= "\n" & getCurrentExceptionMsg()
    if bot.config.logErrors:
      # Если нужно писать ошибки в консоль
      error "Message processing error", error = getCurrentExceptionMsg()
    # Отправляем сообщение об ошибке
    await bot.api.answer(msg, errorMessage)