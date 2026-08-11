#!/usr/bin/env bash
# Генерирует тело объединённого GitHub-релиза (markdown): архив под каждую поддерживаемую
# линию EDT + состав по каждой. Линии берутся из manifests/*.json (.package.edtLine) —
# добавление или снятие линии правок в этом скрипте не требует.
# Использование: release-notes.sh <version> [строка-сверху]
set -euo pipefail
cd "$(dirname "$0")/.."
VER="$1"; EXTRA="${2:-}"

mapfile -t MANIFESTS < <(ls manifests/*.json | sort)
[ "${#MANIFESTS[@]}" -gt 0 ] || { echo "манифесты не найдены" >&2; exit 1; }

comp() {  # $1 = путь к манифесту
  jq -r '"## Состав — " + .package.edtLine + "\n"
    + ([.plugins[] | "- **" + .name + "** " + .version + " — " + .license
        + (if .category=="mcp" then " _(категория «EDT MCP», ставится отдельно)_" else "" end)] | join("\n"))
    + "\n- **YAXUnit** " + .yaxunit.version + " — " + .yaxunit.license
    + " _(расширение 1С .cfe, в папке yaxunit/ — нужно для edt-test-runner)_"' "$1"
}

ARCHIVES=""; COMPS=""
for m in "${MANIFESTS[@]}"; do
  line=$(jq -r '.package.edtLine' "$m")
  ARCHIVES="$ARCHIVES- **EDT-Plugin-Pack-$line-$VER.zip** — для 1C:EDT **$line**"$'\n'
  COMPS="$COMPS$(comp "$m")"$'\n\n'
done

[ -n "$EXTRA" ] && printf '%s\n\n' "$EXTRA"
cat <<EOF
# Набор плагинов 1C:EDT — v$VER

Выберите архив под свою версию 1C:EDT (все **проверены установкой на реальную 1C:EDT**, self-hosted runner):

$ARCHIVES
## Установка
В 1C:EDT: Справка → Установить новое ПО → **Add… → Archive…** → выбрать архив под свою версию EDT →
отметить категорию **«Набор плагинов 1C:EDT»** → снять галку «Обращаться ко всем сайтам обновления…» → установить.
YAXUnit (.cfe) — отдельно: из папки yaxunit/ загрузить в информационную базу (нужен для edt-test-runner).

$COMPS
EOF
