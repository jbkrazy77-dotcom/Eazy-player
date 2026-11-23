# Demonstração Windows do eazy 5.2.0 rev.45

Este pacote combina duas experiências distintas:

1. `Windows/eazy-win-demo.py`: protótipo de navegação **nativo no Windows**, sem dependências externas. É uma demonstração limitada de navegação, marcação amarela e Ctrl+K.
2. `Windows/Run-Full-Easy.ps1`: inicia o **Easy completo dentro do WSL2**. O executável principal é o `eazy` normal da raiz do ZIP enviado; os módulos auxiliares de SQLite, monitoramento, mídia e instalação vêm junto no bundle. O launcher usa o bundle local para instalar ou atualizar o Easy nos caminhos do sistema do WSL e inicia `/usr/bin/eazy`.

O protótipo nativo não é o Easy completo nem um porte nativo integral. Indexação SQLite, F9, player, watcher, listas e configurações são executados pelo Easy Linux dentro do WSL. Os dados e configurações dessa execução ficam no ambiente Linux da distribuição WSL (`~/.config/eazy`), não no perfil nativo do Windows.

## Easy completo no WSL2

Requer uma distribuição Linux WSL2 x86_64 instalada. No PowerShell, a partir desta pasta, execute:

```powershell
.\Windows\Run-Full-Easy.ps1
```

Ou use `Windows\Run-Full-Easy.cmd` para iniciar com duplo clique. Na primeira execução, ou quando o `eazy` do bundle for diferente do instalado, o launcher executa `install.sh`; isso pode solicitar sua senha `sudo` para instalar dependências e gravar os arquivos do programa em caminhos de sistema. Em Ubuntu/Debian:

```bash
sudo apt update
sudo apt install -y bash python3 fzf whiptail
```

O comando principal fica em `/usr/bin/eazy`, os companions CLI em `/usr/bin`, os helpers em `/usr/lib/eazy` e a man page em `/usr/share/man/man1`. O launcher não copia executáveis do Easy para HOME nem para `/usr/local/bin`; as configurações e dados do usuário permanecem em `~/.config/eazy`.

Para construir o executável Linux protegido, também são necessários `gcc` e os headers de zlib:

```bash
sudo apt install -y build-essential zlib1g-dev
cd /mnt/c/caminho/ate/Eazy-player-windows-demo-5.2.0-rev45/windows-demo/Easy/eazy-5.2.0-rev45
./tools/compilar-eazy.sh ./eazy ./bin/eazy-linux-x86_64
```

O compilador acompanha o código-fonte em `Easy/eazy-5.2.0-rev45/tools/compilar-eazy.sh`; ele não altera o `eazy` original. O pacote também inclui o monitor C (`full.c`) e o executável Linux `full`. Reprodutores e utilitários de mídia são opcionais e dependem da configuração do WSL.

O bundle-fonte permanece na pasta escolhida no Windows; a instalação operacional do programa ocorre nos diretórios de sistema do WSL. O launcher não mantém uma segunda cópia executável do Easy em `~/.local/share`.

## Protótipo nativo limitado

Requer Python 3 para Windows. Execute:

```powershell
py -3 .\Windows\eazy-win-demo.py "$env:USERPROFILE"
```

Sem argumento, começa na pasta atual. Para testar uma pasta de rede, passe o caminho UNC entre aspas. Teclas: setas para mover, Enter para abrir, Backspace para voltar, Espaço para marcar/desmarcar amarelo, Ctrl+K para o menu de ações e `Q` para sair.

Teste sintético da enumeração do protótipo:

```powershell
py -3 .\Windows\eazy-win-demo.py --self-test
```

Esse teste verifica apenas a prova de conceito nativa. A operação do Easy completo precisa ser validada em uma máquina Windows real com WSL2.
