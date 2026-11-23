# eazy 5.2.0 rev.45

Easy é um gerenciador de arquivos e mídia em Bash, com indexação SQLite, navegação interativa e monitoramento de alterações. O executável principal desta entrega é o arquivo `eazy` na raiz deste repositório.

```bash
./eazy --version
# eazy 5.2.0 rev.45 (sqlite-live-watch)
```

## Conteúdo e uso

O conjunto completo de módulos necessários para executar e instalar o Easy, junto com o executável principal da raiz, está em [`windows-demo/Easy/eazy-5.2.0-rev45/`](windows-demo/Easy/eazy-5.2.0-rev45/). Esse diretório inclui indexador SQLite, monitoramento, auxiliares de mídia, instalação, o código-fonte `full.c` e o compilador `tools/compilar-eazy.sh`.

No Linux x86_64 ou WSL2 x86_64, instale os requisitos essenciais e inicie o instalador do bundle:

```bash
sudo apt update
sudo apt install -y bash python3 fzf whiptail
cd windows-demo/Easy/eazy-5.2.0-rev45
./eazy --version
./install.sh
```

Players e ferramentas de mídia, como `mpv`, `ffmpeg`, `curl` e `wget`, são opcionais e habilitam funcionalidades correspondentes. Para compilar o executável Linux protegido são necessários GCC e os headers de zlib:

```bash
sudo apt install -y build-essential zlib1g-dev
./tools/compilar-eazy.sh ./eazy ./bin/eazy-linux-x86_64
```

O script cria um wrapper Linux x86_64 e não altera o fonte `eazy`. A versão em Bash continua incluída no pacote.

O instalador coloca o comando principal em `/usr/bin/eazy`, os companions executáveis em `/usr/bin`, os helpers em `/usr/lib/eazy` e a man page em `/usr/share/man`. Não instala cópias executáveis em HOME nem em `/usr/local/bin`; configurações e dados do usuário permanecem em `~/.config/eazy`. O pacote Debian é `amd64`, pois inclui o monitor compilado `full` para x86_64.

## Demonstração Windows

A pasta [`windows-demo/`](windows-demo/) contém um protótipo de navegação nativo limitado e um launcher para executar o Easy completo via WSL2. A versão completa ainda não é um porte nativo para Windows: ela executa no Linux/WSL, mantendo SQLite, watcher e demais componentes do ambiente Linux.

Leia [`windows-demo/README.md`](windows-demo/README.md) para instruções, requisitos e limites da demonstração.

## Versões

O histórico de alterações da linha 5.2.0 está em [`CHANGELOG.md`](CHANGELOG.md); a revisão publicada pelo executável é **45**. `VERSION` registra a versão-base `5.2.0`.

## Autoria

Desenvolvido por John B. Kersting.
