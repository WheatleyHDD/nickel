# Очень рекомендуется include'ить этот файл во все плагины
import ../types  # Типы данных
import ../vkapi  # VK API
import ../handlers  # Процедура handle
import ../utils  # Утилиты
import ../dsl  # Метапрограммирование для модулей
import ../log  # Логгирование
# Импортируем переменные с кол-вом обработанных сообщений и команд
from ../message import msgCount, cmdCount
import json
import parsetoml # Конфигурация модулей
import strutils  # Строковые операции
import strformat # Строковая интерполяция
import asyncdispatch  # Асинхронность
import random  # Функции рандома
import strtabs  # Строковые таблицы
import tables  # Обработка модулей во время компиляции
import os # Операции с файлами
# Рандомизируем генератор чисел
randomize()