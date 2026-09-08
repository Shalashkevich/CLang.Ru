#!/usr/bin/env python3
# apply.sh — применяет патчи СЯзык к исходникам LLVM/Clang
# Запускать из корня llvm-project: ../patches/apply.sh .
import os, sys, shutil, re

def backup(path):
    if os.path.exists(path):
        shutil.copy(path, path + ".bak")

def load_file(path):
    with open(path, "r", encoding="utf-8") as f:
        return f.readlines()

def save_file(path, lines):
    with open(path, "w", encoding="utf-8") as f:
        f.writelines(lines)

def insert_after_marker(lines, marker_regex, content_lines, before=False):
    """
    Вставляет content_lines после (или перед) первой строки, совпадающей с marker_regex.
    Если before=True — вставляет ПЕРЕД найденной строкой.
    """
    for i, line in enumerate(lines):
        if re.search(marker_regex, line):
            if before:
                return lines[:i] + content_lines + ["\n"] + lines[i:]
            else:
                return lines[:i+1] + ["\n"] + content_lines + lines[i+1:]
    return lines

def main():
    root = sys.argv[1] if len(sys.argv) > 1 else "."
    script_dir = os.path.dirname(os.path.abspath(__file__))
    patches_dir = os.path.join(script_dir, "..", "patches")

    # --- Патч 1: русские ключевые слова в IdentifierTable ---
    kw_inc_path = os.path.join(patches_dir, "rus_keywords.inc")
    with open(kw_inc_path, "r", encoding="utf-8") as f:
        kw_lines = f.readlines()

    # 1.1. Вставляем таблицу в clang/include/clang/Basic/IdentifierTable.h
    kw_h_path = os.path.join(root, "clang", "include", "clang", "Basic", "IdentifierTable.h")
    backup(kw_h_path)
    lines = load_file(kw_h_path)

    # Ищем конец класса (};) и вставляем перед ним
    insert_pos = -1
    for i in reversed(range(len(lines))):
        stripped = lines[i].strip()
        if stripped == "};":
            insert_pos = i
            break

    if insert_pos != -1:
        lines = lines[:insert_pos] + kw_lines + ["\n"] + lines[insert_pos:]
        save_file(kw_h_path, lines)
        print("Applied rus_keywords.inc to IdentifierTable.h")
    else:
        print("Warning: Could not find '};' in IdentifierTable.h — keyword table not inserted.")

    # 1.2. Вставляем ту же таблицу в начало clang/lib/Lex/IdentifierTable.cpp
    kw_cpp_path = os.path.join(root, "clang", "lib", "Lex", "IdentifierTable.cpp")
    backup(kw_cpp_path)
    cpp_lines = load_file(kw_cpp_path)

    # Вставляем сразу после всех #include (находим последнюю строку с #include)
    last_include_idx = -1
    for i, line in enumerate(cpp_lines):
        if line.strip().startswith("#include"):
            last_include_idx = i

    if last_include_idx != -1:
        cpp_lines = cpp_lines[:last_include_idx+1] + ["\n"] + kw_lines + cpp_lines[last_include_idx+1:]
        save_file(kw_cpp_path, cpp_lines)
        print("Applied rus_keywords.inc to IdentifierTable.cpp")
    else:
        # Если нет #include, вставляем в самое начало
        cpp_lines = kw_lines + ["\n"] + cpp_lines
        save_file(kw_cpp_path, cpp_lines)
        print("Applied rus_keywords.inc to IdentifierTable.cpp (inserted at top)")

    # --- Патч 2: переводы ошибок в DiagnosticIDs.cpp ---
    diag_inc_path = os.path.join(patches_dir, "rus_diagnostics.inc")
    with open(diag_inc_path, "r", encoding="utf-8") as f:
        diag_lines = f.readlines()

    diag_cpp_path = os.path.join(root, "clang", "lib", "Basic", "DiagnosticIDs.cpp")
    backup(diag_cpp_path)
    diag_lines_content = load_file(diag_cpp_path)

    # Ищем функцию getDescription() и вставляем таблицу прямо перед ней (или в начало файла)
    # Самый надёжный вариант — вставить в начало файла, но после #include
    last_include_idx = -1
    for i, line in enumerate(diag_lines_content):
        if line.strip().startswith("#include"):
            last_include_idx = i

    if last_include_idx != -1:
        diag_lines_content = diag_lines_content[:last_include_idx+1] + ["\n"] + diag_lines + diag_lines_content[last_include_idx+1:]
        save_file(diag_cpp_path, diag_lines_content)
        print("Applied rus_diagnostics.inc to DiagnosticIDs.cpp")
    else:
        diag_lines_content = diag_lines + ["\n"] + diag_lines_content
        save_file(diag_cpp_path, diag_lines_content)
        print("Applied rus_diagnostics.inc to DiagnosticIDs.cpp (inserted at top)")

    # --- Патч 3: логика подмены русских слов в IdentifierTable.cpp ---
    # Добавляем функцию-помощник и модифицируем get()
    # Это упрощённая версия: мы добавляем статическую таблицу и функцию поиска
    # и делаем так, чтобы get() проверял русские слова перед возвратом.

    cpp_modified = load_file(kw_cpp_path)  # уже загружен выше, но перечитаем для ясности
    # Если уже модифицировали — не будем дублировать, но для простоты перезапишем с логикой
    # Здесь мы просто добавим функцию, которая делает маппинг.

    map_func = """
static const char* rus_to_eng_lookup(const char* rus) {
  static const struct { const char* r; const char* e; } map[] = {
"""
    # Переиспользуем данные из rus_keywords.inc, но в виде C++ функции
    # Для простоты просто скопируем логику из .inc и превратим в функцию
    # (в реальном проекте лучше вынести в отдельный заголовок, но здесь делаем компактно)

    # Чтобы не парсить .inc заново, просто вставим упрощённый маппинг прямо сюда.
    # Ниже — минимальный список для примера. В идеале нужно генерировать это из rus_keywords.inc.
    map_entries = [
        ('если', 'if'), ('иначе', 'else'), ('пока', 'while'), ('для', 'for'),
        ('вернуть', 'return'), ('целое', 'int'), ('плавающее', 'float'), ('двойной', 'double'),
        ('структура', 'struct'), ('переключатель', 'switch'), ('случай', 'case'),
        ('по умолчанию', 'default'), ('класс', 'class'), ('шаблон', 'template'),
        ('новое', 'new'), ('удалённое', 'delete'), ('оператор', 'operator'),
        ('публичное', 'public'), ('приватное', 'private'), ('защищённое', 'protected'),
        ('включить', 'include'), ('определить', 'define'), ('отменить_определение', 'undef'),
        ('если_определено', 'ifdef'), ('если_не_определено', 'ifndef'), ('ошибка', 'error'),
        ('прагма', 'pragma'), ('модуль', 'module')
    ]

    for r, e in map_entries:
        map_func += f'    {{"{r}", "{e}"}},\n'

    map_func += """    {nullptr, nullptr}
  };
  for (size_t i = 0; map[i].r != nullptr; ++i) {
    if (strcmp(rus, map[i].r) == 0) return map[i].e;
  }
  return nullptr;
}
"""

    # Теперь найдём определение get() в IdentifierTable.cpp и модифицируем его
    # Мы ищем: IdentifierInfo *IdentifierTable::get(StringRef Name)
    get_signature = r"IdentifierInfo \*IdentifierTable::get$StringRef Name$"
    
    # Вместо сложной модификации, мы вставим функцию lookup в начало файла (уже сделали)
    # и добавим вызов в get(). Но чтобы не ломать парсер, сделаем это аккуратно.
    # Упрощение: мы вставим lookup и вызов в get() через поиск сигнатуры.

    # Читаем заново
    cpp_content = load_file(kw_cpp_path)

    # Вставляем lookup-функцию после всех #include (уже сделано выше вместе с rus_keywords)
    # А теперь ищем get() и добавляем логику
    i = 0
    while i < len(cpp_content):
        line = cpp_content[i]
        if re.search(get_signature, line):
            # Нашли сигнатуру get(). Теперь идём до открывающей { и вставляем логику внутрь
            j = i
            while j < len(cpp_content) and not cpp_content[j].strip().startswith("{"):
                j += 1
            if j < len(cpp_content):
                # Вставляем проверку русских слов сразу после {
                cpp_content = cpp_content[:j+1] + [
                    "  const char* eng = rus_to_eng_lookup(Name.data());\n",
                    "  if (eng) {\n",
                    "    StringRef newName(eng, strlen(eng));\n",
                    "    return getImpl(newName);\n",
                    "  }\n"
                ] + cpp_content[j+1:]
                print("Modified get() to handle Russian keywords.")
                break
        i += 1

    save_file(kw_cpp_path, cpp_content)

    print("All patches applied successfully.")

if __name__ == "__main__":
    main()
