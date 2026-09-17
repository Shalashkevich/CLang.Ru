#!/usr/bin/env bash
# =============================================================================
# patch2_rus_pp_directives.sh — Русские препроцессорные директивы для Clang
# =============================================================================
# Создаёт файл RusPPKeywords.h и патчит PPDirectives.cpp
# для поддержки русских препроцессорных директив

set -e

# Проверяем существование директорий
if [ ! -d "clang/lib/Lex" ]; then
    echo "Ошибка: директория clang/lib/Lex не найдена"
    exit 1
fi

# Создаём файл RusPPKeywords.h
cat <<EOF > clang/include/clang/Lex/RusPPKeywords.h
// =========================================================================
// СЯзык русские препроцессорные директивы
// =========================================================================
#ifndef CLANG_LEX_RUSPPKEYWORDS_H
#define CLANG_LEX_RUSPPKEYWORDS_H

#include "clang/Basic/TokenKinds.h"

namespace clang {
namespace lex {

// Маппинг русских препроцессорных директив
inline tok::PPKeywordID getRusPPKeywordID(StringRef Name) {
    if (Name == "#если") return tok::pp_if;
    if (Name == "#если_определено") return tok::pp_ifdef;
    if (Name == "#если_не_определено") return tok::pp_ifndef;
    if (Name == "#иначе_если") return tok::pp_elif;
    if (Name == "#иначе_если_опр") return tok::pp_elifdef;
    if (Name == "#иначе_если_не_опр") return tok::pp_elifndef;
    if (Name == "#иначе") return tok::pp_else;
    if (Name == "#конец_если") return tok::pp_endif;
    if (Name == "#включить") return tok::pp_include;
    if (Name == "#определить") return tok::pp_define;
    if (Name == "#отменить_определение") return tok::pp_undef;
    if (Name == "#строка") return tok::pp_line;
    if (Name == "#ошибка") return tok::pp_error;
    if (Name == "#прагма") return tok::pp_pragma;
    if (Name == "#вложение") return tok::pp_embed;
    if (Name == "#включить_следующее") return tok::pp_include_next;
    if (Name == "#предупреждение") return tok::pp_warning;
    if (Name == "#импорт") return tok::pp_import;
    if (Name == "#идент") return tok::pp_ident;
    if (Name == "#сццс") return tok::pp_pch_org;
    if (Name == "#утверждение") return tok::pp_assert;
    if (Name == "#отменить_утверждение") return tok::pp_unassert;
    if (Name == "#__открытый_макрос") return tok::pp_open_macro;
    if (Name == "#__закрытый_макрос") return tok::pp_close_macro;
    if (Name == "#__имеет_атрибут") return tok::pp_has_attribute;
    if (Name == "#__имеет_встроенное") return tok::pp_has_builtin;
    if (Name == "#__имеет_включение") return tok::pp_has_include;
    
    return tok::pp_not_keyword;
}

} // namespace lex
} // namespace clang

#endif // CLANG_LEX_RUSPPKEYWORDS_H
EOF

# Патчим PPDirectives.cpp
sed -i.bak -e '
/getPPKeywordID/i\
    if (Result == tok::pp_not_keyword) {\
        Result = lex::getRusPPKeywordID(Name);\
    }\
' clang/lib/Lex/PPDirectives.cpp

# Добавляем include в PPDirectives.cpp
sed -i.bak -e '
/PPDirectives\.cpp/a\
#include "clang/Lex/RusPPKeywords.h"\
' clang/lib/Lex/PPDirectives.cpp

echo "Патч 2 (препроцессорные директивы) применён успешно"
