# Easy 5.2.0 rev.45 — bundle Linux/WSL2

Este diretório contém o `eazy` da raiz do repositório como executável principal, além de Easy Stream, indexador SQLite, migrador, watcher, monitor C, compilador, ajuda, man page e ferramentas auxiliares.

## Testar sem instalar

```bash
./eazy --version
./eazy --help
```

Para testar monitoramento, streaming e recursos auxiliares, mantenha todos os arquivos deste bundle juntos. O programa em Bash e seus companions devem ser usados no Linux ou no WSL2.

## Instalação local

No Debian/Ubuntu ou numa distribuição Debian/Ubuntu dentro do WSL2 x86_64:

```bash
sudo apt update
sudo apt install -y bash python3 fzf whiptail
./install.sh
```

Ou use `./install-eazy-pronto.sh`; ambos delegam à instalação oficial do Easy neste bundle.

O executável principal fica em `/usr/bin/eazy`; os companions CLI ficam em `/usr/bin`, os auxiliares em `/usr/lib/eazy`, o launcher em `/usr/share/applications` e a man page em `/usr/share/man/man1`. Não são criadas cópias executáveis em HOME ou em `/usr/local/bin`. Configurações e dados do usuário permanecem em `~/.config/eazy`.

## Instalação pela Internet

O instalador `install-from-web.sh` baixa o pacote validado por SHA-256 da release `v5.2.0-rev45` do repositório `jbkrazy77-dotcom/Eazy-player`. O pacote Debian disponibilizado é `amd64`, pois contém o monitor x86_64 `full`.

## Instalação WSL2

Use `./install-wsl2.sh` em uma distribuição WSL2 x86_64 baseada em Debian/Ubuntu. O script instala pacote local validado por SHA-256, se presente, ou delega ao instalador web; depois verifica `/usr/bin/eazy` e instala as dependências usuais do fluxo WSL. O launcher Windows correspondente fica em `../Windows/Run-Full-Easy.ps1`.

## Compilador

O fonte `full.c` e o compilador `tools/compilar-eazy.sh` acompanham o bundle. Para compilar o wrapper Linux x86_64 do Easy:

```bash
sudo apt install -y build-essential zlib1g-dev
./tools/compilar-eazy.sh ./eazy ./bin/eazy-linux-x86_64
```

O compilador não altera o fonte `eazy`.

## Limites

A demonstração Windows executa o Easy completo dentro do Linux/WSL2; não é uma conversão nativa completa para Windows. O protótipo Python nativo é limitado à navegação demonstrativa.
