$ErrorActionPreference = 'Stop'

$bundleVersion = '5.2.0-rev45'
$sourceWindows = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot "..\Easy\eazy-$bundleVersion"))
if (-not (Test-Path -LiteralPath (Join-Path $sourceWindows 'eazy'))) {
    throw "Não encontrei o bundle do Easy em: $sourceWindows"
}

$wslPathOutput = & wsl.exe --exec wslpath -a $sourceWindows
if ($LASTEXITCODE -ne 0 -or -not $wslPathOutput) {
    throw 'Não foi possível converter o caminho para o WSL. Verifique se há uma distribuição WSL instalada.'
}
$sourceLinux = ($wslPathOutput | Select-Object -Last 1).Trim()

# Quota um argumento como literal Bash sem interpolar conteúdo do caminho.
$sourceQuoted = "'" + $sourceLinux.Replace("'", "'\''") + "'"
$bootstrap = @"
set -euo pipefail
src=$sourceQuoted
dest="`$HOME/.local/share/eazy-windows-demo/eazy-$bundleVersion"
parent="`$(dirname "`$dest")"
mkdir -p "`$parent"
if [[ ! -x "`$dest/eazy" || ! -f "`$dest/BUNDLE_VERSION" || "`$(cat "`$dest/BUNDLE_VERSION" 2>/dev/null || true)" != "$bundleVersion" ]]; then
  tmp="`$dest.new.`$`$"
  rm -rf -- "`$tmp"
  mkdir -p "`$tmp"
  cp -a -- "`$src/." "`$tmp/"
  printf '%s\n' '$bundleVersion' > "`$tmp/BUNDLE_VERSION"
  chmod +x "`$tmp/eazy" "`$tmp/tools/compilar-eazy.sh" 2>/dev/null || true
  rm -rf -- "`$dest"
  mv -- "`$tmp" "`$dest"
fi
for cmd in bash python3 fzf whiptail; do
  if ! command -v "`$cmd" >/dev/null 2>&1; then
    printf 'Dependência essencial ausente no WSL: %s\n' "`$cmd" >&2
    printf 'Ubuntu/Debian: sudo apt update && sudo apt install -y bash python3 fzf whiptail\n' >&2
    exit 2
  fi
done
cd "`$dest"
exec bash ./eazy
"@

& wsl.exe --exec bash -lc $bootstrap
exit $LASTEXITCODE
