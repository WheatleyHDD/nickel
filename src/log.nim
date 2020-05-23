import std / [macros, terminal, strutils, strformat, times]

import types, utils

type
  LogLevel* = enum
    lvlDebug = "DEBUG"
    lvlInfo = "INFO"
    lvlNotice = "NOTICE"
    lvlWarn = "WARN"
    lvlError = "ERROR"
    lvlFatal = "FATAL"

# Default logging level, can be changed
var logLevel* = lvlInfo

const levelToColor: array[LogLevel, ForegroundColor] = [
  fgWhite, fgGreen, fgCyan, fgYellow, fgRed, fgRed
]

proc log*(lvl: LogLevel, line: string) =
  ## Logs message with specified log level to the stdout
  setForegroundColor(stdout, levelToColor[lvl])
  echo fmt"{now()} | {$lvl:^6} | {line}"
  resetAttributes()

macro getFormatted(data: varargs[untyped]): untyped =
  ## Returns a strutils.format call for code like
  ## getFormatted("Test", a = 1, b = "hello")
  result = newTree(nnkCall)

  var fmtIdent = newTree(nnkDotExpr)
  fmtIdent.add(newIdentNode("strutils"))
  fmtIdent.add(newIdentNode("format"))
  result.add(fmtIdent)

  var fmtString = ""
  var i = 1
  # List of arguments to a `format` call
  var tmp = newSeq[NimNode]()

  for arg in data:
    # Literal string
    if arg.kind == nnkStrLit:
      fmtString &= arg.strVal
    # a = b
    elif arg.kind == nnkExprEqExpr:
      fmtString &= ", " & arg[0].strVal & " = $" & $i
      tmp.add(arg[1])
      inc(i)
  
  result.add(newLit(fmtString))
  # Add nodes which will be used as arguments
  for node in tmp:
    result.add(node)

template genTemplate(name: untyped, lvl: untyped): untyped =
  template name*(data: varargs[untyped]): untyped =
    log(lvl, getFormatted(data))

# Generate templates for all log levels
genTemplate(logDebug, lvlDebug)
genTemplate(logInfo, lvlInfo)
genTemplate(logNotice, lvlNotice)
genTemplate(logWarn, lvlWarn)
genTemplate(logError, lvlError)
genTemplate(logFatal, lvlFatal)


template fatalError*(data: varargs[untyped]) =
  ## Логгирует ошибку data с уровнем error и выключает бота
  logFatal(data)
  quit()


proc log*(msg: Message, command = false) =
  ## Логгирует объект сообщения в консоль
  let frm = $msg.pid
  # Если нужно логгировать команду
  if command:
    logInfo(
      "New command", sender_id = frm,
      cmd = quotes(msg.cmd.name), args = toStr(msg.cmd.args)
    )
  else:
    logDebug("New message", sender_id = frm, text = msg.body)