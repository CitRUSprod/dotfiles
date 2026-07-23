#!/usr/bin/env bash
set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

info()  { echo -e "${YELLOW}$*${NC}"; }
ok()    { echo -e "${GREEN}$*${NC}"; }
err()   { echo -e "${RED}$*${NC}"; }

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

STAGE1=()
while IFS= read -r branch; do
    branch="${branch#\* }"
    branch="${branch#"${branch%%[![:space:]]*}"}"
    branch="${branch%"${branch##*[![:space:]]}"}"
    [[ -z "$branch" ]] && continue
    [[ "$branch" =~ $PROTECTED ]] && continue
    STAGE1+=("$branch")
done < <(git branch --merged "$BASE" | sed 's/^..//')

STAGE2=()
while IFS= read -r branch; do
    branch="${branch#"${branch%%[![:space:]]*}"}"
    branch="${branch%"${branch##*[![:space:]]}"}"
    [[ -z "$branch" ]] && continue
    [[ "$branch" =~ $PROTECTED ]] && continue

    skip=false
    for b in "${STAGE1[@]}"; do
        if [ "$b" = "$branch" ]; then skip=true; break; fi
    done
    $skip && continue

    if git rev-parse --abbrev-ref "@{upstream}" &>/dev/null 2>&1 && \
       git diff "$BASE"..."$branch" --exit-code --quiet 2>/dev/null; then
        STAGE2+=("$branch")
    fi
done < <(git branch --list | sed 's/^..//')

ALL=("${STAGE1[@]}" "${STAGE2[@]}")
if [ ${#ALL[@]} -eq 0 ]; then
    ok "Нет влитых веток для удаления."
else
    info "Найдено веток на удаление: ${#ALL[@]}"
    echo -e "${YELLOW}---${NC}"

    for branch in "${STAGE1[@]}"; do
        echo -e "  ${YELLOW}--merged:${NC} $branch"
        git push origin --delete "$branch" 2>/dev/null || echo "    (удалённая уже удалена)"
        git branch -d "$branch" 2>/dev/null || echo "    (локальная уже удалена)"
    done

    for branch in "${STAGE2[@]}"; do
        echo -e "  ${YELLOW}diff:     ${NC} $branch"
        git push origin --delete "$branch" 2>/dev/null || echo "    (удалённая уже удалена)"
        git branch -d "$branch" 2>/dev/null || echo "    (локальная уже удалена)"
    done

    echo -e "${YELLOW}---${NC}"
    ok "Удалено веток: ${#ALL[@]} (--merged: ${#STAGE1[@]}, diff: ${#STAGE2[@]})"
fi

if [ "$NEED_SWITCH" = true ]; then
    info "Возвращаюсь на $CURRENT..."
    git checkout "$CURRENT"
fi
