#!/bin/bash
# СЯзык patch for Clang 23.1
# Adds Russian keyword aliases via ALIAS macro in TokenKinds.def

set -e

DEFFILE="clang/include/clang/Basic/TokenKinds.def"

if [ ! -f "$DEFFILE" ]; then
    echo "Error: $DEFFILE not found"
    exit 1
fi

if grep -q 'ALIAS("если"' "$DEFFILE"; then
    echo "Already patched, skipping."
    exit 0
fi

TMPFILE=$(mktemp)

awk '
/^#undef ALIAS/ && !done {
    print "// === СЯзык: Russian keyword aliases ==="
    print "ALIAS(\"если\", if, KEYALL)"
    print "ALIAS(\"иначе\", else, KEYALL)"
    print "ALIAS(\"пока\", while, KEYALL)"
    print "ALIAS(\"для\", for, KEYALL)"
    print "ALIAS(\"вернуть\", return, KEYALL)"
    print "ALIAS(\"переключатель\", switch, KEYALL)"
    print "ALIAS(\"случай\", case, KEYALL)"
    print "ALIAS(\"умолчание\", default, KEYALL)"
    print "ALIAS(\"прервать\", break, KEYALL)"
    print "ALIAS(\"продолжить\", continue, KEYALL)"
    print "ALIAS(\"перейти\", goto, KEYALL)"
    print "ALIAS(\"целое\", int, KEYALL)"
    print "ALIAS(\"короткое\", short, KEYALL)"
    print "ALIAS(\"длинное\", long, KEYALL)"
    print "ALIAS(\"символ\", char, KEYALL)"
    print "ALIAS(\"пусто\", void, KEYALL)"
    print "ALIAS(\"плавающее\", float, KEYALL)"
    print "ALIAS(\"двойное\", double, KEYALL)"
    print "ALIAS(\"беззнаковое\", unsigned, KEYALL)"
    print "ALIAS(\"константа\", const, KEYALL)"
    print "ALIAS(\"изменчивое\", volatile, KEYALL)"
    print "ALIAS(\"логическое\", bool, KEYCXX)"
    print "ALIAS(\"авто\", auto, KEYALL)"
    print "ALIAS(\"размер\", sizeof, KEYALL)"
    print "ALIAS(\"структура\", struct, KEYALL)"
    print "ALIAS(\"объединение\", union, KEYALL)"
    print "ALIAS(\"перечисление\", enum, KEYALL)"
    print "ALIAS(\"тип\", typedef, KEYALL)"
    print "ALIAS(\"внешний\", extern, KEYALL)"
    print "ALIAS(\"статический\", static, KEYALL)"
    print "ALIAS(\"регистр\", register, KEYALL)"
    print "ALIAS(\"указатель_нуль\", nullptr, KEYCXX11|KEYC23)"
    print "ALIAS(\"класс\", class, KEYCXX)"
    print "ALIAS(\"шаблон\", template, KEYCXX)"
    print "ALIAS(\"пространство\", namespace, KEYCXX)"
    print "ALIAS(\"новое\", new, KEYCXX)"
    print "ALIAS(\"удалить\", delete, KEYCXX)"
    print "ALIAS(\"попытка\", try, KEYCXX)"
    print "ALIAS(\"поймать\", catch, KEYCXX)"
    print "ALIAS(\"бросить\", throw, KEYCXX)"
    print "ALIAS(\"открытый\", public, KEYCXX)"
    print "ALIAS(\"закрытый\", private, KEYCXX)"
    print "ALIAS(\"защищённый\", protected, KEYCXX)"
    print "ALIAS(\"виртуальный\", virtual, KEYCXX)"
    print "ALIAS(\"переопределить\", override, KEYCXX11)"
    print "// === End СЯзык aliases ==="
    print ""
    done = 1
}
{ print }
' "$DEFFILE" > "$TMPFILE"

mv "$TMPFILE" "$DEFFILE"
echo "Patch applied: Russian keywords added to $DEFFILE"
