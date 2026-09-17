#!/usr/bin/env python3
# =============================================================================
# patch3_translate_diagnostics.py
# СЯзык — перевод диагностических сообщений Clang 23.x
# =============================================================================
# Скрипт находит все Diagnostic*Kinds.td файлы, извлекает сообщения об
# ошибках/предупреждениях/примечаниях, защищает форматные спецификаторы
# (%0, %select{}0, %plural{}0, %diff{}0 и т.д.), применяет словарь
# перевода и восстанавливает спецификаторы.
#
# Использование:
#   python3 patch3_translate_diagnostics.py --apply    — применить к исходникам
#   python3 patch3_translate_diagnostics.py --output patch.diff — сгенерировать diff
#   python3 patch3_translate_diagnostics.py --report   — показать статистику
# =============================================================================

import os
import re
import sys
import argparse
import difflib
from pathlib import Path

# ─────────────────────────────────────────────────────────────────────────────
# Словарь перевода: (английский_термин, русский_перевод)
# Порядок важен: длинные фразы идут раньше коротких слов, чтобы избежать
# частичных замен (например, "type" не должен заменяться внутри "prototype").
# ─────────────────────────────────────────────────────────────────────────────

TRANSLATIONS = [
    # ── Длинные фразы (идут первыми) ──────────────────────────────────────────
    ("does not exist",            "не существует"),
    ("is not declared",           "не объявлен"),
    ("is not defined",             "не определён"),
    ("is not allowed",             "не разрешено"),
    ("is not supported",           "не поддерживается"),
    ("has not been declared",      "не был объявлен"),
    ("has not been defined",       "не был определён"),
    ("was not declared",           "не был объявлен"),
    ("was not defined",            "не был определён"),
    ("no member named",            "нет члена с именем"),
    ("no matching",                "нет подходящего"),
    ("no viable",                  "нет жизнеспособного"),
    ("cannot be used",             "нельзя использовать"),
    ("cannot be overloaded",       "нельзя перегрузить"),
    ("cannot be used as",          "нельзя использовать как"),
    ("cannot initialize",          "нельзя инициализировать"),
    ("cannot be applied to",       "нельзя применить к"),
    ("cannot be a member of",      "не может быть членом"),
    ("cannot be converted to",     "нельзя преобразовать в"),
    ("is not a member of",         "не является членом"),
    ("is not a class or namespace", "не является классом или пространством имён"),
    ("is not a class, struct, or union", "не является классом, структурой или объединением"),
    ("is not a function",          "не является функцией"),
    ("is not a type",              "не является типом"),
    ("is not an object",           "не является объектом"),
    ("is not a template",          "не является шаблоном"),
    ("is not a namespace",         "не является пространством имён"),
    ("is not a variable",          "не является переменной"),
    ("is not a constant",          "не является константой"),
    ("is not a constant expression", "не является константным выражением"),
    ("must be a",                  "должно быть"),
    ("must be an",                 "должно быть"),
    ("must have",                  "должно иметь"),
    ("must be declared",           "должно быть объявлено"),
    ("must be defined",            "должно быть определено"),
    ("must return",                "должно возвращать"),
    ("has already been declared",  "уже объявлен"),
    ("has already been defined",   "уже определён"),
    ("has already been initialized","уже инициализирован"),
    ("redefinition of",            "переопределение"),
    ("redeclaration of",           "переобъявление"),
    ("use of undeclared identifier","использование необъявленного идентификатора"),
    ("unknown type name",          "неизвестное имя типа"),
    ("unknown attribute",          "неизвестный атрибут"),
    ("unknown directive",          "неизвестная директива"),
    ("unknown pragma",             "неизвестная прагма"),
    ("unknown option",             "неизвестная опция"),
    ("incomplete type",            "неполный тип"),
    ("incomplete result type",    "неполный тип результата"),
    ("incomplete element type",    "неполный тип элемента"),
    ("incomplete object type",    "неполный тип объекта"),
    ("invalid operand",            "недопустимый операнд"),
    ("invalid argument",           "недопустимый аргумент"),
    ("invalid conversion",         "недопустимое преобразование"),
    ("invalid use of",             "недопустимое использование"),
    ("invalid declaration",        "недопустимое объявление"),
    ("invalid expression",         "недопустимое выражение"),
    ("invalid initializer",        "недопустимый инициализатор"),
    ("invalid type",               "недопустимый тип"),
    ("invalid operator",           "недопустимый оператор"),
    ("invalid specifier",          "недопустимый спецификатор"),
    ("invalid storage class",      "недопустимый класс хранения"),
    ("invalid token",              "недопустимый токен"),
    ("implicit conversion",        "неявное преобразование"),
    ("narrowing conversion",       "сужающее преобразование"),
    ("implicit declaration",       "неявное объявление"),
    ("implicit conversion from",   "неявное преобразование из"),
    ("expected expression",        "ожидается выражение"),
    ("expected identifier",        "ожидается идентификатор"),
    ("expected type",              "ожидается тип"),
    ("expected statement",         "ожидается оператор"),
    ("expected declaration",       "ожидается объявление"),
    ("expected function body",     "ожидается тело функции"),
    ("expected parameter",         "ожидается параметр"),
    ("expected member name",       "ожидается имя члена"),
    ("expected namespace name",    "ожидается имя пространства имён"),
    ("expected class name",        "ожидается имя класса"),
    ("expected base class",        "ожидается базовый класс"),
    ("expected initializer",       "ожидается инициализатор"),
    ("expected string",            "ожидается строка"),
    ("expected constant expression","ожидается константное выражение"),
    ("expected semicolon",         "ожидается точка с запятой"),
    ("return type",                "тип возврата"),
    ("base class",                 "базовый класс"),
    ("base type",                  "базовый тип"),
    ("derived class",              "производный класс"),
    ("derived type",               "производный тип"),
    ("return value",               "возвращаемое значение"),
    ("return statement",           "оператор возврата"),
    ("break statement",            "оператор прерывания"),
    ("continue statement",         "оператор продолжения"),
    ("while loop",                 "цикл пока"),
    ("for loop",                   "цикл для"),
    ("do-while loop",              "цикл делать-пока"),
    ("switch statement",           "оператор переключатель"),
    ("case statement",             "оператор выбора"),
    ("default statement",          "оператор умолчание"),
    ("if statement",               "оператор если"),
    ("else statement",             "оператор иначе"),
    ("goto statement",             "оператор перехода"),
    ("label statement",            "оператор метки"),
    ("null pointer",               "нулевой указатель"),
    ("null pointer constant",      "нулевая указательная константа"),
    ("null pointer value",         "нулевое значение указателя"),
    ("null character",             "нулевой символ"),
    ("forward declaration",        "предварительное объявление"),
    ("function call",              "вызов функции"),
    ("function definition",        "определение функции"),
    ("function declaration",       "объявление функции"),
    ("function prototype",         "прототип функции"),
    ("function template",          "шаблон функции"),
    ("function pointer",           "указатель на функцию"),
    ("function type",              "тип функции"),
    ("function return type",       "тип возврата функции"),
    ("member function",            "функция-член"),
    ("member access",              "доступ к члену"),
    ("member name",                "имя члена"),
    ("member pointer",             "указатель на член"),
    ("data member",                "член-данное"),
    ("static member",              "статический член"),
    ("static data member",         "статический член-данное"),
    ("static member function",     "статическая функция-член"),
    ("non-static member",          "нестатический член"),
    ("non-static data member",     "нестатический член-данное"),
    ("virtual function",           "виртуальная функция"),
    ("virtual base class",         "виртуальный базовый класс"),
    ("virtual member function",    "виртуальная функция-член"),
    ("pure virtual function",      "чистая виртуальная функция"),
    ("inline function",           "встроенная функция"),
    ("inline variable",            "встроенная переменная"),
    ("constructor",                "конструктор"),
    ("destructor",                 "деструктор"),
    ("copy constructor",          "конструктор копирования"),
    ("move constructor",          "конструктор перемещения"),
    ("copy assignment",           "копирующее присваивание"),
    ("move assignment",           "перемещающее присваивание"),
    ("default constructor",        "конструктор по умолчанию"),
    ("overloaded function",        "перегруженная функция"),
    ("overloaded operator",        "перегруженный оператор"),
    ("overloaded member function","перегруженная функция-член"),
    ("overload resolution",       "разрешение перегрузки"),
    ("ambiguous",                  "неоднозначный"),
    ("ambiguity",                  "неоднозначность"),
    ("inherited",                  "унаследованный"),
    ("inheritance",                "наследование"),
    ("multiple inheritance",       "множественное наследование"),
    ("virtual inheritance",       "виртуальное наследование"),
    ("namespace",                  "пространство имён"),
    ("nested namespace",           "вложенное пространство имён"),
    ("unnamed namespace",          "безымянное пространство имён"),
    ("inline namespace",           "встроенное пространство имён"),
    ("template argument",          "шаблонный аргумент"),
    ("template parameter",         "шаблонный параметр"),
    ("template declaration",       "шаблонное объявление"),
    ("template definition",        "шаблонное определение"),
    ("template instantiation",     "создание экземпляра шаблона"),
    ("template specialization",    "специализация шаблона"),
    ("explicit specialization",    "явная специализация"),
    ("partial specialization",     "частичная специализация"),
    ("implicit specialization",    "неявная специализация"),
    ("default argument",           "аргумент по умолчанию"),
    ("default value",              "значение по умолчанию"),
    ("default initializer",        "инициализатор по умолчанию"),
    ("default member initializer","инициализатор члена по умолчанию"),
    ("default label",              "метка по умолчанию"),
    ("default case",               "случай по умолчанию"),
    ("friend declaration",         "объявление друга"),
    ("friend function",            "функция-друг"),
    ("friend class",               "класс-друг"),
    ("access specifier",           "спецификатор доступа"),
    ("access control",             "контроль доступа"),
    ("access declaration",         "объявление доступа"),
    ("private access",             "закрытый доступ"),
    ("protected access",           "защищённый доступ"),
    ("public access",              "открытый доступ"),
    ("private member",             "закрытый член"),
    ("protected member",           "защищённый член"),
    ("public member",              "открытый член"),
    ("private base class",         "закрытый базовый класс"),
    ("protected base class",       "защищённый базовый класс"),
    ("public base class",          "открытый базовый класс"),
    ("private inheritance",        "закрытое наследование"),
    ("protected inheritance",     "защищённое наследование"),
    ("public inheritance",         "открытое наследование"),
    ("type qualifier",             "квалификатор типа"),
    ("type specifier",             "спецификатор типа"),
    ("type definition",            "определение типа"),
    ("type declaration",           "объявление типа"),
    ("type alias",                 "псевдоним типа"),
    ("type name",                  "имя типа"),
    ("type identifier",            "идентификатор типа"),
    ("type parameter",             "параметр типа"),
    ("type argument",              "аргумент типа"),
    ("type mismatch",              "несоответствие типов"),
    ("type conversion",           "преобразование типа"),
    ("type cast",                  "приведение типа"),
    ("cast expression",            "выражение приведения"),
    ("type trait",                 "свойство типа"),
    ("type constraint",            "ограничение типа"),
    ("type inference",             "вывод типа"),
    ("deduction",                  "вывод"),
    ("deduction failed",           "вывод не удался"),
    ("deduction guide",            "направляющий вывод"),
    ("class template",             "шаблон класса"),
    ("class definition",           "определение класса"),
    ("class declaration",          "объявление класса"),
    ("class member",               "член класса"),
    ("class method",               "метод класса"),
    ("class type",                 "тип класса"),
    ("class scope",                "область видимости класса"),
    ("class name",                 "имя класса"),
    ("class identifier",           "идентификатор класса"),
    ("struct definition",         "определение структуры"),
    ("struct declaration",        "объявление структуры"),
    ("struct type",               "тип структуры"),
    ("struct name",               "имя структуры"),
    ("union type",                 "тип объединения"),
    ("union member",               "член объединения"),
    ("enum type",                  "тип перечисления"),
    ("enum value",                 "значение перечисления"),
    ("enum constant",              "константа перечисления"),
    ("enumerator",                 "перечислитель"),
    ("enumeration",                "перечисление"),
    ("enumeration type",           "тип перечисления"),
    ("scoped enumeration",        "областное перечисление"),
    ("unscoped enumeration",      "необластное перечисление"),
    ("lambda expression",          "лямбда-выражение"),
    ("lambda function",            "лямбда-функция"),
    ("lambda capture",            "захват лямбды"),
    ("capture default",           "захват по умолчанию"),
    ("capture list",              "список захвата"),
    ("capture by value",           "захват по значению"),
    ("capture by reference",      "захват по ссылке"),
    ("variable declaration",      "объявление переменной"),
    ("variable definition",       "определение переменной"),
    ("variable type",             "тип переменной"),
    ("variable name",             "имя переменной"),
    ("variable length array",     "массив переменной длины"),
    ("local variable",            "локальная переменная"),
    ("global variable",           "глобальная переменная"),
    ("static local variable",     "статическая локальная переменная"),
    ("static variable",           "статическая переменная"),
    ("instance variable",         "переменная экземпляра"),
    ("automatic variable",        "автоматическая переменная"),
    ("register variable",         "регистровая переменная"),
    ("external variable",         "внешняя переменная"),
    ("pointer type",              "тип указателя"),
    ("pointer to",                "указатель на"),
    ("pointer to member",         "указатель на член"),
    ("pointer to function",       "указатель на функцию"),
    ("pointer arithmetic",       "адресная арифметика"),
    ("pointer value",             "значение указателя"),
    ("pointer comparison",        "сравнение указателей"),
    ("pointer mismatch",          "несоответствие указателей"),
    ("reference type",            "ссылочный тип"),
    ("reference to",              "ссылка на"),
    ("lvalue reference",         "lvalue-ссылка"),
    ("rvalue reference",         "rvalue-ссылка"),
    ("forwarding reference",     "пересылающая ссылка"),
    ("universal reference",      "универсальная ссылка"),
    ("array type",                "тип массива"),
    ("array of",                  "массив из"),
    ("array element",            "элемент массива"),
    ("array index",              "индекс массива"),
    ("array size",               "размер массива"),
    ("array bounds",             "границы массива"),
    ("array subscript",          "индексация массива"),
    ("out of bounds",            "выход за границы"),
    ("array bound",              "граница массива"),
    ("array decay",              "деградация массива"),
    ("multi-dimensional array",  "многомерный массив"),
    ("aggregate type",           "агрегатный тип"),
    ("aggregate initialization", "агрегатная инициализация"),
    ("aggregate",                "агрегат"),
    ("trivial type",             "тривиальный тип"),
    ("trivially copyable",       "тривиально копируемый"),
    ("trivially destructible",   "тривиально деструктируемый"),
    ("literal type",             "литеральный тип"),
    ("standard layout type",     "тип со стандартной раскладкой"),
    ("scalar type",              "скалярный тип"),
    ("arithmetic type",          "арифметический тип"),
    ("integral type",            "целочисленный тип"),
    ("floating point type",      "плавающий тип"),
    ("fundamental type",         "фундаментальный тип"),
    ("compound type",            "составной тип"),
    ("object type",              "объектный тип"),
    ("complete type",            "полный тип"),
    ("abstract class",           "абстрактный класс"),
    ("abstract type",            "абстрактный тип"),
    ("concrete class",           "конкретный класс"),
    ("sealed class",             "запечатанный класс"),
    ("final class",              "финальный класс"),
    ("virtual base",             "виртуальная база"),
    ("direct base class",        "прямой базовый класс"),
    ("indirect base class",      "косвенный базовый класс"),
    ("parameter pack",           "пакет параметров"),
    ("pack expansion",           "расширение пакета"),
    ("pack",                     "пакет"),
    ("variadic",                 "вариативный"),
    ("variadic template",        "вариативный шаблон"),
    ("variadic function",        "вариативная функция"),
    ("variadic macro",           "вариативный макрос"),
    ("constant expression",      "константное выражение"),
    ("constant value",           "константное значение"),
    ("constant initializer",     "константный инициализатор"),
    ("compile-time constant",    "константа времени компиляции"),
    ("runtime",                  "время выполнения"),
    ("compile-time",             "время компиляции"),
    ("linkage specification",    "спецификация компоновки"),
    ("external linkage",         "внешняя компоновка"),
    ("internal linkage",         "внутренняя компоновка"),
    ("no linkage",               "без компоновки"),
    ("language linkage",         "языковая компоновка"),
    ("storage class",            "класс хранения"),
    ("storage duration",         "длительность хранения"),
    ("automatic storage",        "автоматическое хранение"),
    ("static storage",           "статическое хранение"),
    ("dynamic storage",          "динамическое хранение"),
    ("thread storage",           "потоковое хранение"),
    ("lifetime",                 "время жизни"),
    ("object lifetime",          "время жизни объекта"),
    ("storage class specifier",  "спецификатор класса хранения"),
    ("calling convention",       "соглашение о вызове"),
    ("mangled name",             "искажённое имя"),
    ("name mangling",            "искажение имён"),
    ("name lookup",              "поиск имени"),
    ("name hiding",              "сокрытие имени"),
    ("name injection",           "внедрение имени"),
    ("qualified name",           "квалифицированное имя"),
    ("unqualified name",         "неквалифицированное имя"),
    ("qualified type",           "квалифицированный тип"),
    ("unqualified type",         "неквалифицированный тип"),
    ("dependent name",           "зависимое имя"),
    ("dependent type",           "зависимый тип"),
    ("dependent scope",          "зависимая область"),
    ("dependent expression",     "зависимое выражение"),
    ("dependent template",       "зависимый шаблон"),
    ("typename",                 "имя типа"),
    ("typename specifier",       "спецификатор имени типа"),
    ("elaborated type",          "развёрнутый тип"),
    ("elaborated type specifier","развёрнутый спецификатор типа"),
    ("using declaration",        "объявление using"),
    ("using directive",          "директива using"),
    ("using enum",              "using-перечисление"),
    ("alias declaration",       "объявление псевдонима"),
    ("alias template",          "шаблон-псевдоним"),
    ("namespace alias",         "псевдоним пространства имён"),
    ("type alias declaration",  "объявление псевдонима типа"),
    ("attribute",               "атрибут"),
    ("attribute specifier",     "спецификатор атрибута"),
    ("attribute argument",      "аргумент атрибута"),
    ("attribute list",          "список атрибутов"),
    ("deprecated",              "устаревший"),
    ("deprecated attribute",   "устаревший атрибут"),
    ("fallthrough",            "провал"),
    ("nodiscard",              "не игнорировать"),
    ("maybe_unused",           "возможно неиспользуемый"),
    ("likely",                 "вероятно"),
    ("unlikely",               "маловероятно"),
    ("no_unique_address",      "без уникального адреса"),
    ("carries_dependency",     "несёт зависимость"),
    ("noreturn",               "без возврата"),
    ("unused",                 "неиспользуемый"),
    ("overflow",               "переполнение"),
    ("underflow",              "антипереполнение"),
    ("integer overflow",       "целочисленное переполнение"),
    ("signed integer overflow","переполнение знакового целого"),
    ("unsigned integer overflow","переполнение беззнакового целого"),
    ("buffer overflow",        "переполнение буфера"),
    ("stack overflow",         "переполнение стека"),
    ("overflow in",            "переполнение в"),
    ("division by zero",       "деление на ноль"),
    ("modulo by zero",         "остаток от деления на ноль"),
    ("shift count",            "счётчик сдвига"),
    ("negative shift count",  "отрицательный счётчик сдвига"),
    ("shift expression",       "выражение сдвига"),
    ("bitwise",                "побитовое"),
    ("bitwise shift",          "побитовый сдвиг"),
    ("bitwise AND",            "побитовое И"),
    ("bitwise OR",             "побитовое ИЛИ"),
    ("bitwise XOR",            "побитовое исключающее ИЛИ"),
    ("bitwise NOT",            "побитовое НЕ"),
    ("bitwise complement",     "побитовое дополнение"),
    ("binary expression",      "бинарное выражение"),
    ("unary expression",       "унарное выражение"),
    ("conditional expression", "условное выражение"),
    ("assignment expression",  "выражение присваивания"),
    ("compound assignment",   "составное присваивание"),
    ("comma expression",       "выражение-запятая"),
    ("initializer list",       "список инициализации"),
    ("initializer clause",     "конструкция инициализации"),
    ("braced-init-list",       "список-в-фигурных-скобках"),
    ("designated initializer", "инициализатор с меткой"),
    ("designator",             "метка инициализатора"),
    ("default initializer",    "инициализатор по умолчанию"),
    ("value initialization",   "инициализация значением"),
    ("zero initialization",   "нулевая инициализация"),
    ("direct initialization", "прямая инициализация"),
    ("copy initialization",   "копирующая инициализация"),
    ("reference initialization","инициализация ссылки"),
    ("list initialization",    "списочная инициализация"),
    ("diagnostic",             "диагностика"),
    ("diagnostic message",    "диагностическое сообщение"),
    ("diagnostic pragma",      "диагностическая прагма"),
    ("diagnostic flag",        "диагностический флаг"),
    ("diagnostic category",    "категория диагностики"),
    ("error",                  "ошибка"),
    ("warning",                "предупреждение"),
    ("note",                   "примечание"),
    ("remark",                 "замечание"),
    ("fatal error",            "фатальная ошибка"),
    ("extension",              "расширение"),
    ("pedantic",               "педантичный"),
    ("suppressed",             "подавлено"),
    ("ignored",                "игнорируется"),
    ("enabled",                "включён"),
    ("disabled",               "выключен"),

    # ── Квалификаторы ─────────────────────────────────────────────────────────
    ("const",                  "константный"),
    ("volatile",               "изменчивый"),
    ("restrict",               "ограниченный"),
    ("mutable",                "изменяемый"),
    ("constexpr",              "константное_выражение"),
    ("consteval",              "конст_вычисление"),
    ("constinit",              "конст_инициализация"),
    ("static",                 "статический"),
    ("extern",                 "внешний"),
    ("inline",                 "встроенный"),
    ("virtual",                "виртуальный"),
    ("explicit",               "явный"),
    ("register",               "регистровый"),
    ("thread_local",           "поток_локальный"),

    # ── Базовые термины (идут последними, короткие слова) ───────────────────────
    ("function",               "функция"),
    ("variable",               "переменная"),
    ("declaration",            "объявление"),
    ("definition",            "определение"),
    ("expression",            "выражение"),
    ("statement",             "оператор"),
    ("identifier",            "идентификатор"),
    ("parameter",             "параметр"),
    ("argument",              "аргумент"),
    ("template",              "шаблон"),
    ("class",                 "класс"),
    ("struct",                "структура"),
    ("union",                 "объединение"),
    ("enum",                  "перечисление"),
    ("operator",              "оператор"),
    ("operand",               "операнд"),
    ("pointer",               "указатель"),
    ("reference",             "ссылка"),
    ("array",                 "массив"),
    ("string",                "строка"),
    ("character",             "символ"),
    ("integer",               "целое"),
    ("floating",              "плавающее"),
    ("boolean",               "логическое"),
    ("constant",              "константа"),
    ("label",                 "метка"),
    ("macro",                 "макрос"),
    ("token",                 "токен"),
    ("scope",                 "область видимости"),
    ("name",                  "имя"),
    ("value",                 "значение"),
    ("member",                "член"),
    ("method",                "метод"),
    ("object",                "объект"),
    ("property",              "свойство"),
    ("field",                 "поле"),
    ("type",                  "тип"),

    # ── Связки ─────────────────────────────────────────────────────────────────
    ("before",                 "перед"),
    ("after",                  "после"),
    ("with",                   "с"),
    ("from",                   "из"),
    ("into",                   "в"),
    ("within",                 "внутри"),
    ("without",               "без"),
    ("inside",                "внутри"),
    ("outside",               "снаружи"),
    ("through",               "через"),
    ("during",                "во время"),
    ("instead of",            "вместо"),
    ("because of",            "из-за"),
    ("due to",                "вследствие"),
    ("according to",          "согласно"),
    ("already",               "уже"),
    ("still",                 "всё ещё"),
    ("never",                 "никогда"),
    ("always",                "всегда"),
    ("again",                 "снова"),
    ("previously",            "ранее"),
    ("currently",             "в настоящее время"),
    ("originally",            "изначально"),
    ("implicitly",            "неявно"),
    ("explicitly",            "явно"),
    ("recursively",           "рекурсивно"),
    ("repeatedly",            "многократно"),
    ("redefinition",          "переопределение"),
    ("redeclaration",         "переобъявление"),
    ("undefined",             "неопределён"),
    ("undeclared",            "необъявлен"),
    ("uninitialized",         "неинициализирован"),
    ("unreachable",           "недостижимый"),
    ("unused",                "неиспользуемый"),
    ("invalid",               "недопустимый"),
    ("valid",                 "допустимый"),
    ("not",                   "не"),
    ("and",                   "и"),
    ("or",                    "или"),
]


