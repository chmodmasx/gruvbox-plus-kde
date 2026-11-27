#!/usr/bin/env bash
# Install exact resources from the tested revision into a disposable user.
set -euo pipefail
src="$1"; out="$2"; variant="$3"; backend="$4"
id="GruvboxPlus$variant"
export LANG=C.UTF-8 XDG_DATA_HOME="$HOME/.local/share" XDG_CONFIG_HOME="$HOME/.config"
export XDG_CACHE_HOME="$HOME/.cache" XDG_RUNTIME_DIR="$HOME/runtime"
export XDG_CONFIG_DIRS="$XDG_CONFIG_HOME/kdedefaults:/etc/xdg"
export XDG_SESSION_TYPE=wayland XDG_CURRENT_DESKTOP=KDE KDE_FULL_SESSION=true XDG_MENU_PREFIX=plasma-
export QT_QPA_PLATFORM=offscreen LIBGL_ALWAYS_SOFTWARE=1
mkdir -p "$XDG_RUNTIME_DIR" "$XDG_CACHE_HOME" "$XDG_CONFIG_HOME/kdedefaults" "$out"
chmod 700 "$XDG_RUNTIME_DIR"
exec > >(tee "$out/probe.log") 2>&1
kwin_pid= shell_pid= app_pid= splash_pid= weston_pid= pipewire_pid=
cleanup() {
    for pid in "$splash_pid" "$app_pid" "$shell_pid" "$kwin_pid" "$weston_pid" "$pipewire_pid"; do
        if [[ -n "$pid" ]]; then kill "$pid" 2>/dev/null || true; fi
    done
    wait || true
    mkdir -p "$out/config"
    cp -a "$XDG_CONFIG_HOME/." "$out/config/" || true
}
trap cleanup EXIT
version="$(dpkg-query -W -f='${Version}' plasma-workspace)"
case "${version#*:}" in 6.6.*) ;; *) echo "Wrong Plasma: $version"; exit 2 ;; esac
echo "Plasma $version / $id"
dpkg-query -W plasma-workspace kwin-wayland kwin-style-aurorae
dpkg -L kwin-style-aurorae >"$out/aurorae-files.txt"
status="$out/results.tsv"
printf 'check\tresult\n' >"$status"
probe() {
    local name="$1"; shift
    local code=0
    "$@" || code=$?
    printf '%s\t%s\n' "$name" "$code" | tee -a "$status"
}
copy_asset() {
    local source="$1" target="$2"
    mkdir -p "$target"
    cp -a "$source" "$target/"
    if [[ -d "$source" ]]; then diff -qr "$source" "$target/$(basename "$source")"
    else cmp "$source" "$target/$(basename "$source")"; fi
}
# Test actual KPackage installation independently of manual file placement.
probe global_package_install kpackagetool6 --type Plasma/LookAndFeel --install "$src/plasma/look-and-feel/$id"
# Use exact source files regardless of the preceding command's outcome.
rm -rf "$XDG_DATA_HOME/plasma/look-and-feel/$id"
copy_asset "$src/plasma/look-and-feel/$id" "$XDG_DATA_HOME/plasma/look-and-feel"
copy_asset "$src/plasma/desktoptheme/$id" "$XDG_DATA_HOME/plasma/desktoptheme"
copy_asset "$src/aurorae/$id" "$XDG_DATA_HOME/aurorae/themes"
copy_asset "$src/color-scheme/$id.colors" "$XDG_DATA_HOME/color-schemes"
probe global_package_show kpackagetool6 --type Plasma/LookAndFeel --show "$id"
list_global() { plasma-apply-lookandfeel --list | tee "$out/global-list.txt" | grep -Fx "$id"; }
probe global_list list_global
probe global_apply plasma-apply-lookandfeel --apply "$id"
read_config() {
    local expected="$1"; shift
    local actual
    actual="$(kreadconfig6 "$@")"
    printf 'Expected %s, effective %s (%s)\n' "$expected" "$actual" "$*"
    [[ "$actual" == "$expected" ]]
}
probe global_config read_config "$id" --file kdeglobals --group KDE --key LookAndFeelPackage
probe global_desktop_config read_config "$id" --file plasmarc --group Theme --key name
probe global_color_config read_config "$id" --file kdeglobals --group General --key ColorScheme
printf 'Decoration configured: %s / %s\n' \
 "$(kreadconfig6 --file kwinrc --group org.kde.kdecoration2 --key library)" \
 "$(kreadconfig6 --file kwinrc --group org.kde.kdecoration2 --key theme)" | tee "$out/decoration-config.txt"
