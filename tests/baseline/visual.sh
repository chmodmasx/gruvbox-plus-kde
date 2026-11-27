#!/usr/bin/env bash
# Native compositor checks. Capture is deliberately independent of splash runtime.
verify_decoration() {
    dbus-send --session --print-reply --reply-timeout=5000 --dest=org.kde.KWin \
        /KWin org.kde.KWin.supportInformation >"$out/kwin-support.txt" || return 1
    # KWin 6.6/6.7 migrates SVG Aurorae themes to v2 automatically.
    grep -Eq '^Plugin: org\.kde\.kwin\.aurorae(\.v2)?$' "$out/kwin-support.txt" &&
    grep -Fx "Theme: __aurorae__svg__$id" "$out/kwin-support.txt"
}
capture() {
    local name="$1"
    # KWin's screenshot manager requires an EGL backend. QPainter is not supported.
    if ! grep -Eq '^Compositing Type: OpenGL( ES 2\.0)?$' "$out/kwin-support.txt"; then
        echo "Visual capture blocked: expected OpenGL compositor" | tee "$out/screenshot-$name.log"
        return 2
    fi
    timeout 15s spectacle --background --nonotify --fullscreen --output "$out/$name.png" \
        >"$out/screenshot-$name.log" 2>&1 || return 1
    test -s "$out/$name.png"
}
test_splash() {
    local start=$SECONDS code=0
    timeout 20s ksplashqml --test --nofork "$id" >"$out/splash.log" 2>&1 || code=$?
    printf 'exit=%s elapsed=%s\n' "$code" "$((SECONDS-start))" | tee "$out/splash-result.txt"
    [[ "$code" = 0 && $((SECONDS-start)) -ge 6 ]] &&
        ! grep -Eq 'Failed loading|Failed to resolve package|ReferenceError|TypeError|is not installed' "$out/splash.log"
}
capture_splash() {
    local snap=0
    ksplashqml --test --nofork "$id" >"$out/splash-capture.log" 2>&1 &
    splash_pid=$!
    sleep 2
    if kill -0 "$splash_pid" 2>/dev/null; then capture splash || snap=$?; else snap=1; fi
    kill "$splash_pid" 2>/dev/null || true
    wait "$splash_pid" || true
    splash_pid=
    return "$snap"
}