# ─────────────────────────────────────────────────────────────────────────────
# Защита и восстановление форматных спецификаторов
# ─────────────────────────────────────────────────────────────────────────────

def protect_specifiers(text):
    """Заменяет форматные спецификаторы на плейсхолдеры перед переводом."""
    # Стандартные %spec{...}N
    text = re.sub(r'%(\d+)', lambda m: f'\x00ARG{m.group(1)}\x00', text)
    text = re.sub(r'%select\{([^}]*)\}(\d+)', lambda m: f'\x00SEL{m.group(2)}\x00', text)
    text = re.sub(r'%plural\{([^}]*)\}(\d+)', lambda m: f'\x00PLU{m.group(2)}\x00', text)
    text = re.sub(r'%diff\{([^}]*)\}(\d+)', lambda m: f'\x00DIF{m.group(2)}\x00', text)
    text = re.sub(r'%([sd])', lambda m: f'\x00SIM{m.group(1)}\x00', text)
    text = re.sub(r'%(q|ord|adj|sub|obj|diff|fixithint|fpeditkind)', lambda m: f'\x00SPL{m.group(1)}\x00', text)
    
    # Нестандартные спецификаторы Clang: %enum_select, %sub_type, и т.п.
    # Правильная регулярка: % + буквы + (_ + буквы)+
    text = re.sub(r'%[a-zA-Z]+(?:_[a-zA-Z]+)+', lambda m: f'\x00CUS{m.group(0)}\x00', text)
    
    return text

