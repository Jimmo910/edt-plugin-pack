#!/usr/bin/env bash
# scripts/verify.sh — проверка установки набора на 1C:EDT (Linux, self-hosted runner).
# Ставит фичи набора на КОПИЮ установленной EDT через штатный p2 director (launcher EDT
# сам поднимает director на своём JDK). Аналог Windows-verify.ps1, но без pwsh.
#
# ВАЖНО: launcher 1cedt может вернуть код 0, даже если director не смог разрешить
# зависимости. Поэтому гейт — ФАКТ установки: после установки проверяем, что КАЖДЫЙ
# запрошенный IU присутствует в -listInstalledRoots; если хоть один отсутствует — провал.
#
# Использование:
#   verify.sh <EDT_HOME> <REPO_URI> <IUS>
#     EDT_HOME — каталог установленной EDT (например /opt/1C/1CE/components/1c-edt-2025.2.6+4-x86_64)
#     REPO_URI — p2-репозиторий: "jar:file:/path/pack.zip!/" (zip) или "file:/path/site" (каталог)
#     IUS      — список feature.group через запятую
#   Песочницу можно переопределить переменной VERIFY_SANDBOX.
set -euo pipefail

EDT_HOME="${1:?EDT_HOME required}"
REPO="${2:?repository URI required}"
IUS="${3:?IU list required}"
IUS="${IUS//$'\r'/}"   # ius.txt мог прийти с Windows (CRLF) — убираем \r из id фич
SANDBOX="${VERIFY_SANDBOX:-/tmp/edt-verify-sandbox}"

[ -x "$EDT_HOME/1cedt" ] || { echo "Не найден launcher $EDT_HOME/1cedt"; exit 1; }

echo ">> verify: EDT_HOME=$EDT_HOME"
echo ">> repo   =$REPO"
echo ">> IUs    =$IUS"

# Ставим в изолированную копию EDT, чтобы не портить эталонную установку.
rm -rf "$SANDBOX"
cp -a "$EDT_HOME" "$SANDBOX"

set +e
"$SANDBOX/1cedt" -clean -purgeHistory -application org.eclipse.equinox.p2.director \
  -noSplash -consoleLog -repository "$REPO" -installIUs "$IUS"
dir_rc=$?
set -e
echo ">> director rc=$dir_rc"

# Гейт по факту: все ли запрошенные IU реально стали installed roots?
roots="$("$SANDBOX/1cedt" -application org.eclipse.equinox.p2.director -noSplash -consoleLog \
  -listInstalledRoots 2>/dev/null || true)"
missing=()
IFS=',' read -ra arr <<< "$IUS"
for iu in "${arr[@]}"; do
  printf '%s\n' "$roots" | grep -qF "$iu" || missing+=("$iu")
done

rm -rf "$SANDBOX"

if [ "${#missing[@]}" -ne 0 ]; then
  echo "VERIFY FAILED ($EDT_HOME): не установились — ${missing[*]}"
  exit 1
fi
echo "VERIFY OK ($EDT_HOME): установлены все ${#arr[@]} фич"
