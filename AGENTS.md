# dotfiles

Репозиторий управляется через [chezmoi](https://chezmoi.io).
Исходники в `~/.local/share/chezmoi`, разворачиваются в `~` командой `chezmoi apply -v`.

## Как устроены файлы

- `dot_` в начале имени заменяется на `.` (например, `dot_gitconfig` → `.gitconfig`)
- `dot_config/` → `~/.config/`
- `.tmpl` — файл обрабатывается как Go-шаблон перед применением
- Переменные для шаблонов берутся из `~/.config/chezmoi/chezmoi.toml`, секция `[data]`
- `.chezmoiignore` исключает корневые README, .editorconfig, chezmoi.example.toml и сам AGENTS.md из `chezmoi apply`
- При добавлении нового файла под управление — обнови таблицу «Состав dotfiles» в README.md

## Основные команды

| Команда | Назначение |
|---------|------------|
| `chezmoi diff` | Показать отличия исходников от целевых файлов |
| `chezmoi apply -v` | Применить изменения — записать в `~` |
| `chezmoi cat ~/.gitconfig` | Проверить результат шаблона |
| `chezmoi edit ~/.config/foo` | Отредактировать исходник, не трогая файл в `~` |
| `chezmoi add ~/.config/foo` | Взять файл под управление |
| `chezmoi status` | Показать статус всех файлов |
| `chezmoi unmanaged` | Показать файлы в `~` не под управлением |

После редактирования любого исходника нужно выполнить `chezmoi apply -v`.
Перед этим полезно проверить `chezmoi diff`.

## OpenCode

Кастомные команды и агенты живут в `dot_config/opencode/exact_commands/` и `dot_config/opencode/exact_agents/`.
Они разворачиваются в `~/.config/opencode/commands/` и `~/.config/opencode/agents/`.
Провайдер настроен на OmniRoute через шаблон `dot_config/opencode/opencode.jsonc.tmpl`.

## Git

- Язык коммитов — русский
- Conventional commits: `feat:`, `fix:`, `docs:`, `refactor:`, `chore:`, и т.д.
- Никогда не коммитить в main/master — всегда создавать новую ветку
- `git add` выполняется вручную пользователем
- `git commit` без `--no-verify`

## Тесты, CI, сборка

В репозитории нет тестов, CI, линтеров и сборки.
Основной способ проверки корректности — `chezmoi diff`.
