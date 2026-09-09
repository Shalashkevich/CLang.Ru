#!/usr/bin/env bash
set -e

echo "=== СЯзык: добавление русских ключевых слов ==="

TOKEN_KINDS="clang/include/clang/Basic/TokenKinds.def"

if [ ! -f "$TOKEN_KINDS" ]; then
    echo "ОШИБКА: $TOKEN_KINDS не найден!"
    echo "Текущая директория: $(pwd)"
    echo "Содержимое clang/include/clang/Basic/:"
    ls -la clang/include/clang/Basic/ 2>/dev/null || echo "директория не найдена"
    exit 1
fi

# Проверка идемпотентности
if grep -q 'СЯзык' "$TOKEN_KINDS"; then
    echo "Русские ключевые слова уже добавлены, пропускаем."
    exit 0
fi

# Ищем строку с while — гибкий поиск, tolerant к пробелам
LINE=$(grep -n 'KEYWORD(while' "$TOKEN_KINDS" | head -1 | cut -d: -f1)

if [ -z "$LINE" ]; then
    echo "ОШИБКА: не найдена точка вставки в TokenKinds.def"
    echo "Первые 40 строк файла:"
    head -40 "$TOKEN_KINDS"
    echo "---"
    echo "Строки с KEYWORD:"
    grep -n 'KEYWORD' "$TOKEN_KINDS" | head -20
    exit 1
fi

echo "Точка вставки: строка $LINE"
sed -n "${LINE}p" "$TOKEN_KINDS"

# Создаём временный файл с русскими алиасами
TMPFILE=$(mktemp)
cat > "$TMPFILE" << 'ENDALIASES'

// СЯзык: Русские ключевые слова (алиасы)
ALIAS("если", if , KEYALL)
ALIAS("иначе", else , KEYALL)
ALIAS("пока", while , KEYALL)
ALIAS("для", for , KEYALL)
ALIAS("возврат", return , KEYALL)
ALIAS("прерывание", break , KEYALL)
ALIAS("продолжить", continue , KEYALL)
ALIAS("выбор", switch , KEYALL)
ALIAS("вариант", case , KEYALL)
ALIAS("умолчание", default , KEYALL)
ALIAS("делать", do , KEYALL)
ALIAS("структура", struct , KEYALL)
ALIAS("объединение", union , KEYALL)
ALIAS("перечисление", enum , KEYALL)
ALIAS("тип", typedef , KEYALL)
ALIAS("константа", const , KEYALL)
ALIAS("статический", static , KEYALL)
ALIAS("внешний", extern , KEYALL)
ALIAS("изменчивый", volatile , KEYALL)
ALIAS("авто", auto , KEYALL)
ALIAS("переход", goto , KEYALL)
ALIAS("пусто", void , KEYALL)
ALIAS("целое", int , KEYALL)
ALIAS("символ", char , KEYALL)
ALIAS("короткий", short , KEYALL)
ALIAS("длинный", long , KEYALL)
ALIAS("плавающий", float , KEYALL)
ALIAS("двойной", double , KEYALL)
ALIAS("знаковый", signed , KEYALL)
ALIAS("беззнаковый", unsigned , KEYALL)
ALIAS("размер", sizeof , KEYALL)
ENDALIASES

# Вставляем после найденной строки
sed -i "${LINE}r ${TMPFILE}" "$TOKEN_KINDS"
rm "$TMPFILE"

echo "✓ Русские ключевые слова добавлены в TokenKinds.def"
echo "=== Патч СЯзык применён успешно ==="