# If global theme cannot be applied, independently test components, not modified assets.
probe desktop_apply plasma-apply-desktoptheme "$id"
probe desktop_config read_config "$id" --file plasmarc --group Theme --key name
probe colors_apply plasma-apply-colorscheme "$id"
probe colors_config read_config "$id" --file kdeglobals --group General --key ColorScheme
# Test the externally maintained companion without copying it into this repository.
source "$(dirname "$0")/icons.sh"
probe icon_config read_config "Gruvbox-Plus-$variant" --file kdeglobals --group Icons --key Theme
probe icon_lookup test_icons
probe splash_config read_config "$id" --file ksplashrc --group KSplash --key Theme
# Start genuine KWin virtual Wayland backend, no X11.
unset DISPLAY WAYLAND_DISPLAY QT_QPA_PLATFORM
source "$(dirname "$0")/backend.sh"
start_backend || exit 2
kwin_wayland "${backend_args[@]}" --width 1280 --height 800 --socket baseline-ci --no-lockscreen \
  >"$out/kwin.log" 2>&1 &
kwin_pid=$!
socket_ready() {
    for ((i=0;i<45;i++)); do
        kill -0 "$kwin_pid" 2>/dev/null || return 1
        [[ -S "$XDG_RUNTIME_DIR/baseline-ci" ]] && return 0
        sleep 1
    done
    return 1
}
if socket_ready; then
    printf 'wayland_socket\t0\n' >>"$status"
else
    printf 'wayland_socket\t1\n' >>"$status"
    cat "$out/kwin.log"
    exit 2
fi
export WAYLAND_DISPLAY=baseline-ci QT_QPA_PLATFORM=wayland
dbus-update-activation-environment WAYLAND_DISPLAY QT_QPA_PLATFORM XDG_RUNTIME_DIR XDG_CONFIG_DIRS XDG_MENU_PREFIX XDG_CURRENT_DESKTOP XDG_SESSION_TYPE
probe wayland_info wayland-info
plasmashell --no-respawn >"$out/plasmashell.log" 2>&1 &
shell_pid=$!
shell_ready() {
    for ((i=0;i<60;i++)); do
        kill -0 "$kwin_pid" && kill -0 "$shell_pid" || return 1
        if dbus-send --session --print-reply --reply-timeout=5000 --dest=org.kde.plasmashell \
          /PlasmaShell org.kde.PlasmaShell.evaluateScript \
          'string:print("BASELINE:" + desktops().length + ":" + panels().length)' \
          >"$out/shell-state.txt" 2>&1 && grep -Eq 'BASELINE:[1-9][0-9]*:[1-9][0-9]*' "$out/shell-state.txt"; then
            return 0
        fi
        sleep 1
    done
    return 1
}
probe shell_ready shell_ready
source "$(dirname "$0")/visual.sh"
probe kwin_decoration verify_decoration
if [[ "$backend" == nested ]]; then probe desktop_capture capture desktop; fi
# A regular Wayland application exercises the window decoration selection.
kdialog --msgbox "Gruvbox baseline $variant" >"$out/client.log" 2>&1 &
app_pid=$!
sleep 5
probe kwin_alive kill -0 "$kwin_pid"
probe shell_alive kill -0 "$shell_pid"
probe client_alive kill -0 "$app_pid"
if [[ "$backend" == nested ]]; then probe window_capture capture window; fi
kill "$app_pid" 2>/dev/null || true
wait "$app_pid" || true
app_pid=
probe splash_runtime test_splash
if [[ "$backend" == nested ]]; then probe splash_capture capture_splash; fi
cat "$status"
# Do not conflate failed component checks with an infrastructure failure.
# Nonzero probe results remain in the artifact and fail the baseline job.
awk -F '\t' 'NR>1 && $2!=0 {bad=1} END {exit bad+0}' "$status"
