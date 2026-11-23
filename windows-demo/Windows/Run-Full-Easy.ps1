$ErrorActionPreference = 'Stop'

$bundleVersion = '5.2.0-rev45'
$sourceWindows = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot "..\Easy\eazy-$bundleVersion"))
if (-not (Test-Path -LiteralPath (Join-Path $sourceWindows 'eazy'))) {
    throw "Não encontrei o bundle do Easy em: $sourceWindows"
}
if (-not (Test-Path -LiteralPath (Join-Path $sourceWindows 'install.sh'))) {
    throw "O bundle está incompleto; falta install.sh em: $sourceWindows"
}

$wslPathOutput = & wsl.exe --exec wslpath -a $sourceWindows
if ($LASTEXITCODE -ne 0 -or -not $wslPathOutput) {
    throw 'Não foi possível converter o caminho para o WSL. Verifique se há uma distribuição WSL instalada.'
}
$sourceLinux = ($wslPathOutput | Select-Object -Last 1).Trim()

# Quote as one Bash literal; the Windows path is not interpolated as shell code.
$sourceQuoted = "'" + $sourceLinux.Replace("'", "'\''") + "'"
$bootstrap = @"
set -euo pipefail
src=$sourceQuoted
machine=`$(uname -m)
if [[ "`$machine" != x86_64 && "`$machine" != amd64 ]]; then
  printf 'Esta release requer WSL x86_64 (amd64); arquitetura detectada: %s\n' "`$machine" >&2
  exit 4
fi
for cmd in bash python3 fzf whiptail sha256sum awk; do
  if ! command -v "`$cmd" >/dev/null 2>&1; then
    printf 'Dependência essencial ausente no WSL: %s\n' "`$cmd" >&2
    printf 'Ubuntu/Debian: sudo apt update && sudo apt install -y bash python3 fzf whiptail coreutils gawk\n' >&2
    exit 2
  fi
done
source_hash=`$(sha256sum "`$src/eazy" | awk '{print `$1}')
installed_hash=`$(sha256sum /usr/bin/eazy 2>/dev/null | awk '{print `$1}' || true)
if [[ "`$source_hash" != "`$installed_hash" ]]; then
  printf 'Instalando/atualizando Easy 5.2.0 rev.45 em /usr/bin/eazy...\n'
  cd -- "`$src"
  bash ./install.sh
fi
if [[ ! -x /usr/bin/eazy ]]; then
  printf 'O instalador não deixou /usr/bin/eazy executável.\n' >&2
  exit 3
fi
exec /usr/bin/eazy
"@

& wsl.exe --exec bash -lc $bootstrap
exit $LASTEXITCODE
