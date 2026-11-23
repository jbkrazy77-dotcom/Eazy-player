#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
if (( EUID == 0 )); then
  if [[ -n "${SUDO_USER:-}" && "$SUDO_USER" != root ]]; then
    TARGET_HOME="$(getent passwd "$SUDO_USER" | cut -d: -f6)"
    [[ -n "$TARGET_HOME" ]] || { echo "Não foi possível localizar o HOME de $SUDO_USER." >&2; exit 1; }
    exec sudo -u "$SUDO_USER" env -u SUDO_USER HOME="$TARGET_HOME" USER="$SUDO_USER" \
      bash -- "$SCRIPT_DIR/install.sh" "$@"
  fi
  echo "Execute este instalador como usuário normal; o eazy solicitará sudo apenas para operações de sistema." >&2
  exit 1
fi
VERSION_DIR="eazy-5.2.0-rev45"

is_bundle() {
  local dir="$1"
  [[ -f "$dir/eazy" && -f "$dir/eazy-yt-stream" && \
     -f "$dir/eazy-index.py" && -f "$dir/migrate_eazy_lists.py" ]]
}

BUNDLE=""
if [[ "$(basename -- "$SCRIPT_DIR")" == "$VERSION_DIR" ]] && is_bundle "$SCRIPT_DIR"; then
  BUNDLE="$SCRIPT_DIR"
else
  for candidate in \
    "$SCRIPT_DIR/windows-demo/Easy/$VERSION_DIR" \
    "$SCRIPT_DIR/$VERSION_DIR" \
    "$SCRIPT_DIR/eazy-5.2.0-full" \
    "$SCRIPT_DIR"; do
    if is_bundle "$candidate"; then
      BUNDLE="$candidate"
      break
    fi
  done
fi

if [[ -z "$BUNDLE" ]]; then
  echo "Bundle Easy 5.2.0 rev45 completo não encontrado." >&2
  exit 1
fi
if [[ ! -x "$BUNDLE/eazy" ]]; then
  echo "Executável do bundle não tem permissão de execução: $BUNDLE/eazy" >&2
  exit 1
fi
cd -- "$BUNDLE"
exec "$BUNDLE/eazy" --install
