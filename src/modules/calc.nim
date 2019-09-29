# Использует C библиотеку tinyexpr для обработки 
# мат. выражений - https://github.com/codeplea/tinyexpr/
include base
import mathexpr

const 
  FailMsg = "Я не смог это сосчитать :("


let e = newEvaluator()

module "📊 Калькулятор":
  command "калькулятор", "посчитай", "calc", "посчитать":
    usage = "калькулятор <выражение> - посчитать математическое выражение"
    if text == "":
      answer usage
      return
    var data: float
    try: data = e.eval(text)
    except:
      answer FailMsg
      return
    # Если число целое - округляем
    let res = if float(int(data)) == data: $int(data) else: $data
    answer &"{text} = {res}"