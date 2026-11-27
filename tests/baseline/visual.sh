#!/usr/bin/env bash
# Sourced only by probe.sh after the Wayland compositor is ready.
verify_decoration() {
    dbus-send --session --print-reply --reply-timeout=5000 --dest=org.kde.KWin \
        /KWin org.kde.KWin.supportInformation >"$out/kwin-support.txt" || return 1
    grep -Fx "Plugin: org.kde.kwin.aurorae" "$out/kwin-support.txt" &&
    grep -Fx "Theme: __aurorae__svg__$id" "$out/kwin-support.txt"
}
capture() {
    local name="$1"
    timeout 20s spectacle --background --nonotify --fullscreen --output "$out/$name.png" \
        >"$out/screenshot-$name.log" 2>&1 || return 1
    test -s "$out/$name.png"
}
test_splash() {
    # Use KDE's real Wayland splash preview instead of testing only QML syntax.
    ksplashqml --test --nofork "$id" >"$out/splash.log" 2>&1 &
    splash_pid=$!
    sleep 3
    local alive=0 snap=0 code=0
    kill -0 "$splash_pid" || alive=$?
    if [[ "$alive" = 0 ]]; then capture splash || snap=$?; else snap=1; fi
    # The KDE test advances every two seconds and exits at stage 6.
    for ((i=0;i<15;i++)); do
        kill -0 "$splash_pid" 2>/dev/null || break
        sleep 1
    done
    if kill -0 "$splash_pid" 2>/dev/null; then
        kill "$splash_pid" || true
        wait "$splash_pid" || true
        splash_pid=
        return 1
    fi
    wait "$splash_pid" || code=$?
    splash_pid=
    [[ "$alive" = 0 && "$snap" = 0 && "$code" = 0 ]]
}
