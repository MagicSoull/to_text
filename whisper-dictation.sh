#!/usr/bin/env bash
set -euo pipefail

# --- Configuration ---
WHISPER_STREAM="/home/void/whisper.cpp/build/bin/whisper-stream"
MODEL="/home/void/whisper.cpp/models/ggml-large-v3-turbo-q5_0.bin"
LANGUAGE="ru"
THREADS=8
STEP_MS=3000
LENGTH_MS=10000
KEEP_MS=200
# ---------------------

WS_PIDFILE="/tmp/whisper-dictation-ws.pid"
MON_PIDFILE="/tmp/whisper-dictation-mon.pid"
OUTFILE="/tmp/whisper-dictation-output.txt"
FULLFILE="/tmp/whisper-dictation-full.txt"
LOG="/tmp/whisper-dictation.log"

start() {
    notify-send -t 1500 "Dictation" "Recording…"

    : > "$OUTFILE"
    : > "$FULLFILE"

    "$WHISPER_STREAM" \
        -m "$MODEL" -l "$LANGUAGE" -t "$THREADS" \
        --step "$STEP_MS" --length "$LENGTH_MS" --keep "$KEEP_MS" \
        --keep-context --no-flash-attn \
        -f "$OUTFILE" \
        >/dev/null 2>"$LOG" &
    local ws_pid=$!
    echo "$ws_pid" > "$WS_PIDFILE"

    sleep 1
    if ! kill -0 "$ws_pid" 2>/dev/null; then
        rm -f "$WS_PIDFILE" "$OUTFILE" "$FULLFILE"
        notify-send -t 5000 "Dictation" "Failed to start — check $LOG"
        exit 1
    fi

    (
        exec 3< <(tail -f --pid="$ws_pid" "$OUTFILE" 2>/dev/null)
        prev=""
        full=""

        while IFS= read -r line <&3; do
            line=$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            [ -z "$line" ] && continue

            # fast path: same as previous line (no new content)
            [ "$line" = "$prev" ] && continue

            if [ -z "$prev" ]; then
                delta="$line"
            else
                delta=$(awk -v p="$prev" -v c="$line" '
                BEGIN {
                    n = split(p, pw)
                    m = split(c, cw)
                    o = 0
                    for (l = (n < m ? n : m); l > 0; l--) {
                        ok = 1
                        for (j = 1; j <= l; j++)
                            if (pw[n-l+j] != cw[j]) { ok = 0; break }
                        if (ok) { o = l; break }
                    }
                    r = ""
                    for (j = o+1; j <= m; j++) r = r " " cw[j]
                    gsub(/^ /, "", r)
                    print r
                }')
            fi

            if [ -n "$delta" ]; then
                wtype "${delta} " 2>/dev/null || true
            fi

            prev="$line"
            full="$full $delta"
            full=$(echo "$full" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

            if [ -n "$full" ]; then
                echo "$full" > "$FULLFILE"
                echo "$full" | wl-copy 2>/dev/null || true
            fi
        done

        if [ -n "${full:-}" ]; then
            echo "$full" > "$FULLFILE"
        fi
        exec 3<&-
    ) &
    local mon_pid=$!
    echo "$mon_pid" > "$MON_PIDFILE"
}

stop() {
    local ws_pid mon_pid
    ws_pid=$(cat "$WS_PIDFILE" 2>/dev/null || true)
    mon_pid=$(cat "$MON_PIDFILE" 2>/dev/null || true)

    notify-send -t 5000 "Dictation" "Transcribing…"

    # Kill whisper-stream — tail --pid detects death, monitor exits
    if [ -n "$ws_pid" ]; then
        kill "$ws_pid" 2>/dev/null || true
    fi

    # Wait for monitor to flush remaining lines and exit
    if [ -n "$mon_pid" ]; then
        wait "$mon_pid" 2>/dev/null || true
    fi

    # Force kill if whisper-stream still hanging
    if [ -n "$ws_pid" ]; then
        kill -0 "$ws_pid" 2>/dev/null && kill -9 "$ws_pid" 2>/dev/null || true
        wait "$ws_pid" 2>/dev/null || true
    fi

    local full=""
    if [ -f "$FULLFILE" ]; then
        full=$(cat "$FULLFILE")
        full=$(echo "$full" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    fi

    rm -f "$WS_PIDFILE" "$MON_PIDFILE" "$OUTFILE" "$FULLFILE" "$LOG"

    sleep 0.3

    if [ -n "$full" ]; then
        wtype "${full} " 2>/dev/null || true
        echo "$full" | wl-copy 2>/dev/null || true
        notify-send -t 3000 "Dictation" "“${full:0:80}” — в буфере"
    else
        notify-send -t 3000 "Dictation" "Речь не распознана"
    fi
}

# --- Toggle ---
if [ -f "$WS_PIDFILE" ] && kill -0 "$(cat "$WS_PIDFILE" 2>/dev/null)" 2>/dev/null; then
    stop
else
    rm -f "$WS_PIDFILE" "$MON_PIDFILE" "$OUTFILE" "$FULLFILE" "$LOG"
    start
fi