def restore_specifiers(text):
    """Восстанавливает форматные спецификаторы после перевода."""
    text = re.sub(r'\x00ARG(\d+)\x00', r'%\1', text)
    text = re.sub(r'\x00SEL(\d+)\x00', r'%select{...}\1', text)
    text = re.sub(r'\x00PLU(\d+)\x00', r'%plural{...}\1', text)
    text = re.sub(r'\x00DIF(\d+)\x00', r'%diff{...}\1', text)
    text = re.sub(r'\x00SIM([sd])\x00', r'%\1', text)
    text = re.sub(r'\x00SPL(\w+)\x00', r'%\1', text)
    # Восстанавливаем нестандартные спецификаторы (включая знак %)
    text = re.sub(r'\x00CUS(%[a-zA-Z]+(?:_[a-zA-Z]+)+)\x00', r'\1', text)
    return text


# ─────────────────────────────────────────────────────────────────────────────
# Применение перевода к одному сообщению
# ─────────────────────────────────────────────────────────────────────────────

def translate_message(msg):
    """Переводит одно диагностическое сообщение."""
    protected = protect_specifiers(msg)
    for eng, rus in TRANSLATIONS:
        if len(eng) > 3:
            protected = re.sub(re.escape(eng), rus, protected, flags=re.IGNORECASE)
        else:
            protected = re.sub(r'\b' + re.escape(eng) + r'\b', rus, protected, flags=re.IGNORECASE)
    return restore_specifiers(protected)


