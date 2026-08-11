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
#     EDT_HOME — каталог установленной EDT (например /opt/1C/1CE/components/1c-edt-2026.2.0+289-x86_64)
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

# Выбор JVM — ЯВНО, через -vm.
# Лаунчер 1cedt ищет JDK-компонент относительно своего расположения
# (…/components/1c-edt-*/../axiom-jdk-full-*). Песочница — копия в /tmp, соседнего JDK там нет,
# и лаунчер уходит на системную java. Для линии 2026.1 это СЛУЧАЙНО совпадало (в контейнере
# openjdk-17, а EDT требует ровно 17), поэтому verify годами шёл на системной JVM незаметно.
# EDT 2026.2 требует 25 — совпадение кончилось: «Provided Java does not match the required
# version 25: /bin/java», director rc=1 и все фичи «не установились».
# JAVA_HOME лаунчер игнорирует (проверено), PATH работает, но -vm не зависит от окружения.
req=$(sed -n 's/.*-Dosgi\.requiredJavaVersion=\([0-9][0-9]*\).*/\1/p' "$EDT_HOME/1cedt.ini" | head -1)
[ -n "$req" ] || { echo "не удалось прочитать requiredJavaVersion из $EDT_HOME/1cedt.ini"; exit 1; }
JAVA_BIN=""
for cand in /opt/1C/1CE/components/axiom-jdk-full-"$req".*/bin/java /usr/lib/jvm/*"$req"*/bin/java "$(command -v java || true)"; do
  [ -x "$cand" ] || continue
  v=$("$cand" -version 2>&1 | sed -n '1s/.*version "\([0-9][0-9]*\).*/\1/p')
  [ "$v" = "$req" ] && { JAVA_BIN="$cand"; break; }
done
[ -n "$JAVA_BIN" ] || { echo "не найдена Java $req, нужная для $EDT_HOME (искали axiom-jdk-компоненты, /usr/lib/jvm, PATH)"; exit 1; }

echo ">> verify: EDT_HOME=$EDT_HOME"
echo ">> repo   =$REPO"
echo ">> IUs    =$IUS"
echo ">> java   =$JAVA_BIN (EDT требует $req)"

# Ставим в изолированную копию EDT, чтобы не портить эталонную установку.
rm -rf "$SANDBOX"
cp -a "$EDT_HOME" "$SANDBOX"

set +e
"$SANDBOX/1cedt" -vm "$JAVA_BIN" -clean -purgeHistory -application org.eclipse.equinox.p2.director \
  -noSplash -consoleLog -repository "$REPO" -installIUs "$IUS"
dir_rc=$?
set -e
echo ">> director rc=$dir_rc"

# Гейт по факту: все ли запрошенные IU реально стали installed roots?
roots="$("$SANDBOX/1cedt" -vm "$JAVA_BIN" -application org.eclipse.equinox.p2.director -noSplash -consoleLog \
  -listInstalledRoots 2>/dev/null || true)"
echo ">> roots: $(printf '%s' "$roots" | wc -c) байт"
# ВАЖНО: не проверять через `printf | grep -q` — при pipefail и roots больше pipe-буфера
# ранний выход grep даёт printf EPIPE, конвейер «падает» и УСТАНОВЛЕННАЯ фича ложно
# считается отсутствующей. Bash-подстрока — без конвейера, без гонки.
missing=()
IFS=',' read -ra arr <<< "$IUS"
for iu in "${arr[@]}"; do
  [[ "$roots" == *"$iu"* ]] || missing+=("$iu")
done

rm -rf "$SANDBOX"

if [ "${#missing[@]}" -ne 0 ]; then
  echo "VERIFY FAILED ($EDT_HOME): не установились — ${missing[*]}"
  exit 1
fi
echo "VERIFY OK ($EDT_HOME): установлены все ${#arr[@]} фич"
