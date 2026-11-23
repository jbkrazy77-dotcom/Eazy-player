#!/bin/sh
SYNC_BIN="$1"
TMP_STATUS="$2"
FILA="/dev/shm/fila_eventos"
SCRIPT_DIR="$(dirname -- "$SYNC_BIN")"
INDEXER="$SCRIPT_DIR/eazy-index.py"
[ -f "$INDEXER" ] || INDEXER="/usr/lib/eazy/eazy-index.py"
DB="${XDG_CONFIG_HOME:-$HOME/.config}/eazy/eazy-index.sqlite3"

mkdir -p "$FILA" 2>/dev/null || true
"$SYNC_BIN" 2>/dev/null || true

ciclo=0
while true; do
    # 1. Processa tickets .evt da fila em RAM (0ms via inotify do full)
    tem_evt=0
    for t in "$FILA"/*.evt; do
        [ -e "$t" ] && tem_evt=1 && break
    done

    if [ "$tem_evt" -eq 1 ]; then
        "$SYNC_BIN" 2>/dev/null || true
    fi

    # 2. A cada 1s, sincroniza se a pasta aberta for Windows (/mnt/c...)
    ciclo=$((ciclo + 1))
    if [ "$ciclo" -ge 5 ]; then
        ciclo=0
        if [ -f "$TMP_STATUS" ]; then
            IFS='|' read -r _t _alvo _ult dir_atual _m < "$TMP_STATUS" 2>/dev/null || true
            case "${dir_atual:-}" in
                /mnt/[a-zA-Z]*)
                    if [ -f "$INDEXER" ] && [ -d "$dir_atual" ]; then
                        python3 "$INDEXER" --db "$DB" --sync-dir "$dir_atual" >/dev/null 2>&1 || true
                    fi
                    ;;
            esac
        fi
    fi

    sleep 0.2
done
