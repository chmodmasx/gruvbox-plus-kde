#!/usr/bin/env bash
# Verify actual KF6 icon resolution, not just configuration.
test_icons() {
    mkdir -p "$XDG_DATA_HOME/icons" || return 1
    local v icon resolved
    for v in Dark Light; do
        test -f "$src/.ci-icons/Gruvbox-Plus-$v/index.theme" || return 1
        ln -s "$src/.ci-icons/Gruvbox-Plus-$v" "$XDG_DATA_HOME/icons/Gruvbox-Plus-$v" || return 1
    done
    : >"$out/icons.txt"
    for icon in folder document-open document-save edit-copy; do
        resolved="$(kiconfinder6 "$icon")" || return 1
        printf '%s\t%s\n' "$icon" "$resolved" | tee -a "$out/icons.txt"
        test -f "$resolved" || return 1
        case "$resolved" in
            */Gruvbox-Plus-Dark/*|*/Gruvbox-Plus-Light/*) ;;
            *) echo "Unexpected fallback for $icon"; return 1 ;;
        esac
    done
}
