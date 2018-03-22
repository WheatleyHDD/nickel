include base
import httpclient

const
  Token = "4d59a157e0174dadaa9e8a11efb13c48"
  Url = "https://api.dialogflow.com/v1/query?v=20170712&"

let headers = newHttpHeaders({
    "Content-Type": "application/json", 
    "Authorization": "Bearer " & Token
})

proc callApi(id, message: string): Future[string] {.async.} = 
  let client = newAsyncHttpClient()
  client.headers = headers

  let data = {
    "lang": "ru",
    "contexts": "chat",
    "query": message,
    "sessionId": id
  }.newStringTable()

  let req = await client.get(Url & encode(data)) 
  let resp = parseJson(await req.body)["result"]
  let answer = resp{"fulfillment", "speech"}.getStr("")
  # Если бот уже решил, что ответить - отправляем
  if answer != "": return answer
  else:
    return "Я вас не понимаю. Попробуйте спросить что-то другое."
  
module "💬 Диалог":
  # Диалог поддерживает общение с пользователем, поэтому он реагирует на любое
  # сообщение кроме тех, которые являются командами, которые уже есть в боте
  command "":
    usage = ""
    answer await callApi($msg.pid, msg.body)