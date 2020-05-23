include base
import httpclient, encodings, streams, htmlparser, xmltree, random

const
  Answers = [
    "Башорг врать не станет!",
    "Сейчас будет смешно, зуб даю",
    "Шуточки заказывали?",
    "Со мной тоже такое бывало :)"
  ]
  
  JokesUrl = "http://bash.im/random"

proc getJoke(): Future[string] {.async.} =
  let
    client = newAsyncHttpClient()
    jokeRaw = (await client.getContent(JokesUrl)).convert("UTF-8", "CP1251")
    jokeHtml = parseHtml(newStringStream(jokeRaw))
  
  result = ""
  var goodElems = newSeq[XmlNode]()
  for elem in jokeHtml.findAll("div"):
    if elem.attr("class") != "text":
      # Нам нужны div'ы с классом "text"
      continue
    goodElems.add elem
  # Для каждого "ребёнка" случайной цитаты из все
  for child in sample(goodElems).items:
    case child.kind:
      of XmlNodeKind.xnText:
        result.add(child.innerText)
      of XmlNodeKind.xnElement:
        result.add("\n")
      else:
        discard


module "💯 Анекдоты":
  command ["пошути", "шуткани", "анекдот", "баш", "петросян"]:
    usage = "пошути - вывести случайную цитату c https://bash.im"
    let joke = await getJoke()
    # Если удалось получить анекдот
    if joke != "":
      answer &"{sample(Answers)}\n\n{joke}"
    else:
      answer "Извини, но у меня шутилка сломалась :("