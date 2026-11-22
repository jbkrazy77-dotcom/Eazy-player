# Eazy 5.2.0 — revisão 13

- Mantida a sincronização incremental ao entrar na pasta.
- Seleção normal usa a coluna `selected` do SQLite.
- O caminho SQL não materializa `selected_paths`, `.dirs`, `.local` ou `.bytes`.
- Seleção de diretório atualiza os caminhos já indexados no SQLite, sem `find` recursivo.
- `Ctrl+R` e `Ctrl+A` continuam operando sobre a lista exibida e o estado SQLite.
