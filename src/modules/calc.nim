include base
import mathexpr

let e = newEvaluator()

module "📊 Калькулятор":
  command ["калькулятор", "посчитай", "calc", "посчитать"]:
    usage = "калькулятор <выражение> - посчитать математическое выражение"
    if text == "":
      answer usage
      return
    let data = try:
      echo(e.eval(text))
    except:
      answer "Я не смог это сосчитать :("
      return
    # Если число целое - округляем
    let res = if float(int(data)) == data: $int(data) else: $data
    answer &"{text} = {res}"