#!/usr/bin/env bash
# Two independent modes: virtual functional checks and nested software OpenGL visuals.
start_backend() {
    pipewire >"$out/pipewire.log" 2>&1 &
    pipewire_pid=$!
    case "$backend" in
        virtual) backend_args=(--virtual) ;;
        nested)
            weston --backend=headless-backend.so --renderer=gl --socket=weston-ci \
                --width=1280 --height=800 --idle-time=0 --no-config \
                >"$out/weston.log" 2>&1 &
            weston_pid=$!
            for ((i=0;i<30;i++)); do
                kill -0 "$weston_pid" 2>/dev/null || { cat "$out/weston.log"; return 1; }
                if [[ -S "$XDG_RUNTIME_DIR/weston-ci" ]]; then
                    backend_args=(--wayland-display weston-ci)
                    return 0
                fi
                sleep 1
            done
            cat "$out/weston.log"
            return 1 ;;
        *) echo "Unknown backend: $backend"; return 2 ;;
    esac
}
