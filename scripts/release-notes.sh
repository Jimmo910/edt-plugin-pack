#!/usr/bin/env bash
# Генерирует тело объединённого GitHub-релиза (markdown): два архива (2025.2 и 2026.1)
# + состав по каждой версии EDT. Версии берутся из manifests/*.json.
# Использование: release-notes.sh <version> [строка-сверху]
set -euo pipefail
VER="$1"; EXTRA="${2:-}"

comp() {  # $1 = путь к манифесту
  jq -r '"## Состав — " + .package.edtLine + "\n"
    + ([.plugins[] | "- **" + .name + "** " + .version + " — " + .license
        + (if .category=="mcp" then " _(категория «EDT MCP», ставится отдельно)_" else "" end)] | join("\n"))
    + "\n- **YAXUnit** " + .yaxunit.version + " — " + .yaxunit.license
    + " _(расширение 1С .cfe, в папке yaxunit/ — нужно для edt-test-runner)_"' "$1"
}

[ -n "$EXTRA" ] && printf '%s\n\n' "$EXTRA"
cat <<EOF
# Набор плагинов 1C:EDT — v$VER

Два архива — выберите под свою версию 1C:EDT (оба **проверены установкой на реальную 1C:EDT**, self-hosted runner):

- **EDT-Plugin-Pack-2025.2-$VER.zip** — для 1C:EDT **2025.2**
- **EDT-Plugin-Pack-2026.1-$VER.zip** — для 1C:EDT **2026.1**

## Установка
В 1C:EDT: Справка → Установить новое ПО → **Add… → Archive…** → выбрать архив под свою версию EDT →
отметить категорию **«Набор плагинов 1C:EDT»** → снять галку «Обращаться ко всем сайтам обновления…» → установить.
YAXUnit (.cfe) — отдельно: из папки yaxunit/ загрузить в информационную базу (нужен для edt-test-runner).

$(comp manifests/2025.2.json)

$(comp manifests/2026.1.json)
EOF
