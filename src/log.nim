include baseimports
import times
import macros


template log*(data: string) =
  ## Выводит сообщение data со стилем style в консоль с указанием времени 
  stdout.write("\e[0;32m")  # Синий цвет
  stdout.write("[" & getClockStr() & "] ")  # Пишем время 
  stdout.write(data & "\n")  # Пишем само сообщение

proc log*(msg: Message, command: bool) = 
  ## Логгирует объект сообщения в консоль
  let `from` = "https://vk.com/id" & $msg.pid
  if command:
    var args = ""
    if len(msg.cmd.arguments) > 0:
      args = "с аргументами " & msg.cmd.arguments.join(", ")
    else:
      args = "без аргументов"
    # Зелёным цветом
    log(interp"${`from`} > Команда `${msg.cmd.command}` $args".fgGreen)
  else:
    # Голубым цветом
    log(interp"Сообщение `${msg.body}` от ${`from`}".fgCyan)

macro logWithStyle*(style: proc (data: string): string, body: untyped): untyped = 
  result = newStmtList()
  # проверяем, что body - список выражений
  expectKind body, nnkStmtList
  for elem in body:
    # Скобки
    expectKind elem, nnkPar
    # Длина - 1 элемент
    expectLen elem, 1
    # Получаем то, что нам нужно вывести
    let toWrite = elem[0]
    # Добавляем выражение к результату
    result.add quote do:
      log `style` `toWrite`
  
template logError*(data: string) = 
  log(data.fgRed.bold)

template logWarning*(data: string) = 
  log(data.fgYellow.bold)

template logSuccess*(data: string) = 
  log(data.fgGreen)

template logHint*(data: string) = 
  log(data.fgCyan)

proc Success*(data: string): string = 
  return data.fgGreen

proc Error*(data: string): string = 
  return data.fgRed.bold

proc Hint*(data: string): string = 
  return data.fgCyan

proc Warning*(data: string): string = 
  return data.fgYellow.bold