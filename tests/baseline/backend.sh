#!/usr/bin/env bash
# The same KWin virtual backend runs with or without a vgem DRM device.
start_backend() {
    pipewire >"$out/pipewire.log" 2>&1 &
    pipewire_pid=$!
    case "$backend" in
        virtual|vgem) backend_args=(--virtual) ;;
        *) echo "Unknown backend: $backend"; return 2 ;;
    esac
}
