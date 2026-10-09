# HelpDesk TI - Sistema de Chamados de Suporte Tecnico

Sistema de simulacao de atendimento de chamados de suporte tecnico de informatica, desenvolvido em Java (API REST) com interface web moderna.

## Como Executar

### 1. Compilar o Backend
```
cd backend
compilar.bat
```

### 2. Iniciar o Backend
```
cd backend
executar.bat
```
A API estara disponivel em `http://localhost:8080`

### 3. Abrir o Frontend
1. Abra a pasta `frontend` no VS Code
2. Clique com botao direito em `index.html`
3. Selecione **"Open with Live Server"**

> **Importante:** O backend (passo 2) deve estar rodando antes de abrir o frontend.

## Estruturas de Dados

| Estrutura | Classe Java | Uso no Sistema |
|---|---|---|
| Fila (Queue) | `Fila.java` | Chamados aguardando atendimento (FIFO) |
| Pilha (Stack) | `Pilha.java` | Historico de operacoes (LIFO) |
| Lista Ligada | `ListaLigada.java` | Usuarios, equipamentos e chamados |
| Arvore Binaria | `ArvoreBinaria.java` | Busca de chamados por ID |

Para explicacao detalhada, veja `EXPLICACAO_PROJETO.md`.
