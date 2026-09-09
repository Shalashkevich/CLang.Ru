#!/usr/bin/env bash
set -e

echo "=== СЯзык: добавление русских ключевых слов ==="

TOKEN_KINDS="clang/include/clang/Basic/TokenKinds.def"

if [ ! -f "$TOKEN_KINDS" ]; then
    echo "ОШИБКА: $TOKEN_KINDS не найден!"
    exit 1
fi

# Проверка идемпотентности — не патчим дважды
if grep -q 'СЯзык' "$TOKEN_KINDS"; then
    echo "Русские ключевые слова уже добавлены, пропускаем."
    exit 0
fi

# Точка вставки — после KEYWORD(while , KEYALL), конец секции C89 keywords
LINE=$(grep -n 'KEYWORD(while , KEYALL)' "$TOKEN_KINDS" | head -1 | cut -d: -f1)

if [ -z "$LINE" ]; then
    echo "ОШИБКА: не найдена точка вставки в TokenKinds.def"
    exit 1
fi

# Создаём временный файл с русскими алиасами
TMPFILE=$(mktemp)
cat > "$TMPFILE" << 'ENDALIASES'

// СЯзык: Русские ключевые слова (алиасы)
ALIAS("если", if, KEYALL)
ALIAS("иначе", else, KEYALL)
ALIAS("пока", while, KEYALL)
ALIAS("для", for, KEYALL)
ALIAS("возврат", return, KEYALL)
ALIAS("прерывание", break, KEYALL)
ALIAS("продолжить", continue, KEYALL)
ALIAS("выбор", switch, KEYALL)
ALIAS("вариант", case, KEYALL)
ALIAS("умолчание", default, KEYALL)
ALIAS("делать", do, KEYALL)
ALIAS("структура", struct, KEYALL)
ALIAS("объединение", union, KEYALL)
ALIAS("перечисление", enum, KEYALL)
ALIAS("тип", typedef, KEYALL)
ALIAS("константа", const, KEYALL)
ALIAS("статический", static, KEYALL)
ALIAS("внешний", extern, KEYALL)
ALIAS("регистр", register, KEYALL)
ALIAS("изменчивый", volatile, KEYALL)
ALIAS("авто", auto, KEYALL)
ALIAS("переход", goto, KEYALL)
ALIAS("пусто", void, KEYALL)
ALIAS("целое", int, KEYALL)
ALIAS("символ", char, KEYALL)
ALIAS("короткий", short, KEYALL)
ALIAS("длинный", long, KEYALL)
ALIAS("плавающий", float, KEYALL)
ALIAS("двойной", double, KEYALL)
ALIAS("знаковый", signed, KEYALL)
ALIAS("беззнаковый", unsigned, KEYALL)
ALIAS("размер", sizeof, KEYALL)
ENDALIASES

# Вставляем содержимое файла после найденной строки
sed -i "${LINE}r ${TMPFILE}" "$TOKEN_KINDS"
rm "$TMPFILE"

echo "✓ Русские ключевые слова добавлены в TokenKinds.def"
echo "=== Патч СЯзык применён успешно ==="
