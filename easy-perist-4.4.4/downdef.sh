#!/usr/bin/env bash

# ╔══════════════════════════════════════════════════════════════╗
# ║                                                              ║
# ║   ██████╗ ███████╗██╗   ██╗                                 ║
# ║   ██╔══██╗██╔════╝╚██╗ ██╔╝                                 ║
# ║   ██║  ██║█████╗   ╚████╔╝                                  ║
# ║   ██║  ██║██╔══╝    ╚██╔╝                                   ║
# ║   ██████╔╝███████╗   ██║                                    ║
# ║   ╚═════╝ ╚══════╝   ╚═╝                                    ║
# ║                                                              ║
# ║   ┌──────────────────────────────────────────────────────┐   ║
# ║   │  FileMirage Auto-Downloader + Tor                     │   ║
# ║   │  Versão: 2.0.0                                        │   ║
# ║   │  Autor: Manus AI                                      │   ║
# ║   │  Data: 2026-08-14                                     │   ║
# ║   └──────────────────────────────────────────────────────┘   ║
# ║                                                              ║
# ╚══════════════════════════════════════════════════════════════╝


script_atual=$(basename "$0")
# Não encerre processos pelo nome: o padrão também pode atingir esta instância.

DIRETORIO_DOWNLOAD="$HOME/Downloads/Links_Capturados"
DIR_TEMP="/tmp/aria_html_temp"
ARQUIVO_LOG="$DIRETORIO_DOWNLOAD/historico_links.txt"
ARQUIVO_UNPACK="$DIRETORIO_DOWNLOAD/unpackers.lst"
ARQUIVO_CLIP="$DIRETORIO_DOWNLOAD/clip.txt"
ARQUIVO_DEBUG="$DIRETORIO_DOWNLOAD/debug.log"
SQ=$'\x27'  # Aspas simples em ASCII (para uso no unpacker)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color


# ══════════════════════════════════════════════════════════════════
# FUNÇÃO: Monitor de status de downloads em tempo real
# ══════════════════════════════════════════════════════════════════
mostrar_status_downloads() {
    echo ""
    echo -e "${CYAN}┌────────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}│  ${YELLOW}STATUS DOS DOWNLOADS${NC}                                     ${CYAN}│${NC}"
    echo -e "${CYAN}└────────────────────────────────────────────────────────────────┘${NC}"

    # Ler o histórico e mostrar status
    if [ -f "$ARQUIVO_LOG" ]; then
        local total=$(grep -c "|" "$ARQUIVO_LOG" 2>/dev/null || echo 0)
        local ok=$(grep -c "Status: OK" "$ARQUIVO_LOG" 2>/dev/null || echo 0)
        local fail=$(grep -c "Status: FAIL" "$ARQUIVO_LOG" 2>/dev/null || echo 0)
        local extrai=$(grep -c "Status: EXTRAINDO" "$ARQUIVO_LOG" 2>/dev/null || echo 0)

        echo -e "  ${GREEN}Total:${NC} $total | ${GREEN}OK:${NC} $ok | ${RED}Falha:${NC} $fail | ${YELLOW}Extraindo:${NC} $extrai"
        echo ""

        # Mostrar últimos 5 downloads
        echo -e "  ${CYAN}Últimos downloads:${NC}"
        tail -n 5 "$ARQUIVO_LOG" | while IFS= read -r line; do
            if echo "$line" | grep -q "Status: OK"; then
                echo -e "  ${GREEN}✅${NC} $(echo "$line" | sed 's/.*| Status:/Status:/')"
            elif echo "$line" | grep -q "Status: FAIL"; then
                echo -e "  ${RED}❌${NC} $(echo "$line" | sed 's/.*| Status:/Status:/')"
            elif echo "$line" | grep -q "Status: EXTRAINDO"; then
                echo -e "  ${YELLOW}⏳${NC} $(echo "$line" | sed 's/.*| Status:/Status:/')"
            else
                echo -e "  ${BLUE}ℹ️${NC} $(echo "$line" | sed 's/.*| Status:/Status:/')"
            fi
        done
    else
        echo -e "  ${YELLOW}Nenhum download registrado ainda.${NC}"
    fi
    echo ""
}

# Mostrar status inicial
mostrar_status_downloads


mkdir -p "$DIRETORIO_DOWNLOAD" "$DIR_TEMP"

# Limpa o arquivo de debug ao iniciar
> "$ARQUIVO_DEBUG"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] ======== INICIANDO SCRIPT ========" >> "$ARQUIVO_DEBUG"

# Verifica dependências essenciais
for cmd in zenity grep sed wget awk curl; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "Erro: o utilitário essencial '$cmd' não está instalado." >&2
        exit 1
    fi
done

# Clipboard: precisa de pelo menos um leitor
if ! command -v wl-paste >/dev/null 2>&1 && ! command -v xsel >/dev/null 2>&1 && ! command -v xclip >/dev/null 2>&1; then
    echo "Erro: nenhum leitor de clipboard encontrado (instale wl-clipboard OU xsel OU xclip)." >&2
    exit 1
fi

# Avisa qual método de clipboard será usado
if command -v wl-paste >/dev/null 2>&1; then
    echo "[*] Clipboard: usando wl-paste (Wayland)"
elif command -v xsel >/dev/null 2>&1; then
    echo "[*] Clipboard: usando xsel (X11)"
else
    echo "[*] Clipboard: usando xclip (X11)"
fi

# ===== CLIPBOARD MELHORADO (X11 + Wayland) =====
ler_clipboard() {
    local conteudo=""

    # 1. Wayland (wl-paste) - prioridade
    if command -v wl-paste >/dev/null 2>&1; then
        conteudo=$(wl-paste --no-newline 2>/dev/null)
        if [ -n "$conteudo" ]; then
            printf '%s' "$conteudo"
            return
        fi
    fi

    # 2. xsel (X11)
    if command -v xsel >/dev/null 2>&1; then
        conteudo=$(xsel --clipboard --output 2>/dev/null)
        if [ -n "$conteudo" ]; then
            printf '%s' "$conteudo"
            return
        fi
    fi

    # 3. xclip (fallback X11)
    if command -v xclip >/dev/null 2>&1; then
        conteudo=$(xclip -selection clipboard -o 2>/dev/null)
        if [ -n "$conteudo" ]; then
            printf '%s' "$conteudo"
            return
        fi
    fi

    # Nada funcionou
    printf ''
}

# Uma notificação ausente não deve interromper o downloader.
if ! command -v notify-send >/dev/null 2>&1; then
    notify-send() { :; }
fi

# Inicia Tor apenas se ele estiver instalado; links diretos não dependem dele.
if command -v tor >/dev/null 2>&1 && ! pgrep -x "tor" >/dev/null 2>&1; then
    echo "[!] Tor não está rodando. Iniciando..."
    if command -v sudo >/dev/null 2>&1; then
        sudo systemctl start tor 2>/dev/null || tor &
    else
        tor &
    fi
    sleep 3
fi

# ┌─────────────────────────────────────────────────────────────────┐
# │  Banner de inicialização com cores                               │
# └─────────────────────────────────────────────────────────────────┘

