#!/bin/bash
# Instala eazy 4.4.4 no Ubuntu WSL2
set -e
cd "$(dirname "$0")"
DEB="eazy_4.4.4_all.deb"
if [ ! -f "$DEB" ]; then
  echo "Coloque $DEB nesta pasta." >&2
  exit 1
fi
sudo dpkg -i "$DEB" || true
sudo apt-get update -qq
sudo apt-get install -f -y
sudo apt-get install -y fzf whiptail gawk aria2 ffmpeg yt-dlp python3 mpv wslu 2>/dev/null || \
  sudo apt-get install -y fzf whiptail gawk aria2 ffmpeg yt-dlp python3 mpv
echo
echo "OK. Execute:  eazy"
echo "Pastas Windows:  eazy /mnt/c/Users/\$USER/Videos"
