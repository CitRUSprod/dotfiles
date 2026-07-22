# dotfiles

Управляются через [chezmoi](https://chezmoi.io) — менеджер dotfiles, который хранит
исходники в `~/.local/share/chezmoi` и по команде разворачивает их в `~`.

## Быстрый старт на новой машине

```sh
# Установить chezmoi
sh -c "$(curl -fsLS https://get.chezmoi.io)" -- -b "$HOME/.local/bin"

# Клонировать и применить (если репозиторий на GitHub)
chezmoi init https://github.com/USER/dotfiles.git

# Вручную: скопировать репозиторий и применить
git clone <url> ~/.local/share/chezmoi
chezmoi apply
```

## Управление файлами

### Добавить файл под управление

```sh
chezmoi add ~/.config/opencode/opencode.jsonc
# → создаст dot_config/opencode/opencode.jsonc
```

После этого можно отредактировать исходник и применить:

```sh
chezmoi apply
```

Если нужно изменить файл, не трогая целевой:

```sh
chezmoi edit ~/.config/opencode/opencode.jsonc
```

### Шаблоны (Go templates)

Файлы с расширением `.tmpl` обрабатываются как шаблоны.
Переменные берутся из секции `[data]` в `~/.config/chezmoi/chezmoi.toml`.

```toml
[data]
  [data.git]
    name = "John Doe"
    email = "john@example.com"
  [data.opencode]
    [data.opencode.omniroute]
      apiKey = "sk-..."
      baseURL = "https://api.example.com/v1"
```

В шаблоне переменные подставляются так:

```gotemplate
name = {{ .git.name }}
baseURL = "{{ .opencode.omniroute.baseURL }}"
```

### Сделать существующий файл шаблоном

```sh
chezmoi add --template ~/.config/opencode/opencode.jsonc
# → создаст dot_config/opencode/opencode.jsonc.tmpl
```

## Основные команды

| Команда | Что делает |
|---------|-----------|
| `chezmoi diff` | Показать отличия между исходником и целевым файлом |
| `chezmoi apply` | Применить все изменения — записать файлы в `~` |
| `chezmoi status` | Показать статус всех файлов |
| `chezmoi add <path>` | Добавить файл из `~` под управление |
| `chezmoi edit <path>` | Отредактировать исходник (в `$EDITOR`) |
| `chezmoi update` | Подтянуть изменения из git и применить |
| `chezmoi cd` | Перейти в директорию репозитория |
| `chezmoi unmanaged` | Показать файлы в `~`, не под управлением |

## Состав репозитория

| Файл | Назначение |
|------|-----------|
| `dot_gitconfig.tmpl` | Шаблон `~/.gitconfig` — имя и email |
| `dot_config/opencode/opencode.jsonc.tmpl` | Шаблон `~/.config/opencode/opencode.jsonc` — провайдер OmniRoute |
| `README.md` | Этот файл |

## Полезное

- Подсказка по шаблонам: `chezmoi help template`
- Проверить, что получится на выходе: `chezmoi cat ~/.gitconfig`
