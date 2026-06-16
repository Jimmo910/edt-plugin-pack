# Набор плагинов 1C:EDT

[![Build, Verify & Release](https://github.com/Jimmo910/edt-plugin-pack/actions/workflows/build-release.yml/badge.svg)](https://github.com/Jimmo910/edt-plugin-pack/actions/workflows/build-release.yml)
[![Auto-update plugins](https://github.com/Jimmo910/edt-plugin-pack/actions/workflows/auto-update.yml/badge.svg)](https://github.com/Jimmo910/edt-plugin-pack/actions/workflows/auto-update.yml)
[![1C:EDT](https://img.shields.io/badge/1C%3AEDT-2025.2%20%7C%202026.1-blue)](https://edt.1c.ru/)

Единый офлайн-набор полезных **сторонних** плагинов для 1C:EDT. Один архив = один p2 update site,
где галочкой на категории ставятся сразу все плагины. Поддерживаются **две линейки EDT — 2025.2 и 2026.1**,
под каждую собирается свой архив, проверенный установкой на реальную EDT этой версии.

## Скачать

На странице [Releases](https://github.com/Jimmo910/edt-plugin-pack/releases) — **последний релиз `vX.Y.Z`
с двумя архивами**. Скачайте тот, что под вашу версию 1C:EDT:

| Ваша 1C:EDT | Файл |
|-------------|------|
| **2025.2**  | `EDT-Plugin-Pack-2025.2-X.Y.Z.zip` |
| **2026.1**  | `EDT-Plugin-Pack-2026.1-X.Y.Z.zip` |

Оба архива **проверены установкой на реальную 1C:EDT соответствующей версии** (self-hosted runner).

## Установка

### Плагины EDT
1. В 1C:EDT: **Справка → Установить новое ПО…** (Install New Software) → **Add… → Archive…**
   и выбрать скачанный `EDT-Plugin-Pack-<версия>.zip`.
2. Отметить категорию **«Набор плагинов 1C:EDT»** — она поставит все плагины разом.
   Категория **«EDT MCP (AGPL-3.0)»** — опционально (см. лицензии ниже).
3. Снизу **снять** галку «Обращаться ко всем сайтам обновления…» (чтобы p2 не опрашивал
   посторонние, возможно мёртвые, сайты — ставим только из этого архива).
4. Принять лицензии, «Install anyway» на предупреждении о неподписанном содержимом, перезапустить EDT.

Архив самодостаточен: в корне — p2-репозиторий (`content.jar`/`artifacts.jar`/`plugins/`/`features/`),
рядом папки `yaxunit/` и `licenses/` (Eclipse их при установке игнорирует).

### YAXUnit (нужен для edt-test-runner)
`YAXUnit` — это **расширение конфигурации 1С** (`.cfe`), а не плагин EDT. Файл из папки
`yaxunit/` загрузить в информационную базу (Конфигуратор → Расширения конфигурации) или
импортировать в EDT-проект. Подробнее — `yaxunit/README.txt`.

## Состав пакета

| Плагин | Версия | Лицензия | Категория | Источник |
|--------|--------|----------|-----------|----------|
| EDT Extension Tweaks | 1.1.2 | EPL-2.0 | основная | [Xelgo/edt-extension-tweaks](https://github.com/Xelgo/edt-extension-tweaks) |
| Disable Editing Plugin | 0.6.0 | EPL-2.0 | основная | [marmyshev/edt-editing](https://gitlab.com/marmyshev/edt-editing) |
| EDT Test Runner | 25.01 | Apache-2.0 | основная | [bia-technologies/edt-test-runner](https://github.com/bia-technologies/edt-test-runner) |
| Configuration Repository (PluginEDT) | 0.4.0 | EPL-2.0 | основная | [ZigRinat85/PluginEDT](https://github.com/ZigRinat85/PluginEDT) |
| AnyEdit Tools (сравнение, буфер, автоформат) | 2.7.3 | EPL-2.0 | основная | [iloveeclipse/anyedittools](https://github.com/iloveeclipse/anyedittools) |
| IndentGuide (направляющие отступов) | 2.2.5 | MIT | основная | [marmyshev/indent-guide](https://github.com/marmyshev/indent-guide) |
| EDT MCP Server | 2.3.1 | **AGPL-3.0** | **EDT MCP (отдельная)** | [DitriXNew/EDT-MCP](https://github.com/DitriXNew/EDT-MCP) |
| YAXUnit (расширение 1С, не плагин) | 25.12 | Apache-2.0 | в архиве `yaxunit/` | [bia-technologies/yaxunit](https://github.com/bia-technologies/yaxunit) |

Версии пинуются отдельно для каждой линейки EDT (`manifests/2025.2.json`, `manifests/2026.1.json`).
Сейчас составы совпадают; **edt-editing зафиксирован на 0.6.0** (`hold`): 0.7.0 требует Guava 33.5,
которой нет ни в 2025.2, ни в 2026.1 — verify это подтвердил.

**Отложен:** `edt.cf_builder` (импорт/экспорт CF/CFE) — технически ставится, но в репозитории
**нет файла LICENSE**, распространять в составе сборки нельзя (ждём ответа автора по issue).

## CI / автоматизация

Конвейер на GitHub Actions, по каждой линейке EDT (матрица `[2025.2, 2026.1]`):

- **Build, Verify & Release** (`build-release.yml`, по кнопке): `build` (облачный Windows-раннер,
  ванильный Eclipse) → `verify` (**self-hosted runner с реальной 1C:EDT**, установка набора через
  p2 director) → `release` (только при успешном verify; отдельный релиз на каждую линейку).
- **Auto-update plugins** (`auto-update.yml`, пн 06:00 UTC + по кнопке): сверяет версии плагинов
  с upstream (GitHub/GitLab), бампит манифест → собирает → **verify на реальной EDT (gate)** →
  при успехе коммитит бамп и публикует релиз; если новая версия не ставится — релиза нет,
  заводится issue. Плагины с `update.hold=true` авто-бамп пропускают.

Верификация на реальной EDT выполняется на self-hosted runner с установленными 1C:EDT 2025.2 и 2026.1.

## Сборка из исходников (локально)

Требуется установленная 1C:EDT (любая из линеек — как источник штатных p2-инструментов).

```powershell
pwsh -NoProfile -File scripts/build.ps1 -Target 2025.2   # или -Target 2026.1
```

Результат — `build/dist/EDT-Plugin-Pack-<target>-<версия>.zip`. Папка `build/` — рабочая, в git не попадает.
Состав правится в `manifests/<target>.json`. Проверка установки: `scripts/verify.ps1` (Windows) или
`scripts/verify.sh` (Linux, self-hosted).

## Лицензии
В пакет включаются только плагины, чьи лицензии допускают повторное распространение.
Тексты лицензий и перечень компонентов — в `licenses/` (внутри дистрибутива — `licenses/NOTICES.md`).
EDT MCP (AGPL-3.0) включён неизменённым, отдельной опциональной категорией, со ссылкой на исходники (AGPL §6).
