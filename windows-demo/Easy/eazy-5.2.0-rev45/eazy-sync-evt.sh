#!/bin/sh
PASTA_FILA="/dev/shm/fila_eventos"
DB="${XDG_CONFIG_HOME:-$HOME/.config}/eazy/eazy-index.sqlite3"
SCRIPT_DIR="$(cd -- "$(dirname -- "$0")" 2>/dev/null && pwd -P)"
INDEXER="$SCRIPT_DIR/eazy-index.py"
[ -f "$INDEXER" ] || INDEXER="/usr/lib/eazy/eazy-index.py"

[ -d "$PASTA_FILA" ] || exit 0
[ -f "$INDEXER" ] || exit 0

tem_ticket=0
for t in "$PASTA_FILA"/*.evt; do
    [ -e "$t" ] && tem_ticket=1 && break
done
[ "$tem_ticket" -eq 0 ] && exit 0

TMP_LIST=$(mktemp "/dev/shm/eazy_evt_batch.XXXXXX") || exit 1
TMP_ADD=$(mktemp "/dev/shm/eazy_evt_add.XXXXXX") || { rm -f "$TMP_LIST"; exit 1; }
TMP_DEL=$(mktemp "/dev/shm/eazy_evt_del.XXXXXX") || { rm -f "$TMP_LIST" "$TMP_ADD"; exit 1; }

for t in "$PASTA_FILA"/*.evt; do
    [ -e "$t" ] || continue
    printf '%s\n' "$t" >> "$TMP_LIST"
    IFS='|' read -r ev _tam _dt caminho < "$t"
    ev="${ev#"${ev%%[![:space:]]*}"}"; ev="${ev%"${ev##*[![:space:]]}"}"
    caminho="${caminho#"${caminho%%[![:space:]]*}"}"
    [ -z "$caminho" ] && continue

    case "$ev" in
        REMOVIDO)
            printf '%s\0' "$caminho" >> "$TMP_DEL"
            ;;
        CRIADO|PRONTO)
            printf '%s\0' "$caminho" >> "$TMP_ADD"
            ;;
    esac
done

# 1. Insere/atualiza criados e prontos via indexador oficial
if [ -s "$TMP_ADD" ]; then
    python3 "$INDEXER" --db "$DB" --scan0 < "$TMP_ADD" >/dev/null 2>&1
fi

# 2. Marca removidos diretamente no SQLite (deleted=1)
if [ -s "$TMP_DEL" ]; then
    python3 - "$DB" "$TMP_DEL" << 'PYDEL' >/dev/null 2>&1
import sqlite3, sys, time
db_path, del_file = sys.argv[1], sys.argv[2]
with open(del_file, "rb") as f:
    paths = [p.decode("utf-8", "surrogateescape") for p in f.read().split(b"\0") if p]
if paths:
    now = int(time.time())
    con = sqlite3.connect(db_path, timeout=15)
    with con:
        for p in paths:
            con.execute("UPDATE files SET deleted=1, deleted_at=? WHERE path=?", (now, p))
            prefix = p.rstrip("/") + "/"
            con.execute("UPDATE files SET deleted=1, deleted_at=? WHERE substr(path,1,?)=?", (now, len(prefix), prefix))
    con.close()
PYDEL
fi

while IFS= read -r t; do
    rm -f -- "$t"
done < "$TMP_LIST"

rm -f -- "$TMP_LIST" "$TMP_ADD" "$TMP_DEL"
exit 0
