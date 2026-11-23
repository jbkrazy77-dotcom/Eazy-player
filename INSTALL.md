# Instalação do eazy 5.2.0 rev.45

## Requisitos essenciais

Em Ubuntu/Debian ou numa distribuição Linux do WSL2:

```bash
sudo apt update
sudo apt install -y bash python3 fzf whiptail
```

`mpv`, `ffmpeg`, `curl` e `wget` são opcionais, conforme as funcionalidades de mídia e rede utilizadas. A compilação do wrapper Linux requer `build-essential` e `zlib1g-dev`.

## Instalar a partir deste repositório

Use o bundle completo, que mantém o `eazy` da raiz como executável principal e traz seus módulos auxiliares ao lado:

```bash
cd windows-demo/Easy/eazy-5.2.0-rev45
./eazy --version
./install.sh
```

O instalador do Easy não deve apagar a configuração existente em `~/.config/eazy`. Revise as ações interativas antes de confirmá-las.

## Compilar o executável Linux x86_64

O compilador fornecido fica em `tools/compilar-eazy.sh`:

```bash
sudo apt install -y build-essential zlib1g-dev
cd windows-demo/Easy/eazy-5.2.0-rev45
mkdir -p bin
./tools/compilar-eazy.sh ./eazy ./bin/eazy-linux-x86_64
sha256sum ./bin/eazy-linux-x86_64
```

O script compila um wrapper C que incorpora uma cópia comprimida do fonte Bash e o executa com `/bin/bash`. O fonte `eazy` original não é modificado. O bundle inclui também `full.c` e o monitor `full` já compilado.

## Windows

Para executar a demonstração do Easy completo em Windows, use WSL2 e siga [`windows-demo/README.md`](windows-demo/README.md). O launcher inicia o Easy Linux dentro do WSL; o protótipo nativo Python é apenas uma demonstração limitada de navegação.
