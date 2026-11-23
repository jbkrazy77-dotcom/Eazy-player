#!/usr/bin/env bash
# Instala o bundle local usando os destinos de sistema do Easy; não grava binários no HOME.
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
VERSION_DIR="eazy-5.2.0-rev45"

is_complete_bundle() {
  local dir="$1"
  [[ -f "$dir/eazy" && -f "$dir/eazy-yt-stream" && \
     -f "$dir/eazy-index.py" && -f "$dir/migrate_eazy_lists.py" ]]
}

SOURCE=""
for candidate in \
  "$SCRIPT_DIR/windows-demo/Easy/$VERSION_DIR" \
  "$SCRIPT_DIR/$VERSION_DIR" \
  "$SCRIPT_DIR/eazy-5.2.0-full" \
  "$SCRIPT_DIR"; do
  if is_complete_bundle "$candidate"; then
    SOURCE="$(cd -- "$candidate" && pwd -P)"
    break
  fi
done

if [[ -z "$SOURCE" ]]; then
  echo "Bundle completo não encontrado próximo ao instalador." >&2
  echo "Esperado: eazy, eazy-yt-stream, eazy-index.py e migrate_eazy_lists.py." >&2
  exit 1
fi
if [[ ! -x "$SOURCE/eazy" ]]; then
  echo "O executável do bundle não tem permissão de execução: $SOURCE/eazy" >&2
  exit 1
fi

# O programa é iniciado como usuário normal para preservar os dados em ~/.config/eazy;
# o próprio --install pede sudo somente para gravar os destinos de sistema.
if (( EUID == 0 )); then
  if [[ -n "${SUDO_USER:-}" && "$SUDO_USER" != root ]]; then
    TARGET_HOME="$(getent passwd "$SUDO_USER" | cut -d: -f6)"
    [[ -n "$TARGET_HOME" ]] || {
      echo "Não foi possível localizar o HOME de $SUDO_USER." >&2
      exit 1
    }
    exec sudo -u "$SUDO_USER" env -u SUDO_USER HOME="$TARGET_HOME" USER="$SUDO_USER" \
      bash -- "$SCRIPT_DIR/install-eazy-pronto.sh" "$@"
  fi
  echo "Execute este instalador como usuário normal; o eazy solicitará sudo apenas para operações de sistema." >&2
  exit 1
fi

if ! command -v sudo >/dev/null 2>&1; then
  echo "sudo não está disponível; é necessário para instalar em /usr/bin e /usr/lib/eazy." >&2
  exit 1
fi

cd -- "$SOURCE"
printf '==> Instalando o bundle local usando: %s/eazy --install\n' "$SOURCE"
"$SOURCE/eazy" --install

if [[ ! -x /usr/bin/eazy ]]; then
  echo "A instalação oficial não deixou um executável em /usr/bin/eazy." >&2
  exit 1
fi

# Não apaga instalações anteriores: avisa para evitar que um comando antigo no PATH
# esconda o executável novo em /usr/bin.
if [[ -x "$HOME/.local/bin/eazy" ]]; then
  echo "Aviso: existe uma cópia anterior em $HOME/.local/bin/eazy; não foi alterada. Use /usr/bin/eazy para testar esta instalação." >&2
fi
if [[ -e /usr/local/bin/eazy || -L /usr/local/bin/eazy ]]; then
  echo "Aviso: existe um destino anterior em /usr/local/bin/eazy; não foi alterado. Verifique a ordem do PATH se o comando eazy não apontar para /usr/bin/eazy." >&2
fi

printf '\nInstalação concluída. Comando principal: /usr/bin/eazy\n'
printf 'Configurações do usuário permanecem em %s/.config/eazy.\n' "${HOME%/}"