# ─────────────────────────────────────────────────────────────────────────────
# Обработка .td файлов
# ─────────────────────────────────────────────────────────────────────────────

def find_diag_files(base_dir="."):
    """Находит все Diagnostic*Kinds.td файлы."""
    base = Path(base_dir)
    patterns = [
        "clang/include/clang/Basic/Diagnostic*Kinds.td",
        "clang/include/clang/Basic/Diagnostics*.td",
    ]
    files = set()
    for pat in patterns:
        files.update(base.glob(pat))
    return sorted(files)

def process_file(filepath, apply=False):
    """Обрабатывает один .td файл. Возвращает (оригинал, изменённый) или None."""
    with open(filepath, "r", encoding="utf-8") as f:
        content = f.read()

    original = content

    diag_pattern = re.compile(
        r'((?:Error|Warning|Note|Remark|Extension|ExtWarn|Frontend|Fatal)\s*<\s*")([^"]+)(")'
    )

    def replacer(m):
        prefix = m.group(1)
        message = m.group(2)
        suffix = m.group(3)
        translated = translate_message(message)
        return f'{prefix}{translated}{suffix}'

    content = diag_pattern.sub(replacer, content)

    if content == original:
        return None

    if apply:
        with open(filepath, "w", encoding="utf-8") as f:
            f.write(content)

    return (original, content)

