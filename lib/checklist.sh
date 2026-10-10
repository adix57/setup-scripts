#!/usr/bin/env bash

# Interactive checklist. Prompts the user to toggle items on/off.
#
# Usage:
#   selection=$(checklist "Title" "*default-checked item" "plain item" ...)
#
# Prefix an item with '*' to mark it checked by default.
# Selected items are printed to stdout, one per line (sans '*').
# All interactive UI is written to stderr, so command substitution
# captures only the result (never escape sequences).
# If stdin is not a TTY (e.g. piped), returns the default-checked items
# without prompting.
#
# Keys: ↑/↓ move, Space toggle, Enter confirm, q cancel (returns nothing).

checklist() {
    local prompt="${1:-Select:}"
    shift
    local items=("$@")
    local n=${#items[@]}

    local checked=()
    local clean=()
    local i k=0
    for ((i = 0; i < n; i++)); do
        if [[ "${items[$i]}" == \** ]]; then
            checked[$k]=1
            clean[$k]="${items[$i]:1}"
        else
            checked[$k]=0
            clean[$k]="${items[$i]}"
        fi
        ((k++))
    done
    n=${#clean[@]}
    [ "$n" -eq 0 ] && return 1

    if [ ! -t 0 ]; then
        for ((i = 0; i < n; i++)); do
            [ "${checked[$i]}" -eq 1 ] && printf '%s\n' "${clean[$i]}"
        done
        return 0
    fi

    local cur=0 key a b
    local oldterm
    oldterm=$(stty -g)
    trap 'printf "\033[?25h\033[2J\033[H" >&2; stty "$oldterm"' RETURN

    stty -echo -icanon -icrnl min 1 time 0
    printf '\033[?25l' >&2

    render() {
        printf '\033[2J\033[H' >&2
        printf '\n  %s\n\n' "$prompt" >&2
        for ((i = 0; i < n; i++)); do
            if [ "$i" -eq "$cur" ]; then
                printf '\033[7m' >&2
            fi
            if [ "${checked[$i]}" -eq 1 ]; then
                printf '  [x] %s' "${clean[$i]}" >&2
            else
                printf '  [ ] %s' "${clean[$i]}" >&2
            fi
            printf '\033[0m\n' >&2
        done
        printf '\n  ↑/↓ move  Space toggle  Enter confirm  q quit\n' >&2
    }

    render
    while :; do
        IFS= read -rsN1 key </dev/tty || continue
        case "$key" in
            $'\e')
                read -rsN1 -t 0.15 a </dev/tty || true
                read -rsN1 -t 0.15 b </dev/tty || true
                case "$a$b" in
                    '[A') [ "$cur" -gt 0 ] && ((cur--)) ;;
                    '[B') [ "$cur" -lt $((n - 1)) ] && ((cur++)) ;;
                esac
                ;;
            ' ')
                checked[$cur]=$((1 - checked[$cur]))
                ;;
            j | J)
                [ "$cur" -lt $((n - 1)) ] && ((cur++))
                ;;
            k | K)
                [ "$cur" -gt 0 ] && ((cur--))
                ;;
            $'\r' | $'\n')
                break
                ;;
            q | Q)
                printf '\033[2J\033[H' >&2
                return 1
                ;;
        esac
        render
    done

    printf '\033[2J\033[H' >&2
    local out=()
    for ((i = 0; i < n; i++)); do
        [ "${checked[$i]}" -eq 1 ] && out+=("${clean[$i]}")
    done
    printf '%s\n' "${out[@]}"
    return 0
}

# Simple yes/no confirmation. Returns 0 on yes, 1 on no.
# Second argument is the default for empty or non-interactive input: "yes" or "no".
ask_yesno() {
    local prompt="${1:-Proceed?}"
    local default="${2:-yes}"
    local hint='[Y/n]'
    [ "$default" = "no" ] && hint='[y/N]'
    local ans
    printf '%s %s ' "$prompt" "$hint" >&2
    if [ ! -t 0 ]; then
        printf '\n' >&2
        [ "$default" = "no" ] && return 1
        return 0
    fi
    IFS= read -r ans || true
    case "${ans,,}" in
        n | no) return 1 ;;
        "")
            if [ "$default" = "no" ]; then
                return 1
            fi
            ;;
    esac
    return 0
}