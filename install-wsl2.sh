#!/usr/bin/env bash
# Instala Easy 5.2.0 rev45 no Ubuntu/WSL2 somente pelo pacote Debian.
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
DEB="eazy_5.2.0+rev45_amd64.deb"
LOCAL_DEB=""
for candidate in \
  "$SCRIPT_DIR/$DEB" \
  "$SCRIPT_DIR/dist/$DEB" \
  "$SCRIPT_DIR/packaging/eazy/dist/$DEB" \
  "$SCRIPT_DIR/../../../dist/$DEB" \
  "$SCRIPT_DIR/../../../packaging/eazy/dist/$DEB"; do
  if [[ -f "$candidate" ]]; then
    LOCAL_DEB="$(cd -- "$(dirname -- "$candidate")" && pwd -P)/$(basename -- "$candidate")"
    break
  fi
done

if [[ -n "$LOCAL_DEB" ]]; then
  CHECKSUM="$LOCAL_DEB.sha256"
  if [[ ! -f "$CHECKSUM" ]]; then
    echo "O pacote local não tem checksum correspondente: $CHECKSUM" >&2
    exit 1
  fi
  (cd -- "$(dirname -- "$LOCAL_DEB")" && sha256sum --check "$(basename -- "$CHECKSUM")")
  sudo apt install -y "$LOCAL_DEB"
else
  WEB_INSTALLER="$SCRIPT_DIR/install-from-web.sh"
  if [[ ! -f "$WEB_INSTALLER" ]]; then
    echo "Instalador web atualizado não encontrado: $WEB_INSTALLER" >&2
    exit 1
  fi
  bash "$WEB_INSTALLER"
fi

if ! dpkg-query -W -f='${Status}' eazy 2>/dev/null | grep -Fqx 'install ok installed' || \
   ! dpkg-query -L eazy | grep -Fqx '/usr/bin/eazy' || [[ ! -x /usr/bin/eazy ]]; then
  echo "Verificação falhou: o pacote deve fornecer o comando /usr/bin/eazy." >&2
  exit 1
fi

# Dependências usuais do fluxo WSL2; a integração do Easy vem exclusivamente do pacote.
sudo apt install -y fzf whiptail gawk aria2 ffmpeg yt-dlp python3 gcc mpv
sudo apt install -y wslu 2>/dev/null || true
printf '\nOK. Comando principal instalado em /usr/bin/eazy. Execute: eazy\n'
printf 'Pastas Windows: eazy /mnt/c/Users/$USER/Videos\n'
