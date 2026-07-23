#!/usr/bin/env bash
set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

info()  { echo -e "${YELLOW}$*${NC}"; }
ok()    { echo -e "${GREEN}$*${NC}"; }
err()   { echo -e "${RED}$*${NC}"; }

escape_regex() { sed 's/[.[\*^$()+?{|\\]/\\&/g' <<< "$1"; }

DRY_RUN=false
for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=true ;;
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

CURRENT=$(git branch --show-current)
PROTECTED="^(main|master|HEAD)$"
if [ "$CURRENT" != "$BASE" ]; then
    PROTECTED="^(main|master|HEAD|$(escape_regex "$CURRENT"))$"
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
    exit 0
fi

if [ "$DRY_RUN" = true ]; then
    info "Найдено веток на удаление: ${#ALL[@]}"
    for branch in "${STAGE1[@]}"; do
        echo -e "  ${YELLOW}--merged:${NC} $branch"
    done
    for branch in "${STAGE2[@]}"; do
        echo -e "  ${YELLOW}diff:     ${NC} $branch"
    done
    ok "Dry-run: ничего не удалено."
    exit 0
fi

if [ -n "$(git status --porcelain)" ]; then
    err "❌ Есть незакоммиченные изменения. Зафиксируйте или отложите их (git stash)."
    exit 1
fi

NEED_SWITCH=false
if [ "$CURRENT" != "$BASE" ]; then
    NEED_SWITCH=true
    info "Переключаюсь на $BASE..."
    git checkout "$BASE"
fi

trap 'if [ "$NEED_SWITCH" = true ]; then git checkout "$CURRENT" 2>/dev/null; fi' EXIT

info "Обновляю $BASE..."
git pull --ff-only
info "Обновляю remote references..."
git fetch origin --prune

DELETED=0
FAILED_LOCAL=()
FAILED_REMOTE=()

for branch in "${STAGE1[@]}"; do
    echo -e "  ${YELLOW}--merged:${NC} $branch"

    if [ "$HAS_ORIGIN" = true ]; then
        if git push origin --delete "$branch" 2>&1; then
            if git branch -d "$branch"; then
                ((DELETED++))
            else
                err "✗ $branch удалена на remote, но не найдена локально"
            fi
        else
            err "✗ Не удалось удалить $branch на remote"
            FAILED_REMOTE+=("$branch")
        fi
    else
        if git branch -d "$branch"; then
            ((DELETED++))
        else
            err "✗ Не удалось удалить локальную ветку $branch"
            FAILED_LOCAL+=("$branch")
        fi
    fi
done

for branch in "${STAGE2[@]}"; do
    echo -e "  ${YELLOW}diff:     ${NC} $branch"

    LOCAL_OK=false
    if [ "$HAS_ORIGIN" = true ]; then
        if git push origin --delete "$branch" 2>&1; then
            if git branch -d "$branch" 2>/dev/null; then
                LOCAL_OK=true
            elif [ "$(git rev-list --count "$BASE..$branch" 2>/dev/null)" -eq 0 ]; then
                git branch -D "$branch" && LOCAL_OK=true
            fi
            if [ "$LOCAL_OK" = true ]; then
                ((DELETED++))
            else
                err "✗ $branch удалена на remote, но локально не удалена (содержит незалитые коммиты)"
                FAILED_LOCAL+=("$branch")
            fi
        else
            err "✗ Не удалось удалить $branch на remote"
            FAILED_REMOTE+=("$branch")
        fi
    else
        if git branch -d "$branch" 2>/dev/null; then
            LOCAL_OK=true
        elif [ "$(git rev-list --count "$BASE..$branch" 2>/dev/null)" -eq 0 ]; then
            git branch -D "$branch" && LOCAL_OK=true
        fi
        if [ "$LOCAL_OK" = true ]; then
            ((DELETED++))
        else
            err "✗ Не удалось удалить локальную ветку $branch"
            FAILED_LOCAL+=("$branch")
        fi
    fi
done

msg="Удалено веток: $DELETED"
if [ ${#FAILED_REMOTE[@]} -gt 0 ]; then
    msg+=", ошибок remote: ${#FAILED_REMOTE[@]}"
fi
if [ ${#FAILED_LOCAL[@]} -gt 0 ]; then
    msg+=", ошибок local: ${#FAILED_LOCAL[@]}"
fi
ok "$msg"