echo ""
echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║${NC}                                                              ${CYAN}║${NC}"
echo -e "${CYAN}║${NC}  ${YELLOW}FileMirage Auto-Downloader${NC}                            ${CYAN}║${NC}"
echo -e "${CYAN}║${NC}  ${GREEN}Versão:${NC} 2.0.0                                      ${CYAN}║${NC}"
echo -e "${CYAN}║${NC}  ${GREEN}Autor:${NC}  Manus AI                                   ${CYAN}║${NC}"
echo -e "${CYAN}║${NC}  ${GREEN}Data:${NC}   2026-08-14                                 ${CYAN}║${NC}"
echo -e "${CYAN}║${NC}                                                              ${CYAN}║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${GREEN}=== SISTEMA DE DOWNLOAD ROBUSTO ATIVO (FileMirage + Tor) ===${NC}"
echo -e "${BLUE}DEBUG: Clipboard será registrado em:${NC} $ARQUIVO_CLIP"
echo -e "${BLUE}DEBUG: Log de debug em:${NC} $ARQUIVO_DEBUG"
echo ""
echo "DEBUG: Clipboard será registrado em: $ARQUIVO_CLIP"
echo "DEBUG: Log de debug em: $ARQUIVO_DEBUG"

# Limpa o arquivo clip.txt ao iniciar
> "$ARQUIVO_CLIP"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] INICIANDO MONITORAMENTO" >> "$ARQUIVO_CLIP"

ultimo_conteudo=""

