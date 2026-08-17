# Набор плагинов 1C:EDT

[![Build, Verify & Release](https://github.com/Jimmo910/edt-plugin-pack/actions/workflows/build-release.yml/badge.svg)](https://github.com/Jimmo910/edt-plugin-pack/actions/workflows/build-release.yml)
[![Auto-update plugins](https://github.com/Jimmo910/edt-plugin-pack/actions/workflows/auto-update.yml/badge.svg)](https://github.com/Jimmo910/edt-plugin-pack/actions/workflows/auto-update.yml)
[![Последний релиз](https://img.shields.io/github/v/release/Jimmo910/edt-plugin-pack)](https://github.com/Jimmo910/edt-plugin-pack/releases/latest)
[![1C:EDT](https://img.shields.io/badge/1C%3AEDT-2026.1%20%7C%202026.2-blue)](https://edt.1c.ru/)

Набор полезных **сторонних** плагинов 1C:EDT — ставится галочкой на одной категории:
**по ссылке** (update site, с обновлениями) или **офлайн-архивом**. Поддерживаются версии EDT
**2026.1** и **2026.2** (под каждую свой набор, проверенный установкой на реальную EDT).

> **1C:EDT 2025.2 снята с поддержки.** Последняя сборка под неё — в релизе
> [v1.1.4](https://github.com/Jimmo910/edt-plugin-pack/releases/tag/v1.1.4)
> (`EDT-Plugin-Pack-2025.2-1.1.4.zip`), она остаётся доступной, но больше не обновляется;
> update site по адресу `…/2025.2/` больше не публикуется.

## Что входит в набор

| Плагин | Версия | Лицензия | Что делает |
|--------|--------|----------|------------|
| [EDT Extension Tweaks](https://github.com/Xelgo/edt-extension-tweaks) | 1.1.22 | EPL-2.0 | общий BSL-контекст, конструктор запросов, цепочки обновления |
| [Disable Editing Plugin](https://gitlab.com/marmyshev/edt-editing) | 0.6.0 (2026.1) / 0.7.0 (2026.2) | EPL-2.0 | объекты «только для чтения» по правилам |
| [EDT Test Runner](https://github.com/bia-technologies/edt-test-runner) | 25.01 | Apache-2.0 | запуск/отладка юнит-тестов (YAXUnit) |
| [Configuration Repository (PluginEDT)](https://github.com/ZigRinat85/PluginEDT) | 0.4.0 | EPL-2.0 | работа с хранилищем конфигурации 1С |
| [AnyEdit Tools](https://github.com/iloveeclipse/anyedittools) | 2.7.3 | EPL-2.0 | сравнение, буфер обмена, автоформат |
| [IndentGuide](https://github.com/marmyshev/indent-guide) | 2.2.5 | MIT | направляющие отступов в редакторе |
| [EDT Fast Button](https://github.com/Jimmo910/edt-fast-button) | 0.1.5 | EPL-2.0 | быстрые кнопки безопасных Git-операций |
| [EDT MCP Server](https://github.com/DitriXNew/EDT-MCP) | 2.12.1 | **AGPL-3.0** | MCP-сервер для AI-ассистентов _(отдельная категория)_ |
| [YAXUnit](https://github.com/bia-technologies/yaxunit) | 25.12 | Apache-2.0 | движок тестов — расширение 1С `.cfe` (не плагин EDT, ставится в ИБ) |

Составы линий совпадают, кроме **Disable Editing Plugin**: на 2026.2 идёт 0.7.0, на 2026.1 — 0.6.0
(0.7.0 требует Guava 33.5, а 2026.1 несёт 32.1.3).

## Требования
- Установленная **1C:EDT 2026.1 или 2026.2** — больше для установки ничего не нужно.
  (Java отдельно не нужна: 2026.1 работает на Java 17, 2026.2 — на Java 25, обе берут её из состава EDT.)
- (Только для сборки из исходников: PowerShell 7+ и Java 17.)

## Установка

### Вариант 1 — по ссылке (рекомендуется)
На update site всегда лежит последний прошедший проверку релиз; установленные так плагины
обновляются штатно (**Справка → Проверить обновления**).

1. В 1C:EDT: **Справка → Установить новое ПО…** (Install New Software) → **Add…** → вставить URL под свою версию EDT:

   | Ваша 1C:EDT | URL update site |
   |-------------|-----------------|
   | **2026.1**  | `https://jimmo910.github.io/edt-plugin-pack/2026.1/` |
   | **2026.2**  | `https://jimmo910.github.io/edt-plugin-pack/2026.2/` |

2. Отметить категорию **«Набор плагинов 1C:EDT»** — поставит все плагины разом
   (категория **«EDT MCP (AGPL-3.0)»** — опционально).
3. Внизу **снять** галку «Обращаться ко всем сайтам обновления…».
4. Далее → принять лицензии → «Install anyway» на предупреждении о подписи → перезапустить EDT.

### Вариант 2 — офлайн-архив (для машин без интернета)
На странице [Releases](https://github.com/Jimmo910/edt-plugin-pack/releases) — последний релиз `vX.Y.Z`
**с двумя архивами**. Скачайте под свою версию EDT:

| Ваша 1C:EDT | Файл |
|-------------|------|
| **2026.1**  | `EDT-Plugin-Pack-2026.1-X.Y.Z.zip` |
| **2026.2**  | `EDT-Plugin-Pack-2026.2-X.Y.Z.zip` |

Установка та же, только на шаге 1: **Add… → Archive…** → выбрать скачанный архив.

### YAXUnit (для запуска тестов)
`YAXUnit` — это **расширение конфигурации 1С** (`.cfe`), а не плагин EDT. Из папки `yaxunit/` в архиве
загрузите `.cfe` в информационную базу (Конфигуратор → Расширения конфигурации). Нужен для `edt-test-runner`.

## FAQ
- **«Невозможно найти … .zip!/» при установке.** Указывайте архив через **Add → Archive**; архив самодостаточен
  (p2-репозиторий лежит в корне, папки `yaxunit/`/`licenses/` Eclipse игнорирует).
- **Просит «Install anyway» из-за подписи.** Это нормально — community-плагины не подписаны.
- **Зачем снимать «обращаться ко всем сайтам».** Чтобы p2 не опрашивал посторонние (возможно мёртвые)
  сайты из вашего списка и ставил только из этого архива.
- **Плагин не нужен / мешает.** Снять можно через Справка → О программе → Сведения об установке → Uninstall.
- **Не нашли нужный плагин / что-то не ставится.** Заведите [issue](https://github.com/Jimmo910/edt-plugin-pack/issues).

## Лицензии
Включаются только плагины, чьи лицензии допускают повторное распространение. Тексты — в `licenses/`,
сводка по дистрибутиву — `licenses/NOTICES.md`. EDT MCP (AGPL-3.0) включён неизменённым, отдельной
категорией, со ссылкой на исходники (AGPL §6). Сам инструментарий репозитория — под [MIT](LICENSE).

---

## Для сопровождающих

### Сборка из исходников
```powershell
pwsh -NoProfile -File scripts/build.ps1 -Target 2026.1   # или -Target 2026.2
```
Результат — `build/dist/EDT-Plugin-Pack-<edtLine>-<версия>.zip`. Проверка установки на копии EDT:
`scripts/verify.ps1` (Windows) или `scripts/verify.sh` (Linux). Папка `build/` — рабочая, в git не попадает.
`p2/category.xml` генерируется при сборке (в git его нет).

### Как добавить плагин или версию EDT
Добавить **плагин** — объект в `plugins[]` в `manifests/2026.1.json` и `manifests/2026.2.json`:
`id`, `name`, `version`, `license`, `category` (`main`/`mcp`), `featureId` (точный id фичи →
IU `<featureId>.feature.group`), `repoUrl`, блок `source` (`zip` | `gitlab-package` | `p2-publish`) и
блок `update` для авто-обновления (`gh-release` | `gh-jars` | `gitlab-package`; `hold:true` — заморозить версию).
Правило: **без файла LICENSE в апстриме плагин не добавляем** (см. отложенный `edt.cf_builder`).
Проверьте локально `build.ps1 -Target … && verify.ps1`.

Добавить **версию EDT** (напр. 2027.1): создать `manifests/2027.1.json`, установить эту EDT на self-hosted
runner, добавить `'2027.1'` в матрицы `target` в обоих workflow. Остальное (описание релиза, таблица версий
в README, публикация на Pages) выводится из `manifests/*.json` и правок не требует.
Снятие линии — обратные действия: удалить манифест и убрать из матриц.

### CI / автоматизация
Матрица `[2026.1, 2026.2]`: **build** (облачный Windows + ванильный Eclipse, без 1C:EDT) → **verify**
(self-hosted runner с реальной 1C:EDT обеих версий) → **release** (один релиз `vX.Y.Z` с двумя архивами,
только при успешном verify). **Auto-update** (пн 06:00 UTC + кнопка) сверяет версии с upstream, собирает,
проверяет на реальной EDT и при успехе выпускает релиз; несовместимая версия release не проходит — заводится issue.

### Политика версий и `hold`
Версия пакета (`package.version`) единая для всех архивов, патч бампается авто-обновлением. Линии
обновляются независимо, поэтому перед сборкой версия выравнивается по всем манифестам
(`scripts/sync-version.ps1`, job `sync`) — имя архива содержит версию, разъехаться она не должна.
`update.hold:true` фиксирует версию плагина. Сейчас зафиксирован: **edt-editing 0.6.0 в линии 2026.1**
(0.7.0 импортирует `com.google.common.cache [33.5.0,34.0.0)`, а 2026.1 несёт Guava 32.1.3;
в 2026.2 — 33.5.0, там стоит 0.7.0).
