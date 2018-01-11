# Очень рекомендуется include'ить этот файл во все плагины
import ../types  # типы данных
import ../vkapi  # VK API
import ../handlers  # Процедура handle
import ../utils  # Утилиты
import ../dsl  # Метапрограммирование для модулей 
import ../log  # Логгирование
# Импортируем кол-во обработанных сообщений и команд для модулей
from ../message import msgCount, cmdCount
import json  # Парсинг JSON
import strutils  # Строковые операции
import strformat # Строковая интерполяция
import asyncdispatch  # Асинхронность
import random  # Функции рандома
import strtabs  # Строковые таблицы
import tables  # Обработка модулей во время компиляции
import logging  # Логгирование
import os # Операции с файлами
# Рандомизируем вывод рандома (иначе он будет всегда одинаков в каждом запуске)
randomize()