def generate_diff(filepath, original, modified):
    """Генерирует unified diff для файла."""
    return difflib.unified_diff(
        original.splitlines(keepends=True),
        modified.splitlines(keepends=True),
        fromfile=str(filepath),
        tofile=str(filepath),
        lineterm=""
    )

def count_messages(filepath):
    """Считает сообщения и сколько из них будут переведены."""
    with open(filepath, "r", encoding="utf-8") as f:
        content = f.read()

    diag_pattern = re.compile(
        r'(?:Error|Warning|Note|Remark|Extension|ExtWarn|Frontend|Fatal)\s*<\s*"([^"]+)"'
    )

    total = 0
    would_translate = 0

    for m in diag_pattern.finditer(content):
        msg = m.group(1)
        total += 1
        translated = translate_message(msg)
        if translated != msg:
            would_translate += 1

    return total, would_translate


# ─────────────────────────────────────────────────────────────────────────────
# Главная функция
# ─────────────────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(
        description="СЯзык — перевод диагностических сообщений Clang 23.x",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Примеры:
  python3 patch3_translate_diagnostics.py --report
  python3 patch3_translate_diagnostics.py --apply
  python3 patch3_translate_diagnostics.py --output sclang_diag.patch
        """
    )
    parser.add_argument("--apply", action="store_true",
                        help="Применить переводы к файлам исходников")
    parser.add_argument("--output", type=str, default=None,
                        help="Сохранить diff-патч в указанный файл")
    parser.add_argument("--report", action="store_true",
                        help="Показать статистику перевода")
    parser.add_argument("--dir", type=str, default=".",
                        help="Базовая директория llvm-project (по умолчанию: .)")

    args = parser.parse_args()

    if not args.apply and not args.output and not args.report:
        parser.print_help()
        sys.exit(1)

    files = find_diag_files(args.dir)

    if not files:
        print("ОШИБКА: Не найдены Diagnostic*Kinds.td файлы.")
        print("Запускайте из корня llvm-project или укажите --dir")
        sys.exit(1)

    print(f"Найдено {len(files)} файлов диагностики:")
    for f in files:
        print(f"  {f}")

    # ── Режим отчёта ──
    if args.report:
        print("\n" + "=" * 70)
        print("Статистика перевода")
        print("=" * 70)
        grand_total = 0
        grand_translated = 0

        for filepath in files:
            total, translated = count_messages(filepath)
            grand_total += total
            grand_translated += translated
            pct = (translated / total * 100) if total > 0 else 0
            print(f"  {filepath.name:50s} {translated:4d}/{total:4d} ({pct:5.1f}%)")

        pct = (grand_translated / grand_total * 100) if grand_total > 0 else 0
        print("-" * 70)
        print(f"  {'ИТОГО':50s} {grand_translated:4d}/{grand_total:4d} ({pct:5.1f}%)")
        print("=" * 70)
        return

    # ── Режим применения ──
    if args.apply:
        print("\nПрименение переводов...")
        changed = 0
        for filepath in files:
            result = process_file(filepath, apply=True)
            if result is not None:
                changed += 1
                print(f"  Изменён: {filepath}")
        print(f"\nГотово. Изменено файлов: {changed} из {len(files)}")
        return

    # ── Режим генерации патча ──
    if args.output:
        print(f"\nГенерация diff-патча: {args.output}")
        with open(args.output, "w", encoding="utf-8") as out:
            out.write("# СЯзык — патч перевода диагностических сообщений Clang 23.x\n")
            out.write("# Автоматически сгенерирован patch3_translate_diagnostics.py\n\n")
            changed = 0
            for filepath in files:
                result = process_file(filepath, apply=False)
                if result is not None:
                    original, modified = result
                    diff = generate_diff(filepath, original, modified)
                    diff_text = "".join(diff)
                    if diff_text:
                        out.write(diff_text)
                        out.write("\n")
                        changed += 1
                        print(f"  В патч добавлен: {filepath}")
        print(f"\nГотово. В патч включено файлов: {changed} из {len(files)}")
        print(f"Патч сохранён: {args.output}")
        return


if __name__ == "__main__":
    main()
