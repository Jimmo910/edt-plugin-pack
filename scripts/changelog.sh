#!/usr/bin/env bash
# scripts/changelog.sh — собирает CHANGELOG.md из тегов и коммитов между ними.
#
# Источник правды — git, поэтому файл можно перегенерировать в любой момент и он не может
# «разойтись» с историей: правки руками затрутся при следующем релизе. Ничего не хранит,
# состояния нет.
#
# Использование:
#   changelog.sh              — только выпущенные версии (по существующим тегам)
#   changelog.sh <версия>     — плюс секция готовящегося релиза (тега ещё нет), из коммитов
#                               после последнего тега; так CHANGELOG попадает в тот же коммит,
#                               которым релиз и выпускается
set -euo pipefail
cd "$(dirname "$0")/.."

PENDING="${1:-}"
OUT="CHANGELOG.md"

git rev-parse --git-dir >/dev/null 2>&1 || { echo "не git-репозиторий" >&2; exit 1; }

mapfile -t TAGS < <(git tag --sort=-v:refname)
if [ "${#TAGS[@]}" -eq 0 ] && [ -z "$PENDING" ]; then
  echo "нет ни одного тега и не задана готовящаяся версия — нечего собирать" >&2
  exit 1
fi

# Коммиты в диапазоне, отсортированные так же, как их видит git log (новые сверху).
# Мержи выкидываем: в этом репозитории история линейная, а мерж-коммиты дали бы шум.
# --invert-grep вместо конвейера с grep: служебные коммиты «docs: CHANGELOG для …» — это
# бухгалтерия самого changelog'а, в истории изменений они лишний шум.
log_range() { git log --no-merges --invert-grep --grep='^docs: CHANGELOG' --format='- %s' "$@" 2>/dev/null || true; }

{
  echo "# История изменений"
  echo
  echo "Собирается автоматически из тегов и коммитов (\`scripts/changelog.sh\`) при каждом релизе —"
  echo "править вручную бесполезно, изменения затрутся. Архивы каждого релиза — на странице"
  echo "[Releases](https://github.com/Jimmo910/edt-plugin-pack/releases)."
  echo

  if [ -n "$PENDING" ]; then
    last="${TAGS[0]:-}"
    body=$(if [ -n "$last" ]; then log_range "$last..HEAD"; else log_range HEAD; fi)
    printf '## v%s — %s\n\n%s\n\n' "$PENDING" "$(date -u +%Y-%m-%d)" "${body:-- без изменений в коде}"
  fi

  for i in "${!TAGS[@]}"; do
    t="${TAGS[$i]}"
    older="${TAGS[$((i+1))]:-}"
    when=$(git log -1 --format=%ad --date=short "$t" 2>/dev/null || echo '?')
    if [ -n "$older" ]; then body=$(log_range "$older..$t"); else body=$(log_range "$t"); fi
    printf '## %s — %s\n\n%s\n\n' "$t" "$when" "${body:-- нет коммитов в этом диапазоне}"
  done
} > "$OUT"

echo "$OUT собран: секций $(grep -c '^## ' "$OUT")"
