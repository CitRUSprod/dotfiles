#!/usr/bin/env bash
set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

info()  { echo -e "${YELLOW}$*${NC}"; }
ok()    { echo -e "${GREEN}$*${NC}"; }
err()   { echo -e "${RED}$*${NC}"; }

DRY_RUN=false
AUTO_YES=false
for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=true ;;
        -y|--yes) AUTO_YES=true ;;
    esac
done

if git show-ref --verify --quiet refs/heads/main; then
    BASE="main"
elif git show-ref --verify --quiet refs/heads/master; then
    BASE="master"
else
    err "❌ Базовая ветка (main/master) не найдена"
    exit 1
fi
info "Базовая ветка: $BASE"

if [ -n "$(git status --porcelain)" ]; then
    err "❌ Есть незакоммиченные изменения. Зафиксируйте или отложите их (git stash)."
    exit 1
fi

CURRENT=$(git branch --show-current)
NEED_SWITCH=false
if [ "$CURRENT" != "$BASE" ]; then
    NEED_SWITCH=true
    info "Переключаюсь на $BASE..."
    git checkout "$BASE"
fi

info "Обновляю $BASE..."
git pull --ff-only
info "Обновляю remote references..."
git fetch origin --prune

PROTECTED="^(main|master|HEAD)$"
if [ "$NEED_SWITCH" = true ]; then
    PROTECTED="^(main|master|HEAD|$CURRENT)$"
fi

HAS_ORIGIN=false
if git remote get-url origin &>/dev/null; then
    HAS_ORIGIN=true
fi

STAGE1=()
while IFS= read -r branch; do
    branch="${branch#\* }"
    branch="${branch#"${branch%%[![:space:]]*}"}"
    branch="${branch%"${branch##*[![:space:]]}"}"
    [[ -z "$branch" ]] && continue
    [[ "$branch" =~ $PROTECTED ]] && continue
    STAGE1+=("$branch")
done < <(git branch --merged "$BASE")

STAGE2=()
while IFS= read -r branch; do
    branch="${branch#\* }"
    branch="${branch#"${branch%%[![:space:]]*}"}"
    branch="${branch%"${branch##*[![:space:]]}"}"
    [[ -z "$branch" ]] && continue
    [[ "$branch" =~ $PROTECTED ]] && continue

    skip=false
    for b in "${STAGE1[@]}"; do
        if [ "$b" = "$branch" ]; then skip=true; break; fi
    done
    if [ "$skip" = true ]; then continue; fi

    if git diff "$BASE" "$branch" --exit-code --quiet 2>/dev/null; then
        STAGE2+=("$branch")
    fi
done < <(git branch --list)

ALL=("${STAGE1[@]}" "${STAGE2[@]}")
if [ ${#ALL[@]} -eq 0 ]; then
    ok "Нет влитых веток для удаления."
else
    info "Найдено веток на удаление: ${#ALL[@]}"
    echo -e "${YELLOW}---${NC}"

    for branch in "${STAGE1[@]}"; do
        echo -e "  ${YELLOW}--merged:${NC} $branch"
    done
    for branch in "${STAGE2[@]}"; do
        echo -e "  ${YELLOW}diff:     ${NC} $branch"
    done
    echo -e "${YELLOW}---${NC}"

    SHOULD_DELETE=false
    if [ "$DRY_RUN" = true ]; then
        ok "Dry-run: ничего не удалено."
    elif [ "$AUTO_YES" = true ]; then
        SHOULD_DELETE=true
    else
        read -r -p "Удалить эти ${#ALL[@]} веток? [y/N] " confirm
        if [[ "$confirm" =~ ^[yYДд] ]]; then
            SHOULD_DELETE=true
        else
            info "Отменено."
        fi
    fi

    if [ "$SHOULD_DELETE" = true ]; then
        for branch in "${STAGE1[@]}"; do
            echo -e "  ${YELLOW}--merged:${NC} $branch"
            if ! git branch -d "$branch" 2>/dev/null; then
                err "✗ Не удалось удалить локальную ветку $branch"
            fi
            if [ "$HAS_ORIGIN" = true ]; then
                git push origin --delete "$branch" 2>&1 || err "✗ Ошибка удаления $branch на remote (см. выше)"
            fi
        done

        for branch in "${STAGE2[@]}"; do
            echo -e "  ${YELLOW}diff:     ${NC} $branch"
            if ! git branch -d "$branch" 2>/dev/null && ! git branch -D "$branch" 2>/dev/null; then
                err "✗ Не удалось удалить локальную ветку $branch"
            fi
            if [ "$HAS_ORIGIN" = true ]; then
                git push origin --delete "$branch" 2>&1 || err "✗ Ошибка удаления $branch на remote (см. выше)"
            fi
        done

        ok "Удалено веток: ${#ALL[@]} (--merged: ${#STAGE1[@]}, diff: ${#STAGE2[@]})"
    fi
fi

if [ "$NEED_SWITCH" = true ]; then
    info "Возвращаюсь на $CURRENT..."
    git checkout "$CURRENT"
fi
