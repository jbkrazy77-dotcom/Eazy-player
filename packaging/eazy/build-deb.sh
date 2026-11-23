#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
PROJECT_DIR="$(cd -- "$SCRIPT_DIR/../.." && pwd -P)"
SRC_DIR="$PROJECT_DIR/windows-demo/Easy/eazy-5.2.0-rev45"
DEBIAN_DIR="$SCRIPT_DIR/debian"
PKGROOT="$SCRIPT_DIR/pkgroot"
DIST_DIR="$SCRIPT_DIR/dist"
PACKAGE="eazy"
VERSION="$(sed -n 's/^Version:[[:space:]]*//p' "$DEBIAN_DIR/control" | head -n1)"
[ -n "$VERSION" ] || { printf 'Erro: versão ausente em %s\n' "$DEBIAN_DIR/control" >&2; exit 1; }
ARCH="amd64"
OUTPUT="$DIST_DIR/${PACKAGE}_${VERSION}_${ARCH}.deb"

for required in dpkg-deb install gzip; do
    command -v "$required" >/dev/null 2>&1 || {
        printf 'Erro: comando necessário não encontrado: %s\n' "$required" >&2
        exit 1
    }
done

[ -d "$SRC_DIR" ] || {
    printf 'Erro: bundle de origem não encontrado: %s\n' "$SRC_DIR" >&2
    exit 1
}
BUNDLE_VERSION="$(cat "$SRC_DIR/BUNDLE_VERSION")"
[ "$BUNDLE_VERSION" = "5.2.0-rev45" ] || {
    printf 'Erro: bundle inesperado em %s (esperado 5.2.0-rev45; recebido %s)\n' "$SRC_DIR" "$BUNDLE_VERSION" >&2
    exit 1
}

required_files=(
    "$SRC_DIR/eazy"
    "$SRC_DIR/eazy-index.py"
    "$SRC_DIR/migrate_eazy_lists.py"
    "$SRC_DIR/eazy-yt-stream"
    "$SRC_DIR/eazy-tor"
    "$SRC_DIR/eazy-ai.py"
    "$SRC_DIR/eazy-notes-editor"
    "$SRC_DIR/eazy-live-watch.py"
    "$SRC_DIR/full.c"
    "$SRC_DIR/full"
    "$SRC_DIR/eazy.desktop"
    "$SRC_DIR/eazy.1"
    "$SRC_DIR/docs/eazy-help-5.2.0.txt"
    "$SRC_DIR/docs/eazy-help-5.2.0.html"
    "$SRC_DIR/README.md"
    "$SRC_DIR/CHANGELOG.md"
    "$SRC_DIR/EAZY_EXPLICADO.md"
    "$SRC_DIR/GUIA_RAPIDO.md"
    "$DEBIAN_DIR/control"
    "$DEBIAN_DIR/changelog"
    "$DEBIAN_DIR/copyright"
)
for required_file in "${required_files[@]}"; do
    [ -f "$required_file" ] || {
        printf 'Erro: arquivo necessário não encontrado: %s\n' "$required_file" >&2
        exit 1
    }
done

# O monitor embarcado é um ELF x86_64; não rotule este pacote como Architecture: all.
FULL_MACHINE="$(od -An -tx1 -j18 -N2 "$SRC_DIR/full" | tr -d '[:space:]')"
if [ "$FULL_MACHINE" != "3e00" ]; then
    printf 'Erro: o binário full não é ELF x86_64 (e_machine=%s); este pacote está configurado para amd64.\n' "$FULL_MACHINE" >&2
    exit 1
fi

rm -rf "$PKGROOT"
mkdir -p "$DIST_DIR"
mkdir -p \
    "$PKGROOT/DEBIAN" \
    "$PKGROOT/usr/bin" \
    "$PKGROOT/usr/lib/eazy" \
    "$PKGROOT/usr/share/applications" \
    "$PKGROOT/usr/share/man/man1" \
    "$PKGROOT/usr/share/doc/$PACKAGE"

# Comando principal e companions executáveis expostos em /usr/bin.
install -m 0755 "$SRC_DIR/eazy" "$PKGROOT/usr/bin/eazy"
install -m 0755 "$SRC_DIR/eazy-yt-stream" "$PKGROOT/usr/bin/eazy-yt-stream"
install -m 0755 "$SRC_DIR/eazy-tor" "$PKGROOT/usr/bin/eazy-tor"
install -m 0755 "$SRC_DIR/eazy-ai.py" "$PKGROOT/usr/bin/eazy-ai.py"
install -m 0755 "$SRC_DIR/eazy-notes-editor" "$PKGROOT/usr/bin/eazy-notes-editor"

# Helpers privados em /usr/lib/eazy; não duplicar o principal nem os companions.
install -m 0644 "$SRC_DIR/eazy-index.py" "$PKGROOT/usr/lib/eazy/eazy-index.py"
install -m 0644 "$SRC_DIR/migrate_eazy_lists.py" "$PKGROOT/usr/lib/eazy/migrate_eazy_lists.py"
install -m 0755 "$SRC_DIR/eazy-live-watch.py" "$PKGROOT/usr/lib/eazy/eazy-live-watch.py"
install -m 0644 "$SRC_DIR/full.c" "$PKGROOT/usr/lib/eazy/full.c"
install -m 0755 "$SRC_DIR/full" "$PKGROOT/usr/lib/eazy/full"

install -m 0644 "$SRC_DIR/eazy.desktop" "$PKGROOT/usr/share/applications/eazy.desktop"
install -m 0644 "$SRC_DIR/README.md" "$PKGROOT/usr/share/doc/$PACKAGE/README.md"
install -m 0644 "$SRC_DIR/CHANGELOG.md" "$PKGROOT/usr/share/doc/$PACKAGE/CHANGELOG.md"
install -m 0644 "$SRC_DIR/EAZY_EXPLICADO.md" "$PKGROOT/usr/share/doc/$PACKAGE/EAZY_EXPLICADO.md"
install -m 0644 "$SRC_DIR/GUIA_RAPIDO.md" "$PKGROOT/usr/share/doc/$PACKAGE/GUIA_RAPIDO.md"
install -m 0644 "$SRC_DIR/docs/eazy-help-5.2.0.txt" "$PKGROOT/usr/share/doc/$PACKAGE/eazy-help.txt"
install -m 0644 "$SRC_DIR/docs/eazy-help-5.2.0.html" "$PKGROOT/usr/share/doc/$PACKAGE/eazy-help.html"
install -m 0644 "$DEBIAN_DIR/control" "$PKGROOT/DEBIAN/control"
install -m 0644 "$DEBIAN_DIR/changelog" "$PKGROOT/usr/share/doc/$PACKAGE/changelog.Debian"
install -m 0644 "$DEBIAN_DIR/copyright" "$PKGROOT/usr/share/doc/$PACKAGE/copyright"
install -m 0644 "$SRC_DIR/eazy.1" "$PKGROOT/usr/share/man/man1/eazy.1"

gzip -n -9 -f "$PKGROOT/usr/share/man/man1/eazy.1"
gzip -n -9 -f "$PKGROOT/usr/share/doc/$PACKAGE/changelog.Debian"

dpkg-deb --build --root-owner-group "$PKGROOT" "$OUTPUT" >/dev/null

printf 'Pacote criado: %s\n' "$OUTPUT"
printf 'Tamanho: '
du -h "$OUTPUT" | cut -f1
printf '\nMetadados:\n'
dpkg-deb --info "$OUTPUT" | sed -n '1,18p'
printf '\nConteúdo:\n'
dpkg-deb --contents "$OUTPUT"
