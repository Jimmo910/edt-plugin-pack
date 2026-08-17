#!/usr/bin/env bash
# Генерирует тело объединённого GitHub-релиза (markdown): архив под каждую поддерживаемую
# линию EDT + состав по каждой. Линии берутся из manifests/*.json (.package.edtLine) —
# добавление или снятие линии правок в этом скрипте не требует.
# Использование: release-notes.sh <version> [строка-сверху]
set -euo pipefail
cd "$(dirname "$0")/.."
VER="$1"; EXTRA="${2:-}"

MANIFESTS=()   # инициализация обязательна: при пустом manifests/ mapfile переменную не создаст,
               # и под set -u проверка ниже упала бы с «unbound variable» вместо внятного сообщения
mapfile -t MANIFESTS < <(ls manifests/*.json 2>/dev/null | sort)
[ "${#MANIFESTS[@]}" -gt 0 ] || { echo "манифесты не найдены" >&2; exit 1; }

# Секция «Что изменилось» — из коммитов после предыдущего тега. Без неё описание релиза
# рассказывало только СОСТАВ набора: у ручного релиза не было ни слова о том, что поменялось
# (кроме врезки, если её не забыли передать), а у авто-релиза — одна строка про бампы плагинов,
# при том что в тот же релиз могли уехать правки CI и скриптов.
# Требует историю с тегами: в workflow у соответствующих job'ов стоит fetch-depth: 0.
changes() {
  command -v git >/dev/null 2>&1 || return 0
  git rev-parse --git-dir >/dev/null 2>&1 || return 0
  local prev log
  prev=$(git describe --tags --abbrev=0 HEAD 2>/dev/null || true)
  [ -n "$prev" ] || return 0                       # первый релиз — сравнивать не с чем
  log=$(git log --no-merges --invert-grep --grep='^docs: CHANGELOG' --format='- %s' "$prev..HEAD" 2>/dev/null || true)
  [ -n "$log" ] || return 0                        # HEAD уже на теге (перевыпуск) — секции нет
  printf '## Что изменилось с %s\n\n%s\n' "$prev" "$log"
}

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
$(changes)
## Установка
В 1C:EDT: Справка → Установить новое ПО → **Add… → Archive…** → выбрать архив под свою версию EDT →
отметить категорию **«Набор плагинов 1C:EDT»** → снять галку «Обращаться ко всем сайтам обновления…» → установить.
YAXUnit (.cfe) — отдельно: из папки yaxunit/ загрузить в информационную базу (нужен для edt-test-runner).

$COMPS
EOF
