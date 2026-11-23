# Referências técnicas — demonstração Windows/WSL

Fontes oficiais consultadas durante o desenho do bundle:

- Microsoft Learn, **Working across file systems**: https://learn.microsoft.com/en-us/windows/wsl/filesystems — orientações de desempenho e uso dos sistemas de arquivos Linux e Windows no WSL. O launcher copia a aplicação uma vez para o filesystem Linux da distribuição em vez de executar repetidamente o programa a partir de `/mnt/c`.
- Microsoft Learn, **Naming a File**: https://learn.microsoft.com/en-us/windows/win32/fileio/naming-a-file — regras e caracteres especiais em nomes de arquivos e caminhos Win32. O protótipo nativo usa APIs de diretório Python e não assume que caminhos Windows são caminhos POSIX.
- Microsoft Learn, **Maximum Path Length Limitation**: https://learn.microsoft.com/en-us/windows/win32/fileio/maximum-file-path-limitation — condições para caminhos longos no Windows. O protótipo deve ser validado em Windows real com nomes extensos e políticas de caminho longo habilitadas/desabilitadas.
- Microsoft Learn, **Virtual Terminal Sequences**: https://learn.microsoft.com/en-us/windows/console/console-virtual-terminal-sequences — sequências de controle suportadas por terminais Windows; relevante para qualquer evolução futura da interface nativa.
- Microsoft Learn, **Pseudoconsoles (ConPTY)**: https://learn.microsoft.com/en-us/windows/console/pseudoconsoles — interface de pseudoconsoles Windows para aplicações de terminal; opção para estudar se o Easy vier a ser portado além da execução em WSL.

Essas referências orientam decisões de compatibilidade; não significam que a prova de conceito já implemente um porte nativo completo. O fluxo completo entregue nesta amostra executa o Easy Linux dentro do WSL2.
