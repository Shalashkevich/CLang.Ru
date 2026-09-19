#!/usr/bin/env bash
set -e

echo "=== СЯзык: добавление русского перевода в CLang ==="

# 1. Ключевые слова
bash ../.github/patches/patch1_russian_keywords.sh

# 2. Препроцессорные директивы
bash ../.github/patches/patch2_russian_preprocessor_directives.sh

# 3. Диагностика
#python3 ../.github/patches/#patch3_translate_diagnostics.py --apply

echo "=== Патч СЯзык применён успешно ==="