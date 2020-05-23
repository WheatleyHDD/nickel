include base
import httpclient, times

const
  Url = "https://api.exchangeratesapi.io/latest?base=RUB"
  # При желании сюда можно добавить другие валюты, доступные на fixer.io

# https://github.com/nim-lang/Nim/issues/14410
let Currencies = {
  "USD": "Доллар: ",
  "EUR": "Евро: ",
  "GBP": "Английский фунт: "
}.toTable

var
  data = ""
  lastTime = getTime()

proc getData(): Future[string] {.async.} =
  let client = newAsyncHttpClient()
  result = ""
  # Если у нас сохранены данные и прошло меньше 12 часов
  if data.len > 0 and (getTime() - lastTime).inHours <= 12: return data
  # Иначе - получаем их
  let rates = parseJson(await client.getContent(Url))["rates"]
  for curr, text in Currencies.pairs:
    let rubleInfo = rates[curr].getFloat()
    # Добавляем название валюты
    result.add(text)
    # И само значение
    result.add((1 / rubleInfo).formatFloat(precision = 4) & " руб.\n")
  # Сохраняем результат и текущее время (для кеширования)
  data = result
  lastTime = getTime()

module "💱 Курсы валют":
  command ["курс", "валюта", "валюты", "доллар", "евро", "фунт"]:
    usage = "курс - вывести курсы доллара, евро, фунта к рублю"
    answer await getData()
