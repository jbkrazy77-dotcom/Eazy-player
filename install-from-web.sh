#!/usr/bin/env bash
# Baixa e instala exclusivamente a release aprovada Easy 5.2.0 rev45.
set -euo pipefail

REPOSITORY="jbkrazy77-dotcom/Eazy-player"
TAG="v5.2.0-rev45"
DEB="eazy_5.2.0+rev45_amd64.deb"
BASE="https://github.com/${REPOSITORY}/releases/download/${TAG}"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/eazy-rev45.XXXXXX")"
trap 'rm -rf -- "$TMP"' EXIT
cd -- "$TMP"

printf '==> Baixando %s da release %s...\n' "$DEB" "$TAG"
curl --fail --location --show-error --silent -o "$DEB" "$BASE/$DEB"
curl --fail --location --show-error --silent -o "$DEB.sha256" "$BASE/$DEB.sha256"
sha256sum --check "$DEB.sha256"

printf '==> Instalando pacote Debian oficial via apt...\n'
sudo apt install -y "./$DEB"

if ! dpkg-query -W -f='${Status}' eazy 2>/dev/null | grep -Fqx 'install ok installed'; then
  echo "O pacote eazy não consta como instalado após o apt." >&2
  exit 1
fi
if ! dpkg-query -L eazy | grep -Fqx '/usr/bin/eazy' || [[ ! -x /usr/bin/eazy ]]; then
  echo "O pacote não instalou o comando principal executável em /usr/bin/eazy." >&2
  exit 1
fi

printf '==> Easy 5.2.0 rev45 instalado; comando principal: /usr/bin/eazy\n'
/usr/bin/eazy --version
