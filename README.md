# dotfiles

Управляются через [chezmoi](https://chezmoi.io) — менеджер dotfiles, который хранит
исходники в `~/.local/share/chezmoi` и по команде разворачивает их в `~`.

## Содержание

- [Как устроен chezmoi](#как-устроен-chezmoi)
- [Быстрый старт на новой машине](#быстрый-старт-на-новой-машине)
- [Управление файлами](#управление-файлами)
  - [Добавить файл под управление](#добавить-файл-под-управление)
  - [Удалить файл из управления](#удалить-файл-из-управления)
  - [Шаблоны (Go templates)](#шаблоны-go-templates)
  - [Сделать существующий файл шаблоном](#сделать-существующий-файл-шаблоном)
- [Основные команды](#основные-команды)
- [Состав репозитория](#состав-репозитория)
- [Полезное](#полезное)

## Как устроен chezmoi

Исходники dotfiles хранятся в `~/.local/share/chezmoi`.
chezmoi изменяет имена файлов по правилам:

| В `~` | В `~/.local/share/chezmoi` |
|-------|---------------------------|
| `.gitconfig` | `dot_gitconfig` |
| `~/.config/foo` | `dot_config/foo` |
| `.ssh/known_hosts` | `dot_ssh/known_hosts` |

Жизненный цикл файла:

1. `chezmoi add ~/.config/foo` — взять файл под управление
2. `chezmoi edit ~/.config/foo` — изменить исходник (не трогая файл в `~`)
3. `chezmoi apply` — записать изменения в `~`

Файлы с суффиксом `.tmpl` перед применением обрабатываются как шаблоны Go.

## Быстрый старт на новой машине

```sh
# Установить chezmoi
sh -c "$(curl -fsLS https://get.chezmoi.io)" -- -b "~/.local/bin"

# Клонировать
chezmoi init https://github.com/CitRUSprod/dotfiles.git

# Создать конфигурацию из примера (обязательно — без неё шаблоны не сработают)
cp ~/.local/share/chezmoi/chezmoi.example.toml ~/.config/chezmoi/chezmoi.toml
nano ~/.config/chezmoi/chezmoi.toml

# Применить
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

### Удалить файл из управления

```sh
chezmoi forget ~/.config/opencode/opencode.jsonc   # забыть файл
rm "~/.local/share/chezmoi/dot_config/opencode/opencode.jsonc.tmpl"  # удалить исходник
chezmoi apply                                      # (опционально) удалить файл из ~
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

Шаблоны поддерживают условия, циклы и фильтры.
Встроенные переменные `chezmoi` (например, `.chezmoi.os`, `.chezmoi.arch`) доступны без объявления:

```gotemplate
{{ if eq .chezmoi.os "linux" }}
some_linux_option = true
{{ else if eq .chezmoi.os "darwin" }}
some_macos_option = true
{{ end }}

# Значение по умолчанию через фильтр
name = {{ .git.name | default "Unknown" }}
```

Проверить результат шаблона без записи в `~`:

```sh
chezmoi cat ~/.gitconfig
chezmoi diff
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

| Путь в домашней папке | Путь в chezmoi |
|----------------------|---------------|
| `~/.gitconfig` | `dot_gitconfig.tmpl` |
| `~/.config/opencode/opencode.jsonc` | `dot_config/opencode/opencode.jsonc.tmpl` |

## Полезное

- Подсказка по шаблонам: `chezmoi help template`
- Проверить, что получится на выходе: `chezmoi cat ~/.gitconfig`
