#!/usr/bin/env bash
# =============================================================================
# patch1_rus_keywords.sh — Русские ключевые слова для Clang 23.x (СЯзык)
# =============================================================================
# Добавляет русские алиасы через механизм ALIAS в TokenKinds.def.
# Механизм ALIAS встроен в Clang: например, "__inline__" → inline.
# Скрипт идемпотентен: повторный запуск не дублирует записи.
#
# Использование:
#   cd llvm-project
#   bash ../.github/patches/patch1_rus_keywords.sh
# =============================================================================

set -e

TKD="clang/include/clang/Basic/TokenKinds.def"

if [ ! -f "$TKD" ]; then
    echo "ОШИБКА: $TKD не найден. Запускайте из корня llvm-project."
    exit 1
fi

# Проверка идемпотентности
if grep -q "СЯзык русские ключевые слова" "$TKD"; then
    echo "Русские ключевые слова уже добавлены. Пропуск."
    exit 0
fi

python3 << 'PYTHON_EOF'
import re

TKD = "clang/include/clang/Basic/TokenKinds.def"

with open(TKD, "r", encoding="utf-8") as f:
    content = f.read()

# Все русские алиасы: (русское_слово, английское_ключевое_слово, флаги)
# Флаги: KEYALL, KEYCXX, KEYCXX11, KEYCXX20, KEYC99, KEYOPENCLC, KEYALL|KEYNOOPENCL, и т.д.
ALIASES = [
    # ─── C (KEYALL) — 32 слова ──────────────────────────────────────────
    ("авто",           "auto",           "KEYALL"),
    ("прервать",       "break",          "KEYALL"),
    ("выбор",          "case",           "KEYALL"),
    ("символ",         "char",           "KEYALL"),
    ("конст",          "const",          "KEYALL"),
    ("продолжить",     "continue",       "KEYALL"),
    ("умолчание",      "default",        "KEYALL"),
    ("делать",         "do",             "KEYALL"),
    ("двойное",        "double",         "KEYALL"),
    ("иначе",          "else",           "KEYALL"),
    ("перечисление",   "enum",           "KEYALL"),
    ("внешний",        "extern",         "KEYALL"),
    ("плавающее",      "float",          "KEYALL"),
    ("для",            "for",            "KEYALL"),
    ("переход",        "goto",           "KEYALL"),
    ("если",           "if",             "KEYALL"),
    ("целое",          "int",            "KEYALL"),
    ("длинное",        "long",           "KEYALL"),
    ("регистр",        "register",       "KEYALL"),
    ("вернуть",        "return",         "KEYALL"),
    ("короткое",       "short",          "KEYALL"),
    ("знаковое",       "signed",         "KEYALL"),
    ("размер",         "sizeof",         "KEYALL"),
    ("статическое",    "static",         "KEYALL"),
    ("структура",      "struct",         "KEYALL"),
    ("переключатель",  "switch",         "KEYALL"),
    ("тип",            "typedef",        "KEYALL"),
    ("объединение",    "union",          "KEYALL"),
    ("беззнаковое",    "unsigned",       "KEYALL"),
    ("пусто",          "void",           "KEYALL"),
    ("изменчивое",     "volatile",       "KEYALL"),
    ("пока",           "while",          "KEYALL"),

    # ─── C11 (KEYALL) ──────────────────────────────────────────────────
    ("_Выравнивание",      "_Alignas",      "KEYALL"),
    ("_ВыравниваниеОф",    "_Alignof",      "KEYALL"),
    ("_Атомарное",         "_Atomic",       "KEYALL|KEYNOOPENCL"),
    ("_Логическое",        "_Bool",         "KEYNOCXX"),
    ("_Комплексное",       "_Complex",      "KEYALL"),
    ("_Обобщённое",        "_Generic",       "KEYALL"),
    ("_Мнимое",            "_Imaginary",    "KEYALL"),
    ("_Невозврат",         "_Noreturn",     "KEYALL"),

    # ─── C23 ────────────────────────────────────────────────────────────
    ("тип_от",             "typeof",       "KEYALL"),
    ("тип_от_без_квал",    "typeof_unqual", "KEYALL"),
    ("БитовоеЦелое",       "_BitInt",       "KEYALL"),

    # ─── C++ (KEYCXX) ──────────────────────────────────────────────────
    ("перехват",           "catch",         "KEYCXX"),
    ("класс",              "class",         "KEYCXX"),
    ("удалить",            "delete",        "KEYCXX"),
    ("друг",               "friend",        "KEYCXX"),
    ("изменяемое",         "mutable",       "KEYCXX"),
    ("пространство_имён",  "namespace",     "KEYCXX"),
    ("новый",              "new",           "KEYCXX"),
    ("оператор",           "operator",     "KEYCXX"),
    ("закрытый",           "private",       "KEYCXX"),
    ("защищённый",         "protected",     "KEYCXX"),
    ("открытый",           "public",        "KEYCXX"),
    ("реинт_приведение",   "reinterpret_cast", "KEYCXX"),
    ("стат_приведение",    "static_cast",   "KEYCXX"),
    ("шаблон",             "template",      "KEYCXX"),
    ("это",                "this",          "KEYCXX"),
    ("бросок",             "throw",         "KEYCXX"),
    ("истина",            "true",          "BOOLSUPPORT|KEYC23"),
    ("попытка",            "try",           "KEYCXX"),
    ("имя_типа",          "typename",      "KEYCXX"),
    ("ид_типа",           "typeid",        "KEYCXX"),
    ("использование",      "using",         "KEYCXX"),
    ("виртуальное",        "virtual",       "KEYCXX"),
    ("широкий_символ",     "wchar_t",       "WCHARSUPPORT"),
    ("явное",              "explicit",      "KEYCXX"),
    ("встроенное",         "inline",        "KEYCXX|KEYGNU"),
    ("ложь",              "false",         "BOOLSUPPORT|KEYC23"),
    ("дин_приведение",     "dynamic_cast",  "KEYCXX"),
    ("конст_приведение",   "const_cast",    "KEYCXX"),

    # ─── C++ альтернативные операторы ──────────────────────────────────
    ("и",                  "and",          "KEYCXX"),
    ("или",                "or",           "KEYCXX"),
    ("не",                 "not",          "KEYCXX"),
    ("битовое_и",          "bitand",       "KEYCXX"),
    ("битовое_или",        "bitor",        "KEYCXX"),
    ("дополнение",         "compl",        "KEYCXX"),
    ("искл_или",           "xor",          "KEYCXX"),
    ("и_равно",           "and_eq",       "KEYCXX"),
    ("или_равно",         "or_eq",        "KEYCXX"),
    ("не_равно",          "not_eq",       "KEYCXX"),
    ("искл_или_равно",    "xor_eq",       "KEYCXX"),

    # ─── C99 ────────────────────────────────────────────────────────────
    ("ограничение",        "restrict",     "0"),

    # ─── C++11 ──────────────────────────────────────────────────────────
    ("выравнивание",       "alignas",       "KEYC23"),
    ("выравнивание_оф",    "alignof",       "KEYC23"),
    ("символ16",          "char16_t",      "KEYNOMS18"),
    ("символ32",          "char32_t",      "KEYNOMS18"),
    ("конст_выражение",    "constexpr",     "KEYC23"),
    ("тип_выражения",      "decltype",      "0"),
    ("без_исключений",     "noexcept",      "0"),
    ("нулевой_указатель",  "nullptr",       "KEYC23"),
    ("стат_утверждение",   "static_assert", "KEYMSCOMPAT|KEYC23"),
    ("поток_локальный",    "thread_local",  "KEYC23"),

    # ─── C++20 корутины ─────────────────────────────────────────────────
    ("сопр_ожидание",      "co_await",     "KEYCXX"),
    ("сопр_возврат",       "co_return",    "KEYCXX"),
    ("сопр_доход",         "co_yield",     "KEYCXX"),

    # ─── C++20 модули ───────────────────────────────────────────────────
    ("модуль",             "module",       "KEYMODULES"),
    ("импорт_модуля",      "import",       "KEYMODULES"),

    # ─── C++20 ──────────────────────────────────────────────────────────
    ("конст_вычисление",   "consteval",    "KEYCXX20"),
    ("конст_инициализация","constinit",    "KEYCXX20"),

    # ─── C++20 концепты ─────────────────────────────────────────────────
    ("концепт",            "concept",      "KEYCXX20"),
    ("требует",           "requires",     "KEYCXX20"),

    # ─── GNU расширения ────────────────────────────────────────────────
    ("__атрибут",          "__attribute",  "KEYALL"),
    ("__выравнивание_оф",  "__alignof",     "KEYALL"),
    ("__ФУНКЦИЯ",          "__FUNCTION__", "KEYALL"),
    ("__КРАСИВАЯ_ФУНКЦИЯ", "__PRETTY_FUNCTION__", "KEYALL"),
    ("__авто_тип",         "__auto_type",  "KEYALL"),

    # ─── Type Traits (KEYCXX) ───────────────────────────────────────────
    ("__явл_классом",              "__is_class",                    "KEYCXX"),
    ("__явл_структурой",           "__is_struct",                   "KEYCXX"),
    ("__явл_объединением",         "__is_union",                    "KEYCXX"),
    ("__явл_перечислением",        "__is_enum",                      "KEYCXX"),
    ("__явл_базой_для",            "__is_base_of",                   "KEYCXX"),
    ("__явл_конвертируемым_в",     "__is_convertible_to",            "KEYCXX"),
    ("__явл_пустым",              "__is_void",                     "KEYCXX"),
    ("__явл_массивом",             "__is_array",                    "KEYCXX"),
    ("__явл_функцией",             "__is_function",                 "KEYCXX"),
    ("__явл_ссылкой",              "__is_reference",                "KEYCXX"),
    ("__явл_лvalue_ссылкой",       "__is_lvalue_reference",         "KEYCXX"),
    ("__явл_rvalue_ссылкой",       "__is_rvalue_reference",         "KEYCXX"),
    ("__явл_интегральным",         "__is_integral",                 "KEYCXX"),
    ("__явл_плавающим",           "__is_floating_point",           "KEYCXX"),
    ("__явл_арифметическим",       "__is_arithmetic",              "KEYCXX"),
    ("__явл_фундаментальным",      "__is_fundamental",             "KEYCXX"),
    ("__явл_объектом",            "__is_object",                   "KEYCXX"),
    ("__явл_скаляром",            "__is_scalar",                   "KEYCXX"),
    ("__явл_составным",           "__is_compound",                 "KEYCXX"),
    ("__явл_полным_типом",        "__is_complete_type",            "KEYCXX"),
    ("__явл_одинаковым",          "__is_same",                     "KEYCXX"),
    ("__явл_литеральным_типом",   "__is_literal",                  "KEYCXX"),
    ("__имеет_трив_присваивание",  "__has_trivial_assign",          "KEYCXX"),
    ("__имеет_трив_копирование",  "__has_trivial_copy",            "KEYCXX"),
    ("__имеет_трив_конструктор",   "__has_trivial_constructor",     "KEYCXX"),
    ("__имеет_трив_деструктор",   "__has_trivial_destructor",       "KEYCXX"),
    ("__имеет_nothrow_присваивание","__has_nothrow_assign",        "KEYCXX"),
    ("__имеет_nothrow_копирование","__has_nothrow_copy",           "KEYCXX"),
    ("__имеет_nothrow_конструктор","__has_nothrow_constructor",    "KEYCXX"),
    ("__явл_деструктируемым",      "__is_destructible",             "KEYALL"),
    ("__явл_trivially_деструктируемым","__is_trivially_destructible","KEYCXX"),
    ("__явл_nothrow_деструктируемым","__is_nothrow_destructible",  "KEYALL"),
    ("__явл_абстрактным",         "__is_abstract",                 "KEYCXX"),
    ("__явл_агрегатом",            "__is_aggregate",                "KEYCXX"),
    ("__явл_полиморфным",         "__is_polymorphic",              "KEYCXX"),
    ("__явл_константным",         "__is_const",                   "KEYCXX"),
    ("__явл_изменчивым",          "__is_volatile",                "KEYCXX"),
    ("__явл_стандартной_раскладкой","__is_standard_layout",        "KEYCXX"),
    ("__явл_POD",                "__is_pod",                     "KEYCXX"),
    ("__явл_пустым_классом",      "__is_empty",                   "KEYCXX"),
    ("__явл_финальным",          "__is_final",                   "KEYCXX"),
    ("__явл_взаимодействующим",   "__is_trivial",                 "KEYCXX"),
    ("__явл_тривиально_копируемым","__is_trivially_copyable",     "KEYCXX"),
    ("__явл_тривиально_присваиваемым","__is_trivially_assignable", "KEYCXX"),
    ("__явл_тривиально_конструируемым","__is_trivially_constructible","KEYCXX"),
    ("__явл_тривиально_перемещаемым","__is_trivially_relocatable","KEYCXX"),
    ("__явл_ограниченным_массивом","__is_bounded_array",          "KEYCXX"),
    ("__явл_неограниченным_массивом","__is_unbounded_array",      "KEYCXX"),
    ("__явл_областным_перечислением","__is_scoped_enum",          "KEYCXX"),
    ("__может_передаваться_в_регистрах","__can_pass_in_regs",     "KEYCXX"),
    ("__явл_интерфейсом",          "__is_interface_class",         "KEYMS"),
    ("__явл_запечатанным",        "__is_sealed",                   "KEYMS"),

    # ─── OpenCL ────────────────────────────────────────────────────────
    ("__ядро",             "__kernel",      "KEYOPENCLC | KEYOPENCLCXX"),
]

# Генерация блока ALIAS-записей
lines = []
lines.append("// ──────────────────────────────────────────────────────────────")
lines.append("// СЯзык русские ключевые слова (автогенерация patch1_rus_keywords.sh)")
lines.append("// ──────────────────────────────────────────────────────────────")

for rus, eng, flags in ALIASES:
    # Выравнивание для читаемости
    rus_padded = rus.ljust(28)
    eng_padded = eng.ljust(28)
    lines.append(f'ALIAS("{rus_padded}" , {eng_padded} , {flags})')

alias_block = "\n".join(lines)

# Вставляем перед строкой "// Clang Extensions." или перед "#undef ALIAS"
# Ищем маркер вставки
marker = "// Clang Extensions."
if marker in content:
    content = content.replace(marker, alias_block + "\n\n" + marker)
else:
    # Fallback: вставляем перед #undef ALIAS
    content = content.replace("#undef ALIAS", alias_block + "\n\n#undef ALIAS")

with open(TKD, "w", encoding="utf-8") as f:
    f.write(content)

print(f"Добавлено {len(ALIASES)} русских алиасов ключевых слов в {TKD}")
PYTHON_EOF

echo "Патч 1 (ключевые слова) применён."