while true; do
    conteudo_atual=$(ler_clipboard)

    # SÓ ESCREVE NO CLIP.TXT QUANDO HOUVER MUDANÇA
    if [ "$conteudo_atual" != "$ultimo_conteudo" ] && [ -n "$conteudo_atual" ]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] NOVO CONTEÚDO DETECTADO: $conteudo_atual" >> "$ARQUIVO_CLIP"
        ultimo_conteudo="$conteudo_atual"

        # --- DETECTA SE É FILEMIRAGE ---
        if echo "$conteudo_atual" | grep -qE "filemirage\.com/file/"; then

            echo "[$(date '+%Y-%m-%d %H:%M:%S')] FILEMIRAGE DETECTADO" >> "$ARQUIVO_CLIP"

            # Pede senha e remove espaços do início e fim
            senha_digitada=$(zenity --entry --title="Senha do Arquivo" --text="Link do FileMirage detectado!\nDigite a senha para este arquivo:" --hide-text 2>/dev/null | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            [ -z "$senha_digitada" ] && senha_digitada="N/A"

            echo "[$(date '+%Y-%m-%d %H:%M:%S')] SENHA: $senha_digitada" >> "$ARQUIVO_CLIP"
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] SENHA ORIGINAL: '$senha_digitada'" >> "$ARQUIVO_DEBUG"

            # === LINK DIRETO DO FILEMIRAGE ===
            if echo "$conteudo_atual" | grep -qE "filemirage\.com/file/direct/"; then
                link_real="$conteudo_atual"

                echo "[$(date '+%Y-%m-%d %H:%M:%S')] LINK DIRETO DETECTADO" >> "$ARQUIVO_CLIP"
                echo "[$(date '+%Y-%m-%d %H:%M:%S')] | Link: $link_real | Senha: $senha_digitada | Status: INICIADO (FileMirage Direct)" >> "$ARQUIVO_LOG"
                echo "[$(date '+%Y-%m-%d %H:%M:%S')] LINK DIRETO: $link_real" >> "$ARQUIVO_DEBUG"
                notify-send "Aria2c" "Baixando arquivo do FileMirage..."

                (
                    echo "[$(date '+%Y-%m-%d %H:%M:%S')] INICIANDO DOWNLOAD DIRETO" >> "$ARQUIVO_CLIP"
                    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ======== INICIANDO DOWNLOAD DIRETO ========" >> "$ARQUIVO_DEBUG"

                    # Salva snapshot antes do download
                    find "$DIRETORIO_DOWNLOAD" -maxdepth 1 -type f ! -name "*.txt" ! -name "*.lst" ! -name "*.log" -printf "%f\n" > /tmp/snapshot_antes.txt
                    echo "[$(date '+%Y-%m-%d %H:%M:%S')] SNAPSHOT ANTES: $(cat /tmp/snapshot_antes.txt | tr '\n' ' ')" >> "$ARQUIVO_DEBUG"

                    # Extrai o nome do arquivo da URL
                    nome_arquivo_url=$(basename "$link_real" | cut -d'?' -f1)
                    if [ -n "$nome_arquivo_url" ]; then
                        notify-send "Aria2c" "Baixando: $nome_arquivo_url"
                    fi

                    # Download com aria2c otimizado
                    echo "[$(date '+%Y-%m-%d %H:%M:%S')] COMANDO: aria2c -d \"$DIRETORIO_DOWNLOAD\" -x16 -s16 -k1M --file-allocation=none --console-log-level=error --content-disposition=true \"$link_real\"" >> "$ARQUIVO_DEBUG"
                    aria2c -d "$DIRETORIO_DOWNLOAD" -x16 -s16 -k1M --file-allocation=none --console-log-level=error --content-disposition=true "$link_real" &> /dev/null
                    status_dl=$?
                    echo "[$(date '+%Y-%m-%d %H:%M:%S')] STATUS DOWNLOAD: $status_dl" >> "$ARQUIVO_DEBUG"

                    echo "[$(date '+%Y-%m-%d %H:%M:%S')] STATUS DOWNLOAD: $status_dl" >> "$ARQUIVO_CLIP"

                    if [ $status_dl -eq 0 ]; then
                        # Identifica o arquivo baixado
                        nome_arquivo=""
                        echo "[$(date '+%Y-%m-%d %H:%M:%S')] PROCURANDO NOVO ARQUIVO..." >> "$ARQUIVO_DEBUG"

                        # Lista todos os arquivos atuais (exceto logs)
                        find "$DIRETORIO_DOWNLOAD" -maxdepth 1 -type f ! -name "*.txt" ! -name "*.lst" ! -name "*.log" -printf "%f\n" > /tmp/snapshot_depois.txt
                        echo "[$(date '+%Y-%m-%d %H:%M:%S')] SNAPSHOT DEPOIS: $(cat /tmp/snapshot_depois.txt | tr '\n' ' ')" >> "$ARQUIVO_DEBUG"

                        # Procura por arquivos que não estavam no snapshot antes
                        while IFS= read -r arquivo; do
                            if [ -n "$arquivo" ] && ! grep -qx "$arquivo" /tmp/snapshot_antes.txt; then
                                nome_arquivo="$arquivo"
                                echo "[$(date '+%Y-%m-%d %H:%M:%S')] NOVO ARQUIVO ENCONTRADO: $nome_arquivo" >> "$ARQUIVO_DEBUG"
                                break
                            fi
                        done < /tmp/snapshot_depois.txt

                        # Se não encontrou, pega o arquivo mais recente (exceto logs)
                        if [ -z "$nome_arquivo" ]; then
                            echo "[$(date '+%Y-%m-%d %H:%M:%S')] NENHUM NOVO ARQUIVO ENCONTRADO, USANDO O MAIS RECENTE" >> "$ARQUIVO_DEBUG"
                            nome_arquivo=$(find "$DIRETORIO_DOWNLOAD" -maxdepth 1 -type f ! -name "*.txt" ! -name "*.lst" ! -name "*.log" -printf "%T@ %f\n" | sort -nr | head -n1 | cut -d' ' -f2-)
                        fi

                        rm -f /tmp/snapshot_depois.txt

                        if [ -z "$nome_arquivo" ]; then
                            echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERRO: NENHUM ARQUIVO IDENTIFICADO" >> "$ARQUIVO_DEBUG"
                            notify-send "Erro" "❌ Não foi possível identificar o arquivo baixado!"
                            exit 1
                        fi

                        echo "[$(date '+%Y-%m-%d %H:%M:%S')] ARQUIVO: $nome_arquivo" >> "$ARQUIVO_CLIP"
                        echo "[$(date '+%Y-%m-%d %H:%M:%S')] ARQUIVO IDENTIFICADO: $nome_arquivo" >> "$ARQUIVO_DEBUG"

                        # ATUALIZA O HISTÓRICO
                        echo "[$(date "+%Y-%m-%d %H:%M:%S")] | Link: $link_real | Senha: $senha_digitada | Status: OK (FileMirage Direct)" >> "$ARQUIVO_LOG"

                        # Notificação com o nome do arquivo
                        notify-send "Download Concluído" "✅ Arquivo baixado: $nome_arquivo"
                        # Atualizar status
                        mostrar_status_downloads

                        # =============================================
                        # CRIA DIRETÓRIO, MOVE E DESCOMPACTA
                        # =============================================
                        extensao="${nome_arquivo##*.}"
                        extensao_lower=$(echo "$extensao" | tr '[:upper:]' '[:lower:]')

                        # Nome do diretório = nome do arquivo sem extensão
                        nome_base="${nome_arquivo%.*}"
                        DIR_ARQUIVO="$DIRETORIO_DOWNLOAD/$nome_base"

                        echo "[$(date '+%Y-%m-%d %H:%M:%S')] EXTENSAO: $extensao_lower" >> "$ARQUIVO_CLIP"
                        echo "[$(date '+%Y-%m-%d %H:%M:%S')] DIRETORIO: $DIR_ARQUIVO" >> "$ARQUIVO_CLIP"
                        echo "[$(date '+%Y-%m-%d %H:%M:%S')] EXTENSAO: $extensao_lower, DIRETORIO: $DIR_ARQUIVO" >> "$ARQUIVO_DEBUG"

                        # Cria o diretório
                        if [ -d "$DIR_ARQUIVO" ]; then
                            contador_dir=2
                            while [ -d "$DIRETORIO_DOWNLOAD/${nome_base}_${contador_dir}" ]; do
                                contador_dir=$((contador_dir + 1))
                            done
                            nome_base="${nome_base}_${contador_dir}"
                            DIR_ARQUIVO="$DIRETORIO_DOWNLOAD/$nome_base"
                        fi
                        mkdir -p "$DIR_ARQUIVO"
                        echo "[$(date '+%Y-%m-%d %H:%M:%S')] DIRETÓRIO CRIADO: $DIR_ARQUIVO" >> "$ARQUIVO_DEBUG"

                        # Move o arquivo para o diretório
                        echo "[$(date '+%Y-%m-%d %H:%M:%S')] MOVENDO: $DIRETORIO_DOWNLOAD/$nome_arquivo -> $DIR_ARQUIVO/" >> "$ARQUIVO_DEBUG"
                        mv "$DIRETORIO_DOWNLOAD/$nome_arquivo" "$DIR_ARQUIVO/"
                        echo "[$(date '+%Y-%m-%d %H:%M:%S')] ARQUIVO MOVIDO PARA: $DIR_ARQUIVO" >> "$ARQUIVO_CLIP"

                        # Só descompacta se for RAR, ZIP ou 7Z
                        case "$extensao_lower" in
                            rar)
                                echo "[$(date '+%Y-%m-%d %H:%M:%S')] ======== INICIANDO DESCOMPACTAÇÃO RAR ========" >> "$ARQUIVO_DEBUG"
                                cd "$DIR_ARQUIVO"
                                echo "[$(date '+%Y-%m-%d %H:%M:%S')] NOVO DIR: $(pwd)" >> "$ARQUIVO_DEBUG"
                                echo "[$(date '+%Y-%m-%d %H:%M:%S')] ARQUIVO: $nome_arquivo" >> "$ARQUIVO_DEBUG"
                                echo "[$(date '+%Y-%m-%d %H:%M:%S')] SENHA: '$senha_digitada'" >> "$ARQUIVO_DEBUG"

                                # CRIA O ARQUIVO U.SH COM O COMANDO
                                if [ "$senha_digitada" != "N/A" ]; then
                                    cmd_unpack="rar x \"$nome_arquivo\" -p${SQ}${senha_digitada}${SQ}"
                                    echo "#!/bin/bash" > "$DIR_ARQUIVO/u.sh"
                                    echo "$cmd_unpack" >> "$DIR_ARQUIVO/u.sh"
                                    chmod +x "$DIR_ARQUIVO/u.sh"
                                    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ARQUIVO CRIADO: $DIR_ARQUIVO/u.sh" >> "$ARQUIVO_DEBUG"
                                else
                                    cmd_unpack="rar x \"$nome_arquivo\""
                                    echo "#!/bin/bash" > "$DIR_ARQUIVO/u.sh"
                                    echo "$cmd_unpack" >> "$DIR_ARQUIVO/u.sh"
                                    chmod +x "$DIR_ARQUIVO/u.sh"
                                    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ARQUIVO CRIADO: $DIR_ARQUIVO/u.sh" >> "$ARQUIVO_DEBUG"
                                fi

                                echo "[$(date '+%Y-%m-%d %H:%M:%S')] COMANDO: $cmd_unpack" >> "$ARQUIVO_DEBUG"
                                rar x "$nome_arquivo" -p"$senha_digitada" 2>&1 | tee -a "$ARQUIVO_DEBUG"
                                status_unpack=${PIPESTATUS[0]}

                                echo "[$(date '+%Y-%m-%d %H:%M:%S')] STATUS UNPACK: $status_unpack" >> "$ARQUIVO_DEBUG"
                                cd "$DIRETORIO_DOWNLOAD"
                                echo "[$(date '+%Y-%m-%d %H:%M:%S')] UNPACK RAR STATUS: $status_unpack" >> "$ARQUIVO_CLIP"
                                echo "[$(date '+%Y-%m-%d %H:%M:%S')] CMD: cd \"$DIR_ARQUIVO\" && $cmd_unpack" >> "$ARQUIVO_UNPACK"
                                if [ $status_unpack -eq 0 ]; then
                                    notify-send "Sucesso" "✅ RAR descompactado: $nome_arquivo em: $DIR_ARQUIVO"
                                else
                                    notify-send "Erro" "❌ Falha ao descompactar RAR: $nome_arquivo!"
                                fi
                                ;;
                            zip|7z)
                                echo "[$(date '+%Y-%m-%d %H:%M:%S')] ======== INICIANDO DESCOMPACTAÇÃO 7Z/ZIP ========" >> "$ARQUIVO_DEBUG"
                                cd "$DIR_ARQUIVO"
                                echo "[$(date '+%Y-%m-%d %H:%M:%S')] NOVO DIR: $(pwd)" >> "$ARQUIVO_DEBUG"
                                echo "[$(date '+%Y-%m-%d %H:%M:%S')] ARQUIVO: $nome_arquivo" >> "$ARQUIVO_DEBUG"
                                echo "[$(date '+%Y-%m-%d %H:%M:%S')] SENHA: '$senha_digitada'" >> "$ARQUIVO_DEBUG"

                                # CRIA O ARQUIVO U.SH COM O COMANDO
                                if [ "$senha_digitada" != "N/A" ]; then
                                    cmd_unpack="7z x \"$nome_arquivo\" -p${SQ}${senha_digitada}${SQ}"
                                    echo "#!/bin/bash" > "$DIR_ARQUIVO/u.sh"
                                    echo "$cmd_unpack" >> "$DIR_ARQUIVO/u.sh"
                                    chmod +x "$DIR_ARQUIVO/u.sh"
                                    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ARQUIVO CRIADO: $DIR_ARQUIVO/u.sh" >> "$ARQUIVO_DEBUG"
                                else
                                    cmd_unpack="7z x \"$nome_arquivo\""
                                    echo "#!/bin/bash" > "$DIR_ARQUIVO/u.sh"
                                    echo "$cmd_unpack" >> "$DIR_ARQUIVO/u.sh"
                                    chmod +x "$DIR_ARQUIVO/u.sh"
                                    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ARQUIVO CRIADO: $DIR_ARQUIVO/u.sh" >> "$ARQUIVO_DEBUG"
                                fi

                                echo "[$(date '+%Y-%m-%d %H:%M:%S')] COMANDO: $cmd_unpack" >> "$ARQUIVO_DEBUG"
                                7z x "$nome_arquivo" -p"$senha_digitada" 2>&1 | tee -a "$ARQUIVO_DEBUG"
                                status_unpack=${PIPESTATUS[0]}

                                echo "[$(date '+%Y-%m-%d %H:%M:%S')] STATUS UNPACK: $status_unpack" >> "$ARQUIVO_DEBUG"
                                cd "$DIRETORIO_DOWNLOAD"
                                echo "[$(date '+%Y-%m-%d %H:%M:%S')] UNPACK 7Z STATUS: $status_unpack" >> "$ARQUIVO_CLIP"
                                echo "[$(date '+%Y-%m-%d %H:%M:%S')] CMD: cd \"$DIR_ARQUIVO\" && $cmd_unpack" >> "$ARQUIVO_UNPACK"
                                if [ $status_unpack -eq 0 ]; then
                                    notify-send "Sucesso" "✅ 7Z/ZIP descompactado: $nome_arquivo em: $DIR_ARQUIVO"
                                else
                                    notify-send "Erro" "❌ Falha ao descompactar 7Z/ZIP: $nome_arquivo!"
                                fi
                                ;;
                            *)
                                echo "[$(date '+%Y-%m-%d %H:%M:%S')] ARQUIVO NÃO COMPACTADO (${extensao_lower}) - APENAS MOVIDO" >> "$ARQUIVO_CLIP"
                                notify-send "Sucesso" "📁 Arquivo movido: $nome_arquivo para: $DIR_ARQUIVO"
                                ;;
                        esac

                    else
                        echo "[$(date '+%Y-%m-%d %H:%M:%S')] DOWNLOAD FALHOU" >> "$ARQUIVO_CLIP"
                        echo "[$(date '+%Y-%m-%d %H:%M:%S')] | Link: $link_real | Senha: $senha_digitada | Status: FAIL (FileMirage Direct)" >> "$ARQUIVO_LOG"
                        notify-send "Erro" "❌ Falha no download do FileMirage Direct!"
                    fi

                    rm -f /tmp/snapshot_antes.txt
                    echo "[$(date '+%Y-%m-%d %H:%M:%S')] FIM PROCESSO DIRETO" >> "$ARQUIVO_CLIP"
                    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ======== FIM DOWNLOAD DIRETO ========" >> "$ARQUIVO_DEBUG"
                ) &

            # === PÁGINA NORMAL DO FILEMIRAGE ===
            else
                echo "[$(date '+%Y-%m-%d %H:%M:%S')] PÁGINA FILEMIRAGE DETECTADA" >> "$ARQUIVO_CLIP"

                zenity --notification --text="Buscando link real no FileMirage..." 2>/dev/null
                echo "[$(date '+%Y-%m-%d %H:%M:%S')] | Link: $conteudo_atual | Senha: $senha_digitada | Status: EXTRAINDO (FileMirage Page)" >> "$ARQUIVO_LOG"

                nohup bash -c '
                    url_pagina="$1"
                    dir_destino="$2"
                    dir_temp="$3"
                    arq_log="$4"
                    senha_obj="$5"
                    unpack_file="$6"
                    clip_file="$7"
                    debug_file="$8"

                    echo "[$(date "+%Y-%m-%d %H:%M:%S")] ======== INICIANDO EXTRAÇÃO PÁGINA ========" >> "$debug_file"
                    echo "[$(date "+%Y-%m-%d %H:%M:%S")] URL: $url_pagina" >> "$debug_file"
                    echo "[$(date "+%Y-%m-%d %H:%M:%S")] SENHA: '"$senha_obj"'" >> "$debug_file"

                    echo "[$(date "+%Y-%m-%d %H:%M:%S")] EXTRAINDO LINK DA PÁGINA" >> "$clip_file"

                    caminho_html="$dir_temp/pagina_$RANDOM.html"
                    echo "[$(date "+%Y-%m-%d %H:%M:%S")] wget -qO \"$caminho_html\" \"$url_pagina\"" >> "$debug_file"
                    wget -qO "$caminho_html" "$url_pagina"

                    if [ -f "$caminho_html" ]; then
                        link_relativo=$(grep -oE "/file/direct/[a-zA-Z0-9_.-]+" "$caminho_html" | head -n 1)
                        echo "[$(date "+%Y-%m-%d %H:%M:%S")] LINK RELATIVO: $link_relativo" >> "$debug_file"
                        rm -f "$caminho_html"

                        if [ -n "$link_relativo" ]; then
                            dominio_base=$(echo "$url_pagina" | awk -F/ '\''{print $1"//"$3}'\'')
                            link_real="${dominio_base}${link_relativo}"

                            echo "[$(date "+%Y-%m-%d %H:%M:%S")] LINK EXTRAÍDO: $link_real" >> "$clip_file"
                            echo "[$(date "+%Y-%m-%d %H:%M:%S")] LINK EXTRAÍDO: $link_real" >> "$debug_file"
                            echo "[$(date "+%Y-%m-%d %H:%M:%S")] | Link Extraído: $link_real | Senha: $senha_obj | Status: INICIADO" >> "$arq_log"

                            # Extrai o nome do arquivo da URL
                            nome_arquivo_url=$(basename "$link_real" | cut -d"?" -f1)
                            if [ -n "$nome_arquivo_url" ]; then
                                notify-send "Aria2c" "Baixando: $nome_arquivo_url"
                            else
                                notify-send "Aria2c" "Extraído! Baixando..."
                            fi

                            find "$dir_destino" -maxdepth 1 -type f ! -name "*.txt" ! -name "*.lst" ! -name "*.log" -printf "%f\n" > /tmp/snapshot_antes.txt
                            echo "[$(date "+%Y-%m-%d %H:%M:%S")] SNAPSHOT ANTES: $(cat /tmp/snapshot_antes.txt | tr "\n" " ")" >> "$debug_file"

                            echo "[$(date "+%Y-%m-%d %H:%M:%S")] COMANDO: aria2c -d \"$dir_destino\" -x16 -s16 -k1M --file-allocation=none --console-log-level=error --content-disposition=true \"$link_real\"" >> "$debug_file"
                            aria2c -d "$dir_destino" -x16 -s16 -k1M --file-allocation=none --console-log-level=error --content-disposition=true "$link_real" &> /dev/null
                            status_dl=$?
                            echo "[$(date "+%Y-%m-%d %H:%M:%S")] STATUS DOWNLOAD: $status_dl" >> "$debug_file"

                            echo "[$(date "+%Y-%m-%d %H:%M:%S")] STATUS DOWNLOAD PÁGINA: $status_dl" >> "$clip_file"

                            if [ $status_dl -eq 0 ]; then
                                nome_arquivo=""
                                echo "[$(date "+%Y-%m-%d %H:%M:%S")] PROCURANDO NOVO ARQUIVO..." >> "$debug_file"

                                find "$dir_destino" -maxdepth 1 -type f ! -name "*.txt" ! -name "*.lst" ! -name "*.log" -printf "%f\n" > /tmp/snapshot_depois.txt
                                echo "[$(date "+%Y-%m-%d %H:%M:%S")] SNAPSHOT DEPOIS: $(cat /tmp/snapshot_depois.txt | tr "\n" " ")" >> "$debug_file"

                                while IFS= read -r arquivo; do
                                    if [ -n "$arquivo" ] && ! grep -qx "$arquivo" /tmp/snapshot_antes.txt; then
                                        nome_arquivo="$arquivo"
                                        echo "[$(date "+%Y-%m-%d %H:%M:%S")] NOVO ARQUIVO ENCONTRADO: $nome_arquivo" >> "$debug_file"
                                        break
                                    fi
                                done < /tmp/snapshot_depois.txt

                                if [ -z "$nome_arquivo" ]; then
                                    echo "[$(date "+%Y-%m-%d %H:%M:%S")] NENHUM NOVO ARQUIVO ENCONTRADO, USANDO O MAIS RECENTE" >> "$debug_file"
                                    nome_arquivo=$(find "$dir_destino" -maxdepth 1 -type f ! -name "*.txt" ! -name "*.lst" ! -name "*.log" -printf "%T@ %f\n" | sort -nr | head -n1 | cut -d" " -f2-)
                                fi

                                rm -f /tmp/snapshot_depois.txt

                                if [ -z "$nome_arquivo" ]; then
                                    echo "[$(date "+%Y-%m-%d %H:%M:%S")] ERRO: NENHUM ARQUIVO IDENTIFICADO" >> "$debug_file"
                                    notify-send "Erro" "❌ Não foi possível identificar o arquivo baixado!"
                                    exit 1
                                fi

                                echo "[$(date "+%Y-%m-%d %H:%M:%S")] ARQUIVO PÁGINA: $nome_arquivo" >> "$clip_file"
                                echo "[$(date "+%Y-%m-%d %H:%M:%S")] ARQUIVO IDENTIFICADO: $nome_arquivo" >> "$debug_file"

                                echo "[$(date "+%Y-%m-%d %H:%M:%S")] | Link: $link_real | Senha: $senha_obj | Status: OK (FileMirage Extraído)" >> "$arq_log"

                                notify-send "Download Concluído" "✅ Arquivo baixado: $nome_arquivo"
                        # O subprocesso bash -c não herda esta função.

                                # =============================================
                                # CRIA DIRETÓRIO, MOVE E DESCOMPACTA
                                # =============================================
                                extensao="${nome_arquivo##*.}"
                                extensao_lower=$(echo "$extensao" | tr "[:upper:]" "[:lower:]")

                                nome_base="${nome_arquivo%.*}"
                                DIR_ARQUIVO="$dir_destino/$nome_base"

                                echo "[$(date "+%Y-%m-%d %H:%M:%S")] EXTENSAO: $extensao_lower" >> "$clip_file"
                                echo "[$(date "+%Y-%m-%d %H:%M:%S")] DIRETORIO: $DIR_ARQUIVO" >> "$clip_file"
                                echo "[$(date "+%Y-%m-%d %H:%M:%S")] EXTENSAO: $extensao_lower, DIRETORIO: $DIR_ARQUIVO" >> "$debug_file"

                                if [ -d "$DIR_ARQUIVO" ]; then
                                    contador_dir=2
                                    while [ -d "$dir_destino/${nome_base}_${contador_dir}" ]; do
                                        contador_dir=$((contador_dir + 1))
                                    done
                                    nome_base="${nome_base}_${contador_dir}"
                                    DIR_ARQUIVO="$dir_destino/$nome_base"
                                fi
                                mkdir -p "$DIR_ARQUIVO"
                                echo "[$(date "+%Y-%m-%d %H:%M:%S")] DIRETÓRIO CRIADO: $DIR_ARQUIVO" >> "$debug_file"

                                echo "[$(date "+%Y-%m-%d %H:%M:%S")] MOVENDO: $dir_destino/$nome_arquivo -> $DIR_ARQUIVO/" >> "$debug_file"
                                mv "$dir_destino/$nome_arquivo" "$DIR_ARQUIVO/"
                                echo "[$(date "+%Y-%m-%d %H:%M:%S")] ARQUIVO MOVIDO PARA: $DIR_ARQUIVO" >> "$clip_file"

                                case "$extensao_lower" in
                                    rar)
                                        echo "[$(date "+%Y-%m-%d %H:%M:%S")] ======== INICIANDO DESCOMPACTAÇÃO RAR ========" >> "$debug_file"
                                        cd "$DIR_ARQUIVO"
                                        echo "[$(date "+%Y-%m-%d %H:%M:%S")] NOVO DIR: $(pwd)" >> "$debug_file"
                                        echo "[$(date "+%Y-%m-%d %H:%M:%S")] ARQUIVO: $nome_arquivo" >> "$debug_file"
                                        echo "[$(date "+%Y-%m-%d %H:%M:%S")] SENHA: '"$senha_obj"'" >> "$debug_file"

                                        if [ "$senha_obj" != "N/A" ]; then
                                            cmd_unpack="rar x \"$nome_arquivo\" -p${SQ}${senha_obj}${SQ}"
                                            echo "#!/bin/bash" > "$DIR_ARQUIVO/u.sh"
                                            echo "$cmd_unpack" >> "$DIR_ARQUIVO/u.sh"
                                            chmod +x "$DIR_ARQUIVO/u.sh"
                                            echo "[$(date "+%Y-%m-%d %H:%M:%S")] ARQUIVO CRIADO: $DIR_ARQUIVO/u.sh" >> "$debug_file"
                                        else
                                            cmd_unpack="rar x \"$nome_arquivo\""
                                            echo "#!/bin/bash" > "$DIR_ARQUIVO/u.sh"
                                            echo "$cmd_unpack" >> "$DIR_ARQUIVO/u.sh"
                                            chmod +x "$DIR_ARQUIVO/u.sh"
                                            echo "[$(date "+%Y-%m-%d %H:%M:%S")] ARQUIVO CRIADO: $DIR_ARQUIVO/u.sh" >> "$debug_file"
                                        fi

                                        echo "[$(date "+%Y-%m-%d %H:%M:%S")] COMANDO: $cmd_unpack" >> "$debug_file"
                                        rar x "$nome_arquivo" -p"$senha_obj" 2>&1 | tee -a "$debug_file"
                                        status_unpack=$?

                                        echo "[$(date "+%Y-%m-%d %H:%M:%S")] STATUS UNPACK: $status_unpack" >> "$debug_file"
                                        cd "$dir_destino"
                                        echo "[$(date "+%Y-%m-%d %H:%M:%S")] UNPACK RAR STATUS: $status_unpack" >> "$clip_file"
                                        echo "[$(date "+%Y-%m-%d %H:%M:%S")] CMD: cd \"$DIR_ARQUIVO\" && $cmd_unpack" >> "$unpack_file"
                                        if [ $status_unpack -eq 0 ]; then
                                            notify-send "Sucesso" "✅ RAR descompactado: $nome_arquivo em: $DIR_ARQUIVO"
                                        else
                                            notify-send "Erro" "❌ Falha ao descompactar RAR: $nome_arquivo!"
                                        fi
                                        ;;
                                    zip|7z)
                                        echo "[$(date "+%Y-%m-%d %H:%M:%S")] ======== INICIANDO DESCOMPACTAÇÃO 7Z/ZIP ========" >> "$debug_file"
                                        cd "$DIR_ARQUIVO"
                                        echo "[$(date "+%Y-%m-%d %H:%M:%S")] NOVO DIR: $(pwd)" >> "$debug_file"
                                        echo "[$(date "+%Y-%m-%d %H:%M:%S")] ARQUIVO: $nome_arquivo" >> "$debug_file"
                                        echo "[$(date "+%Y-%m-%d %H:%M:%S")] SENHA: '"$senha_obj"'" >> "$debug_file"

                                        if [ "$senha_obj" != "N/A" ]; then
                                            cmd_unpack="7z x \"$nome_arquivo\" -p${SQ}${senha_obj}${SQ}"
                                            echo "#!/bin/bash" > "$DIR_ARQUIVO/u.sh"
                                            echo "$cmd_unpack" >> "$DIR_ARQUIVO/u.sh"
                                            chmod +x "$DIR_ARQUIVO/u.sh"
                                            echo "[$(date "+%Y-%m-%d %H:%M:%S")] ARQUIVO CRIADO: $DIR_ARQUIVO/u.sh" >> "$debug_file"
                                        else
                                            cmd_unpack="7z x \"$nome_arquivo\""
                                            echo "#!/bin/bash" > "$DIR_ARQUIVO/u.sh"
                                            echo "$cmd_unpack" >> "$DIR_ARQUIVO/u.sh"
                                            chmod +x "$DIR_ARQUIVO/u.sh"
                                            echo "[$(date "+%Y-%m-%d %H:%M:%S")] ARQUIVO CRIADO: $DIR_ARQUIVO/u.sh" >> "$debug_file"
                                        fi

                                        echo "[$(date "+%Y-%m-%d %H:%M:%S")] COMANDO: $cmd_unpack" >> "$debug_file"
                                        7z x "$nome_arquivo" -p"$senha_obj" 2>&1 | tee -a "$debug_file"
                                        status_unpack=$?

                                        echo "[$(date "+%Y-%m-%d %H:%M:%S")] STATUS UNPACK: $status_unpack" >> "$debug_file"
                                        cd "$dir_destino"
                                        echo "[$(date "+%Y-%m-%d %H:%M:%S")] UNPACK 7Z STATUS: $status_unpack" >> "$clip_file"
                                        echo "[$(date "+%Y-%m-%d %H:%M:%S")] CMD: cd \"$DIR_ARQUIVO\" && $cmd_unpack" >> "$unpack_file"
                                        if [ $status_unpack -eq 0 ]; then
                                            notify-send "Sucesso" "✅ 7Z/ZIP descompactado: $nome_arquivo em: $DIR_ARQUIVO"
                                        else
                                            notify-send "Erro" "❌ Falha ao descompactar 7Z/ZIP: $nome_arquivo!"
                                        fi
                                        ;;
                                    *)
                                        echo "[$(date "+%Y-%m-%d %H:%M:%S")] ARQUIVO NÃO COMPACTADO (${extensao_lower}) - APENAS MOVIDO" >> "$clip_file"
                                        notify-send "Sucesso" "📁 Arquivo movido: $nome_arquivo para: $DIR_ARQUIVO"
                                        ;;
                                esac

                            else
                                echo "[$(date "+%Y-%m-%d %H:%M:%S")] DOWNLOAD PÁGINA FALHOU" >> "$clip_file"
                                echo "[$(date "+%Y-%m-%d %H:%M:%S")] | Link Original: $url_pagina | Senha: $senha_obj | Status: FAIL (FileMirage Extraído)" >> "$arq_log"
                                notify-send "Erro" "❌ Falha no download da página!"
                            fi
                            rm -f /tmp/snapshot_antes.txt
                        fi
                    fi
                    echo "[$(date "+%Y-%m-%d %H:%M:%S")] ======== FIM EXTRAÇÃO PÁGINA ========" >> "$debug_file"
                ' _ "$conteudo_atual" "$DIRETORIO_DOWNLOAD" "$DIR_TEMP" "$ARQUIVO_LOG" "$senha_digitada" "$ARQUIVO_UNPACK" "$ARQUIVO_CLIP" "$ARQUIVO_DEBUG" &> /dev/null &
            fi

        # --- DETECTA SE É OUTRO LINK (NÃO FILEMIRAGE) ---
        elif echo "$conteudo_atual" | grep -qE "https?://[a-zA-Z0-9./?=_-]+"; then
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] LINK GENÉRICO DETECTADO" >> "$ARQUIVO_CLIP"

            senha_digitada=$(zenity --entry --title="Senha do Arquivo" --text="Link genérico detectado!\nDigite a senha (se houver):" --hide-text 2>/dev/null | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            [ -z "$senha_digitada" ] && senha_digitada="N/A"

            echo "[$(date '+%Y-%m-%d %H:%M:%S')] SENHA: $senha_digitada" >> "$ARQUIVO_CLIP"
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] SENHA ORIGINAL: '$senha_digitada'" >> "$ARQUIVO_DEBUG"
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] | Link: $conteudo_atual | Senha: $senha_digitada | Status: INICIADO (Tor)" >> "$ARQUIVO_LOG"

            (
                echo "[$(date '+%Y-%m-%d %H:%M:%S')] ======== INICIANDO DOWNLOAD GENÉRICO ========" >> "$ARQUIVO_DEBUG"
                echo "[$(date '+%Y-%m-%d %H:%M:%S')] INICIANDO DOWNLOAD GENÉRICO" >> "$ARQUIVO_CLIP"

                # Salva snapshot antes do download
                find "$DIRETORIO_DOWNLOAD" -maxdepth 1 -type f ! -name "*.txt" ! -name "*.lst" ! -name "*.log" -printf "%f\n" > /tmp/snapshot_antes.txt
                echo "[$(date '+%Y-%m-%d %H:%M:%S')] SNAPSHOT ANTES: $(cat /tmp/snapshot_antes.txt | tr '\n' ' ')" >> "$ARQUIVO_DEBUG"

                nome_arquivo_url=$(basename "$conteudo_atual" | cut -d'?' -f1)
                if [ -n "$nome_arquivo_url" ]; then
                    notify-send "Aria2c" "Baixando: $nome_arquivo_url"
                fi

                cd "$DIRETORIO_DOWNLOAD"
                # === ORDEM DOS DOWNLOADS GENÉRICOS: aria2c -> axel -> wget -> curl ===
                status_dl=127

                # TENTATIVA 1: aria2c
                if command -v aria2c >/dev/null 2>&1; then
                    echo "[$(date '+%Y-%m-%d %H:%M:%S')] TENTATIVA 1: aria2c" >> "$ARQUIVO_DEBUG"
                    echo "[$(date '+%Y-%m-%d %H:%M:%S')] COMANDO: aria2c -d \"$DIRETORIO_DOWNLOAD\" -x16 -s16 -k1M --file-allocation=none --max-tries=3 --console-log-level=error --content-disposition=true \"$conteudo_atual\"" >> "$ARQUIVO_DEBUG"
                    aria2c -d "$DIRETORIO_DOWNLOAD" -x16 -s16 -k1M --file-allocation=none --max-tries=3 --console-log-level=error --content-disposition=true "$conteudo_atual" &> /dev/null
                    status_dl=$?
                else
                    echo "[$(date '+%Y-%m-%d %H:%M:%S')] aria2c não instalado; pulando para axel" >> "$ARQUIVO_DEBUG"
                fi

                # TENTATIVA 2: axel via Tor
                if [ $status_dl -ne 0 ]; then
                    echo "[$(date '+%Y-%m-%d %H:%M:%S')] FALHA ARIA2C (status: $status_dl), TENTATIVA 2: AXEL VIA TOR" >> "$ARQUIVO_DEBUG"
                    if command -v axel >/dev/null 2>&1; then
                        echo "[$(date '+%Y-%m-%d %H:%M:%S')] COMANDO: torsocks axel -k --insecure \"$conteudo_atual\"" >> "$ARQUIVO_DEBUG"
                        if command -v torsocks >/dev/null 2>&1; then
                            torsocks axel -k --insecure "$conteudo_atual"
                        else
                            axel -k --insecure "$conteudo_atual"
                        fi
                        status_dl=$?
                    else
                        echo "[$(date '+%Y-%m-%d %H:%M:%S')] axel não instalado; pulando para wget" >> "$ARQUIVO_DEBUG"
                    fi
                fi
                if [ $status_dl -ne 0 ]; then
                    # === TENTATIVA 3: wget via Tor ===
                    echo "[$(date '+%Y-%m-%d %H:%M:%S')] FALHA AXEL (status: $status_dl), TENTANDO WGET VIA TOR..." >> "$ARQUIVO_DEBUG"
                    echo "[$(date '+%Y-%m-%d %H:%M:%S')] COMANDO: torsocks wget --no-check-certificate -q --content-disposition \"$conteudo_atual\"" >> "$ARQUIVO_DEBUG"
                    torsocks wget --no-check-certificate -q --content-disposition "$conteudo_atual"
                    status_dl=$?
                fi
                if [ $status_dl -ne 0 ]; then
                    # === TENTATIVA 4: curl via Tor ===
                    echo "[$(date '+%Y-%m-%d %H:%M:%S')] FALHA WGET (status: $status_dl), TENTANDO CURL VIA TOR..." >> "$ARQUIVO_DEBUG"
                    echo "[$(date '+%Y-%m-%d %H:%M:%S')] COMANDO: curl --socks5-hostname 127.0.0.1:9050 -OJL -s --show-error \"$conteudo_atual\"" >> "$ARQUIVO_DEBUG"
                    curl --socks5-hostname 127.0.0.1:9050 -OJL -s --show-error "$conteudo_atual"
                    status_dl=$?
                fi
                cd "$DIRETORIO_DOWNLOAD"

                echo "[$(date '+%Y-%m-%d %H:%M:%S')] STATUS DOWNLOAD: $status_dl" >> "$ARQUIVO_CLIP"
                echo "[$(date '+%Y-%m-%d %H:%M:%S')] STATUS DOWNLOAD: $status_dl" >> "$ARQUIVO_DEBUG"

                if [ $status_dl -eq 0 ]; then
                    nome_arquivo=""
                    echo "[$(date '+%Y-%m-%d %H:%M:%S')] PROCURANDO NOVO ARQUIVO..." >> "$ARQUIVO_DEBUG"

                    find "$DIRETORIO_DOWNLOAD" -maxdepth 1 -type f ! -name "*.txt" ! -name "*.lst" ! -name "*.log" -printf "%f\n" > /tmp/snapshot_depois.txt
                    echo "[$(date '+%Y-%m-%d %H:%M:%S')] SNAPSHOT DEPOIS: $(cat /tmp/snapshot_depois.txt | tr '\n' ' ')" >> "$ARQUIVO_DEBUG"

                    while IFS= read -r arquivo; do
                        if [ -n "$arquivo" ] && ! grep -qx "$arquivo" /tmp/snapshot_antes.txt; then
                            nome_arquivo="$arquivo"
                            echo "[$(date '+%Y-%m-%d %H:%M:%S')] NOVO ARQUIVO ENCONTRADO: $nome_arquivo" >> "$ARQUIVO_DEBUG"
                            break
                        fi
                    done < /tmp/snapshot_depois.txt

                    if [ -z "$nome_arquivo" ]; then
                        echo "[$(date '+%Y-%m-%d %H:%M:%S')] NENHUM NOVO ARQUIVO ENCONTRADO, USANDO O MAIS RECENTE" >> "$ARQUIVO_DEBUG"
                        nome_arquivo=$(find "$DIRETORIO_DOWNLOAD" -maxdepth 1 -type f ! -name "*.txt" ! -name "*.lst" ! -name "*.log" -printf "%T@ %f\n" | sort -nr | head -n1 | cut -d' ' -f2-)
                    fi

                    rm -f /tmp/snapshot_depois.txt

                    if [ -z "$nome_arquivo" ]; then
                        echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERRO: NENHUM ARQUIVO IDENTIFICADO" >> "$ARQUIVO_DEBUG"
                        notify-send "Erro" "❌ Não foi possível identificar o arquivo baixado!"
                        exit 1
                    fi

                    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ARQUIVO: $nome_arquivo" >> "$ARQUIVO_CLIP"
                    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ARQUIVO IDENTIFICADO: $nome_arquivo" >> "$ARQUIVO_DEBUG"
                    echo "[$(date "+%Y-%m-%d %H:%M:%S")] | Link: $conteudo_atual | Senha: $senha_digitada | Status: OK (Genérico)" >> "$ARQUIVO_LOG"

                    notify-send "Download Concluído" "✅ Arquivo baixado: $nome_arquivo"
                        # Atualizar status
                        mostrar_status_downloads

                    # Cria diretório, move e descompacta
                    extensao="${nome_arquivo##*.}"
                    extensao_lower=$(echo "$extensao" | tr '[:upper:]' '[:lower:]')
                    nome_base="${nome_arquivo%.*}"
                    DIR_ARQUIVO="$DIRETORIO_DOWNLOAD/$nome_base"

                    echo "[$(date '+%Y-%m-%d %H:%M:%S')] EXTENSAO: $extensao_lower" >> "$ARQUIVO_CLIP"
                    echo "[$(date '+%Y-%m-%d %H:%M:%S')] DIRETORIO: $DIR_ARQUIVO" >> "$ARQUIVO_CLIP"
                    echo "[$(date '+%Y-%m-%d %H:%M:%S')] EXTENSAO: $extensao_lower, DIRETORIO: $DIR_ARQUIVO" >> "$ARQUIVO_DEBUG"

                    if [ -d "$DIR_ARQUIVO" ]; then
                        contador_dir=2
                        while [ -d "$DIRETORIO_DOWNLOAD/${nome_base}_${contador_dir}" ]; do
                            contador_dir=$((contador_dir + 1))
                        done
                        nome_base="${nome_base}_${contador_dir}"
                        DIR_ARQUIVO="$DIRETORIO_DOWNLOAD/$nome_base"
                    fi
                    mkdir -p "$DIR_ARQUIVO"
                    echo "[$(date '+%Y-%m-%d %H:%M:%S')] DIRETÓRIO CRIADO: $DIR_ARQUIVO" >> "$ARQUIVO_DEBUG"

                    echo "[$(date '+%Y-%m-%d %H:%M:%S')] MOVENDO: $DIRETORIO_DOWNLOAD/$nome_arquivo -> $DIR_ARQUIVO/" >> "$ARQUIVO_DEBUG"
                    mv "$DIRETORIO_DOWNLOAD/$nome_arquivo" "$DIR_ARQUIVO/"

                    case "$extensao_lower" in
                        rar)
                            echo "[$(date '+%Y-%m-%d %H:%M:%S')] ======== INICIANDO DESCOMPACTAÇÃO RAR ========" >> "$ARQUIVO_DEBUG"
                            cd "$DIR_ARQUIVO"
                            echo "[$(date '+%Y-%m-%d %H:%M:%S')] NOVO DIR: $(pwd)" >> "$ARQUIVO_DEBUG"
                            echo "[$(date '+%Y-%m-%d %H:%M:%S')] ARQUIVO: $nome_arquivo" >> "$ARQUIVO_DEBUG"
                            echo "[$(date '+%Y-%m-%d %H:%M:%S')] SENHA: '$senha_digitada'" >> "$ARQUIVO_DEBUG"

                            if [ "$senha_digitada" != "N/A" ]; then
                                cmd_unpack="rar x \"$nome_arquivo\" -p${SQ}${senha_digitada}${SQ}"
                                echo "#!/bin/bash" > "$DIR_ARQUIVO/u.sh"
                                echo "$cmd_unpack" >> "$DIR_ARQUIVO/u.sh"
                                chmod +x "$DIR_ARQUIVO/u.sh"
                                echo "[$(date '+%Y-%m-%d %H:%M:%S')] ARQUIVO CRIADO: $DIR_ARQUIVO/u.sh" >> "$ARQUIVO_DEBUG"
                            else
                                cmd_unpack="rar x \"$nome_arquivo\""
                                echo "#!/bin/bash" > "$DIR_ARQUIVO/u.sh"
                                echo "$cmd_unpack" >> "$DIR_ARQUIVO/u.sh"
                                chmod +x "$DIR_ARQUIVO/u.sh"
                                echo "[$(date '+%Y-%m-%d %H:%M:%S')] ARQUIVO CRIADO: $DIR_ARQUIVO/u.sh" >> "$ARQUIVO_DEBUG"
                            fi

                            echo "[$(date '+%Y-%m-%d %H:%M:%S')] COMANDO: $cmd_unpack" >> "$ARQUIVO_DEBUG"
                            rar x "$nome_arquivo" -p"$senha_digitada" 2>&1 | tee -a "$ARQUIVO_DEBUG"
                            status_unpack=$?

                            echo "[$(date '+%Y-%m-%d %H:%M:%S')] STATUS UNPACK: $status_unpack" >> "$ARQUIVO_DEBUG"
                            cd "$DIRETORIO_DOWNLOAD"
                            echo "[$(date '+%Y-%m-%d %H:%M:%S')] CMD: cd \"$DIR_ARQUIVO\" && $cmd_unpack" >> "$ARQUIVO_UNPACK"
                            if [ $status_unpack -eq 0 ]; then
                                notify-send "Sucesso" "✅ RAR descompactado: $nome_arquivo em: $DIR_ARQUIVO"
                            else
                                notify-send "Erro" "❌ Falha ao descompactar RAR: $nome_arquivo! Verifique a senha."
                            fi
                            ;;
                        zip|7z)
                            echo "[$(date '+%Y-%m-%d %H:%M:%S')] ======== INICIANDO DESCOMPACTAÇÃO 7Z/ZIP ========" >> "$ARQUIVO_DEBUG"
                            cd "$DIR_ARQUIVO"
                            echo "[$(date '+%Y-%m-%d %H:%M:%S')] NOVO DIR: $(pwd)" >> "$ARQUIVO_DEBUG"
                            echo "[$(date '+%Y-%m-%d %H:%M:%S')] ARQUIVO: $nome_arquivo" >> "$ARQUIVO_DEBUG"
                            echo "[$(date '+%Y-%m-%d %H:%M:%S')] SENHA: '$senha_digitada'" >> "$ARQUIVO_DEBUG"

                            if [ "$senha_digitada" != "N/A" ]; then
                                cmd_unpack="7z x \"$nome_arquivo\" -p${SQ}${senha_digitada}${SQ}"
                                echo "#!/bin/bash" > "$DIR_ARQUIVO/u.sh"
                                echo "$cmd_unpack" >> "$DIR_ARQUIVO/u.sh"
                                chmod +x "$DIR_ARQUIVO/u.sh"
                                echo "[$(date '+%Y-%m-%d %H:%M:%S')] ARQUIVO CRIADO: $DIR_ARQUIVO/u.sh" >> "$ARQUIVO_DEBUG"
                            else
                                cmd_unpack="7z x \"$nome_arquivo\""
                                echo "#!/bin/bash" > "$DIR_ARQUIVO/u.sh"
                                echo "$cmd_unpack" >> "$DIR_ARQUIVO/u.sh"
                                chmod +x "$DIR_ARQUIVO/u.sh"
                                echo "[$(date '+%Y-%m-%d %H:%M:%S')] ARQUIVO CRIADO: $DIR_ARQUIVO/u.sh" >> "$ARQUIVO_DEBUG"
                            fi

                            echo "[$(date '+%Y-%m-%d %H:%M:%S')] COMANDO: $cmd_unpack" >> "$ARQUIVO_DEBUG"
                            7z x "$nome_arquivo" -p"$senha_digitada" 2>&1 | tee -a "$ARQUIVO_DEBUG"
                            status_unpack=$?

                            echo "[$(date '+%Y-%m-%d %H:%M:%S')] STATUS UNPACK: $status_unpack" >> "$ARQUIVO_DEBUG"
                            cd "$DIRETORIO_DOWNLOAD"
                            echo "[$(date '+%Y-%m-%d %H:%M:%S')] CMD: cd \"$DIR_ARQUIVO\" && $cmd_unpack" >> "$ARQUIVO_UNPACK"
                            if [ $status_unpack -eq 0 ]; then
                                notify-send "Sucesso" "✅ ZIP/7Z descompactado: $nome_arquivo em: $DIR_ARQUIVO"
                            else
                                notify-send "Erro" "❌ Falha ao descompactar ZIP/7Z: $nome_arquivo! Verifique a senha."
                            fi
                            ;;
                        *)
                            echo "[$(date '+%Y-%m-%d %H:%M:%S')] ARQUIVO NÃO COMPACTADO (${extensao_lower}) - APENAS MOVIDO" >> "$ARQUIVO_CLIP"
                            notify-send "Sucesso" "📁 Arquivo movido: $nome_arquivo para: $DIR_ARQUIVO"
                            ;;
                    esac
                else
                    echo "[$(date '+%Y-%m-%d %H:%M:%S')] DOWNLOAD FALHOU" >> "$ARQUIVO_CLIP"
                    echo "[$(date "+%Y-%m-%d %H:%M:%S")] | Link: $conteudo_atual | Senha: $senha_digitada | Status: FAIL (Genérico)" >> "$ARQUIVO_LOG"
                    notify-send "Erro" "❌ Falha no download: $nome_arquivo_url"
                fi

                rm -f /tmp/snapshot_antes.txt
                echo "[$(date '+%Y-%m-%d %H:%M:%S')] FIM PROCESSO GENÉRICO" >> "$ARQUIVO_CLIP"
                echo "[$(date '+%Y-%m-%d %H:%M:%S')] ======== FIM DOWNLOAD GENÉRICO ========" >> "$ARQUIVO_DEBUG"
            ) &
        fi
    fi
    sleep 0.4
done
