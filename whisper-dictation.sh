#!/usr/bin/env bash
set -euo pipefail

# --- Configuration ---
WHISPER_CLI="/home/void/whisper.cpp/build/bin/whisper-cli"
MODEL="/home/void/whisper.cpp/models/ggml-large-v3-turbo-q5_0.bin"
LANGUAGE="ru"
THREADS=8
# ---------------------

PIDFILE="/tmp/whisper-dictation-pid.txt"
OUTDIR=""
LOG="/tmp/whisper-dictation.log"

start() {
    OUTDIR=$(mktemp -d /tmp/whisper-dictation-XXXXXX)
    echo "$OUTDIR" > /tmp/whisper-dictation-dir.txt

    notify-send -t 1500 "Dictation" "Recording…"

    parec \
        --file-format=wav \
        --rate=16000 \
        --channels=1 \
        --format=s16le \
        "$OUTDIR/audio.wav" \
        2>/dev/null &
    echo $! > "$PIDFILE"

    sleep 0.5
    if ! kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
        rm -f "$PIDFILE" /tmp/whisper-dictation-dir.txt
        rm -rf "$OUTDIR"
        notify-send -t 3000 "Dictation" "Failed to start recording"
        exit 1
    fi
}

stop() {
    local pid
    pid=$(cat "$PIDFILE" 2>/dev/null || true)

    notify-send -t 5000 "Dictation" "Transcribing…"

    if [ -n "$pid" ]; then
        kill "$pid" 2>/dev/null || true
        for _ in 1 2 3 4 5 6 7 8 9 10; do
            if ! kill -0 "$pid" 2>/dev/null; then break; fi
            sleep 0.1
        done
        kill -9 "$pid" 2>/dev/null || true
        wait "$pid" 2>/dev/null || true
    fi

    rm -f "$PIDFILE"

    local dir
    dir=$(cat /tmp/whisper-dictation-dir.txt 2>/dev/null || true)
    rm -f /tmp/whisper-dictation-dir.txt

    local text=""
    if [ -n "$dir" ] && [ -f "$dir/audio.wav" ]; then
        text=$("$WHISPER_CLI" \
            -m "$MODEL" \
            -l "$LANGUAGE" \
            -t "$THREADS" \
            -ng \
            --no-flash-attn \
            --no-timestamps \
            -f "$dir/audio.wav" \
            2>"$LOG")
        text=$(echo "$text" | tr '\n' ' ' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        rm -rf "$dir"
    fi
    rm -f "$LOG"
    rm -rf "$dir" 2>/dev/null || true

    sleep 0.3

    if [ -n "$text" ]; then
        echo "$text" | wl-copy 2>/dev/null || true
        wtype "${text} " 2>/dev/null || true
        notify-send -t 3000 "Dictation" "“${text:0:80}” — скопировано в буфер"
    else
        notify-send -t 3000 "Dictation" "Речь не распознана"
    fi
}

if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE" 2>/dev/null)" 2>/dev/null; then
    stop
else
    rm -f "$PIDFILE" /tmp/whisper-dictation-dir.txt "$LOG"
    start
fi
