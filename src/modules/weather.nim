include base
import httpclient, strutils, times, math, unicode

const
  ForecastUrlFormat = "http://api.openweathermap.org/data/2.5/forecast/daily?APPID=$1&lang=ru&q=$2&cnt=$3"

  ResultFormat = """$1:
    $2
    Температура: $3 °C
    Влажность: $4%
    Облачность: $5%
    Скорость ветра: $6 м/с""".unindent

  TextToDays = {
    "через неделю": 8, "послезавтра": 2, "через 1 день": 2,
    "через 5 дней": 6, "через 6 дней": 7, "через день": 2,
    "через 2 дня": 3, "через 3 дня": 4, "через 4 дня": 5,
    "завтра": 1
  }.toOrderedTable
              
var key = ""

module "🌦 Погода":
  startConfig:
    key = config.getString("key")
  
  command "погода":
    usage = "погода <город> <время> - узнать погоду, например `погода в Москве через неделю`"
    let 
      client = newAsyncHttpClient()
    var
      city = "Москва"
      days = 0
      url: string
    if text.len > 0:
      var data = text
      # Проходимся по всем возможным значениям
      for k, v in TextToDays.pairs:
        if k in args:
          data = data.replace(k, "")
          days = v
      # Находим город, который отправил пользователь
      let possibleCity = data.multiReplace({" в ": "", " в": "", "в ": ""})
      if possibleCity != "":
        city = unicode.toLower(possibleCity)
    # Формируем URL
    url = ForecastUrlFormat % [key, city, $(days+1)]
    let resp = await client.get(url)
    # Если сервер не нашёл этот город
    if resp.code != HttpCode(200):
      answer "Информацию по заданному городу получить не удалось :("
      return
    let
      # День - последний элемент из массива
      day = parseJson(await resp.body)["list"].getElems[^1]
      # Конвертируем температуру по Фаренгейту в Цельсии, 
      # округляем и переводим в int
      temp = $(round(day["temp"]["day"].getFloat() - 273))
      # Влажность
      humidity = $round(day["humidity"].getFloat())
      # Описание погоды с большой буквы в верхнем регистре
      desc = unicode.capitalize(
        day["weather"].getElems()[0]["description"].getStr()
      )
      # Получаем скорость ветра, округляем и переводим в int
      wind = $round(day["speed"].getFloat())
      # Получаем облачность, округляем и переводим в int
      cloud = $round(day["clouds"].getFloat(0))
      # Получаем timestamp
      date = day["dt"].getBiggestInt()
      # Конвертируем timestamp в наш формат
      time = fromUnix(date).local().format("d'.'MM'.'yyyy")
    # Отвечаем
    answer ResultFormat % [time, desc, temp, humidity, cloud, wind]

