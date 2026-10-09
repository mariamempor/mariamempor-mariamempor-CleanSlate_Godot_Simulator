# Sistema de Help Desk TI - Documentacao Completa do Projeto

## Indice

1. [Visao Geral](#visao-geral)
2. [Arquitetura do Sistema](#arquitetura-do-sistema)
3. [Estruturas de Dados ](#estruturas-de-dados)
   - 3.1 [Fila Circular (Queue)](#31-fila-circular-queue---fifo)
   - 3.2 [Pilha (Stack)](#32-pilha-stack---lifo)
   - 3.3 [Lista Ligada (Linked List)](#33-lista-ligada-linked-list)
   - 3.4 [Arvore Binaria de Busca (BST)](#34-arvore-binaria-de-busca-bst)
4. [Algoritmos Implementados - Comparacao com o Codigo do Professor](#algoritmos-implementados)
   - 4.1 [Selection Sort](#41-selection-sort)
   - 4.2 [Busca Binaria](#42-busca-binaria)
5. [Diferenciais do Projeto](#diferenciais-do-projeto)
   - 5.1 [Sistema de SLA](#51-sistema-de-sla-service-level-agreement)
   - 5.2 [Desfazer (Undo) com Pilha](#52-desfazer-undo-com-pilha)
   - 5.3 [Travessias Completas da Arvore](#53-travessias-completas-da-arvore-binaria)
6. [Classes de Modelo (Dados)](#classes-de-modelo)
7. [API REST - Como Funciona o Backend](#api-rest)
8. [Frontend - Como Funciona a Interface](#frontend)
9. [Fluxo Completo de Operacoes](#fluxo-completo)
10. [Como Executar o Projeto](#como-executar)
11. [Endpoints da API](#endpoints-da-api)
12. [Tecnologias Utilizadas](#tecnologias-utilizadas)

---

## Visao Geral

Este projeto e um **sistema de simulacao de atendimento de chamados de suporte tecnico de TI (Help Desk)**, desenvolvido em **Java** (backend REST API) com **interface web** (HTML/CSS/JavaScript).

O sistema permite:
- Registrar chamados de suporte tecnico com prioridade e SLA
- Organizar a fila de atendimento (FIFO)
- Registrar historico de todas as operacoes (LIFO)
- Buscar chamados de forma eficiente usando arvore binaria
- Ordenar chamados usando Selection Sort
- Localizar chamados por prioridade usando Busca Binaria
- Desfazer a ultima operacao realizada (Undo)
- Monitorar SLA (tempo maximo de atendimento) por prioridade


---

## Arquitetura do Sistema

```
Estrutura_de_dados_analise_de_algoritmos/
├── backend/                                # API REST em Java
│   ├── src/
│   │   ├── estruturas/                     # Estruturas de dados implementadas do zero
│   │   │   ├── Fila.java                   # Fila Circular com array (FIFO)
│   │   │   ├── Pilha.java                  # Pilha com array (LIFO)
│   │   │   ├── ListaLigada.java            # Lista Ligada com nos encadeados
│   │   │   └── ArvoreBinaria.java          # Arvore Binaria de Busca (BST)
│   │   ├── modelo/                         # Classes de modelo (dados)
│   │   │   ├── Chamado.java                # Chamado tecnico (com SLA)
│   │   │   ├── Usuario.java                # Usuario do sistema
│   │   │   ├── Equipamento.java            # Equipamento de informatica
│   │   │   └── RegistroHistorico.java      # Registro de operacao (historico/undo)
│   │   ├── api/
│   │   │   └── HelpDeskAPI.java            # Servidor HTTP + todos os endpoints REST
│   │   └── util/
│   │       └── JsonParser.java             # Parser JSON simples (sem dependencias)
│   ├── compilar.bat                        # Script para compilar todos os .java
│   └── executar.bat                        # Script para rodar o servidor
├── frontend/                               # Interface Web (SPA)
│   ├── index.html                          # Pagina unica com todas as telas
│   ├── css/
│   │   └── style.css                       # Estilos visuais (responsivo)
│   └── js/
│       └── app.js                          # Logica JavaScript (chamadas a API)
└── DOCUMENTACAO_PROJETO.md                 # Este arquivo
```

**Como o sistema se comunica:**
```
┌──────────────┐      HTTP (JSON)      ┌──────────────────┐
│   Frontend   │ ◄──────────────────► │    Backend Java   │
│  (Navegador) │   GET/POST/DELETE     │  (porta 8080)    │
│  HTML/JS/CSS │                       │  HelpDeskAPI.java │
└──────────────┘                       └──────────────────┘
                                              │
                                       Usa internamente:
                                       ├── Fila<Chamado>
                                       ├── Pilha<RegistroHistorico> (x2)
                                       ├── ListaLigada<Usuario/Equipamento/Chamado>
                                       └── ArvoreBinaria<Chamado>
```

O frontend envia requisicoes HTTP para o backend. O backend processa usando as estruturas de dados e retorna JSON. Nao ha banco de dados — tudo fica em memoria usando as estruturas implementadas.

---

## Estruturas de Dados

### 3.1 Fila Circular (Queue) - FIFO

**Arquivo:** `backend/src/estruturas/Fila.java`

**Uso no sistema:** Organizar os chamados que estao **aguardando atendimento**. Quando um chamado e criado, ele entra no final da fila. O primeiro a entrar e o primeiro a ser atendido (FIFO - First In, First Out).

#### Como funciona internamente

A fila usa um **array circular** com tres variaveis de controle:
- `v[]` — vetor (array) que armazena os elementos
- `i` — indice do inicio da fila (de onde sai o elemento)
- `f` — indice do fim da fila (onde entra o proximo elemento)
- `tam` — quantos elementos existem na fila

Quando `f` ou `i` chegam ao fim do vetor, eles "voltam" para a posicao 0 (comportamento circular). Isso evita desperdicar espaco no array.

#### Codigo do projeto vs codigo do professor

**Codigo do professor (FilaC - Fila Circular):**
```java
// Professor usou Fila Circular com array, ponteiros i e f, e variavel tam
public class FilaC {
    int[] v;
    int i, f, tam, N;

    FilaC(int N) {
        this.N = N;
        v = new int[N];
        i = 0; f = -1; tam = 0;
    }

    void enfileira(int x) {
        f++;
        if (f >= N) f = 0;  // Circular
        v[f] = x;
        tam++;
    }

    int desenfileira() {
        int x = v[i];
        tam--;
        i++;
        if (i >= N) i = 0;  // Circular
        return x;
    }
}
```

**Codigo do projeto (Fila.java):**
```java
// Mesmo conceito do professor, mas com Generics <T> para aceitar qualquer tipo
public class Fila<T> {
    private Object[] v;      // vetor que armazena os elementos (igual v[] do professor)
    private int i;            // inicio da fila (igual i do professor)
    private int f;            // fim da fila (igual f do professor)
    private int tam;          // numero de elementos (igual tam do professor)
    private int capacidade;   // tamanho do vetor (igual N do professor)

    public Fila() {
        this.capacidade = 100;
        this.v = new Object[capacidade];
        this.i = 0;
        this.f = -1;  // Fila Vazia (igual ao professor: f = -1)
        this.tam = 0;
    }

    public void enfileirar(T dado) {
        if (tam == capacidade) {
            aumentarCapacidade();  // Diferencial: expande automaticamente
        }
        f++;                       // Identico ao professor
        if (f >= capacidade) {
            f = 0;                 // Circular (identico ao professor)
        }
        v[f] = dado;
        tam++;
    }

    public T desenfileirar() {
        if (tam == 0) return null;
        T saiu = (T) v[i];        // Pega valor do inicio (identico ao professor)
        v[i] = null;
        tam--;
        i++;
        if (i >= capacidade) {
            i = 0;                 // Circular (identico ao professor)
        }
        return saiu;
    }
}
```

**O que e igual ao professor:**
- Usa array (`v[]`) para armazenar dados (nao usa nos/ponteiros)
- Usa variaveis `i` (inicio), `f` (fim), `tam` (tamanho)
- `f` comeca em -1 (fila vazia)
- Logica circular: `if (f >= N) f = 0` e `if (i >= N) i = 0`
- Mesma logica de enfileirar (incrementa `f`, coloca no vetor) e desenfileirar (pega de `i`, incrementa `i`)

**O que foi adicionado no projeto:**
- `Generics <T>` para aceitar qualquer tipo de dado (nao apenas int)
- Metodo `aumentarCapacidade()` que dobra o vetor quando fica cheio
- Metodos auxiliares: `espiar()`, `estaVazia()`, `paraArray()`

#### Onde e usado no sistema (HelpDeskAPI.java)

```java
// Declaracao (linha 31):
private static final Fila<Chamado> filaChamados = new Fila<>();

// Ao criar chamado - enfileira na fila de espera (linha 697):
filaChamados.enfileirar(c);

// Ao atender chamado - desenfileira o proximo (linha 728):
Chamado c = filaChamados.desenfileirar();

// Para ver quem e o proximo sem remover (linha 716):
Chamado proximo = filaChamados.espiar();

// Para listar toda a fila (linha 329):
Chamado[] chamados = filaChamados.paraArray(new Chamado[tam]);
```

**Tela na interface:** Menu "Fila de Atendimento" — mostra os chamados na ordem de chegada, com botao "Atender" apenas no primeiro.

---

### 3.2 Pilha (Stack) - LIFO

**Arquivo:** `backend/src/estruturas/Pilha.java`

**Uso no sistema:** Duas pilhas sao usadas no projeto:
1. `pilhaHistorico` — Registra todas as operacoes (criacao, atendimento, finalizacao, undo). A operacao mais recente fica no topo.
2. `pilhaUndo` — Armazena as acoes que podem ser desfeitas. Quando o usuario clica "Desfazer", a acao do topo e removida e revertida.

#### Como funciona internamente

A pilha usa um **array com variavel topo**:
- `v[]` — vetor que armazena os elementos
- `topo` — indice do elemento no topo da pilha (-1 significa pilha vazia)

Ao empilhar, `topo` incrementa e o dado e colocado em `v[topo]`. Ao desempilhar, o dado e retirado de `v[topo]` e `topo` decrementa.

#### Codigo do projeto vs codigo do professor

**Codigo do professor (Pilha com array):**
```java
// Professor usou Pilha com array v[] e variavel topo
public class Pilha {
    int[] v;
    int topo, N;

    Pilha(int N) {
        this.N = N;
        v = new int[N];
        topo = -1;  // Pilha Vazia
    }

    void push(int x) {
        topo++;
        v[topo] = x;
    }

    int pop() {
        int x = v[topo];
        topo--;
        return x;
    }
}
```

**Codigo do projeto (Pilha.java):**
```java
public class Pilha<T> {
    private Object[] v;      // vetor (igual v[] do professor)
    private int topo;         // topo da pilha (igual topo do professor)
    private int capacidade;   // tamanho maximo (igual N do professor)

    public Pilha() {
        this.capacidade = 100;
        this.v = new Object[capacidade];
        this.topo = -1;  // Pilha Vazia (identico ao professor)
    }

    public void empilhar(T dado) {
        topo++;                          // Identico ao professor: topo++
        if (topo == capacidade) {
            aumentarCapacidade();        // Diferencial: expande automaticamente
        }
        v[topo] = dado;                  // Identico ao professor: v[topo] = x
    }

    public T desempilhar() {
        if (topo == -1) return null;     // Pilha Vazia
        T x = (T) v[topo];              // Identico ao professor: x = v[topo]
        v[topo] = null;
        topo--;                          // Identico ao professor: topo--
        return x;
    }
}
```

**O que e igual ao professor:**
- Usa array (`v[]`) para armazenar dados
- Usa variavel `topo` que comeca em -1 (pilha vazia)
- `push`/`empilhar`: incrementa topo, coloca dado em `v[topo]`
- `pop`/`desempilhar`: pega dado de `v[topo]`, decrementa topo
- Mesma logica estrutural exata

**O que foi adicionado no projeto:**
- `Generics <T>` para aceitar qualquer tipo
- `aumentarCapacidade()` que dobra o vetor quando cheio
- Metodos auxiliares: `espiar()`, `estaVazia()`, `paraArray()` (que percorre do topo para a base)

#### Onde e usado no sistema (HelpDeskAPI.java)

```java
// Duas pilhas declaradas (linhas 34-37):
private static final Pilha<RegistroHistorico> pilhaHistorico = new Pilha<>();  // historico geral
private static final Pilha<RegistroHistorico> pilhaUndo = new Pilha<>();       // acoes desfaziveis

// Ao criar chamado - empilha nas duas pilhas (linhas 705-708):
pilhaHistorico.empilhar(registro);
pilhaUndo.empilhar(registro);

// Ao atender chamado (linhas 737-738):
pilhaHistorico.empilhar(registro);
pilhaUndo.empilhar(registro);

// Ao finalizar chamado (linhas 770-771):
pilhaHistorico.empilhar(registro);
pilhaUndo.empilhar(registro);

// Para desfazer (handleDesfazer, linha 496):
RegistroHistorico acao = pilhaUndo.desempilhar();  // Remove do topo da pilha de undo

// Para listar historico (linha 351):
RegistroHistorico[] registros = pilhaHistorico.paraArray(new RegistroHistorico[tam]);
```

**Tela na interface:**
- Menu "Historico" — mostra todas as operacoes (mais recente primeiro, LIFO natural)
- Botao "Desfazer" no topo da pagina — desempilha da pilhaUndo e reverte a acao

---

### 3.3 Lista Ligada (Linked List)

**Arquivo:** `backend/src/estruturas/ListaLigada.java`

**Uso no sistema:** Armazenar **usuarios**, **equipamentos** e **todos os chamados** de forma dinamica. Permite insercao e remocao sem limite fixo de tamanho.

#### Como funciona internamente

A lista usa **nos encadeados**:
- Cada `No` contem um `dado` e um ponteiro `prox` para o proximo no
- A variavel `ini` aponta para o primeiro no (cabeca da lista)
- Para percorrer, usa-se uma variavel `t` que caminha de no em no: `t = t.prox`

#### Codigo do projeto vs codigo do professor

**Codigo do professor (Lista Ligada):**
```java
// Professor usou Lista Ligada com nos, ini como cabeca, e t como variavel de percurso
class No {
    int dado;
    No prox;
}

class Lista {
    No ini;  // aponta para o primeiro No

    void insere(int x) {
        No novo = new No();
        novo.dado = x;
        novo.prox = null;

        if (ini == null) {
            ini = novo;
        } else {
            No t = ini;
            while (t.prox != null) {
                t = t.prox;  // anda na lista
            }
            t.prox = novo;  // conecta no final
        }
    }
}
```

**Codigo do projeto (ListaLigada.java):**
```java
public class ListaLigada<T> {

    private static class No<T> {
        T dado;
        No<T> prox;        // aponta para o proximo No (igual ao professor)

        No(T dado) {
            this.dado = dado;
            this.prox = null;  // "Aterra o No" (igual ao professor)
        }
    }

    private No<T> ini;      // cabeca da lista (igual ini do professor)
    private int tamanho;

    public void adicionar(T dado) {
        No<T> novoNo = new No<>(dado);
        if (ini == null) {
            ini = novoNo;                   // Lista vazia, insere na cabeca
        } else {
            No<T> t = ini;                  // t aponta para a cabeca (igual ao professor)
            while (t.prox != null) {
                t = t.prox;                 // anda na lista (igual ao professor)
            }
            t.prox = novoNo;               // conecta no final (igual ao professor)
        }
        tamanho++;
    }
}
```

**O que e igual ao professor:**
- Usa nos encadeados com `dado` e `prox`
- Variavel `ini` como cabeca da lista (em vez de `head` ou `cabeca`)
- Variavel `t` para percorrer a lista (padrao do professor)
- Insercao percorrendo ate o final com `while (t.prox != null)` e conectando `t.prox = novo`
- Comentario "aterra o No" (prox = null) identico ao estilo do professor

**O que foi adicionado no projeto:**
- `Generics <T>` e No como classe interna (`No<T>`)
- Metodos de remocao: `remover(T dado)` e `removerPorIndice(int indice)`
- Metodo `obter(int indice)` para acessar por posicao
- Interface `Filtro<T>` para busca e filtragem flexivel
- Metodos `buscar(Filtro)` e `filtrar(Filtro)` que percorrem a lista com `t = t.prox`

#### Onde e usado no sistema (HelpDeskAPI.java)

```java
// Tres listas ligadas declaradas (linhas 40-42):
private static final ListaLigada<Usuario> listaUsuarios = new ListaLigada<>();
private static final ListaLigada<Equipamento> listaEquipamentos = new ListaLigada<>();
private static final ListaLigada<Chamado> listaChamados = new ListaLigada<>();

// Adicionar usuario (linha 674):
listaUsuarios.adicionar(u);

// Busca de usuario por ID usando filtro (linha 125):
Usuario u = listaUsuarios.buscar(usr -> usr.getId() == id);

// Busca de chamados por termo (linhas 445-450):
ListaLigada<Chamado> resultados = listaChamados.filtrar(c ->
    c.getTitulo().toLowerCase().contains(termo) ||
    c.getDescricao().toLowerCase().contains(termo) ||
    c.getNomeUsuario().toLowerCase().contains(termo) ||
    c.getSetor().toLowerCase().contains(termo)
);

// Copiar para array para ordenacao (linha 589):
Chamado[] vetor = listaChamados.paraArray(new Chamado[total]);
```

**Tela na interface:** Menus "Usuarios", "Equipamentos" e "Chamados"

---

### 3.4 Arvore Binaria de Busca (BST)

**Arquivo:** `backend/src/estruturas/ArvoreBinaria.java`

**Uso no sistema:** Organizar e **buscar chamados por ID** de forma eficiente com complexidade O(log n) no caso medio. Tambem permite listar os chamados em 3 ordens diferentes (emOrdem, preOrdem, posOrdem).

#### Como funciona internamente

A arvore e composta por nos, cada um com:
- `dado` — o valor armazenado
- `esquerda` — filho com valor menor
- `direita` — filho com valor maior
- `raiz` — o no que fica no topo da arvore

A **insercao e busca usam lacos `while`** (iterativo), e as **travessias usam recursao**.

#### Codigo do projeto vs codigo do professor

**Codigo do professor (ArvoreBinaria - insercao iterativa com while):**
```java
// Professor usou insercao com while, percorrendo a arvore iterativamente
class ABB {
    No raiz;

    void inserir(int x) {
        No novo = new No(x);
        if (raiz == null) {
            raiz = novo;
            return;
        }
        No t = raiz;
        while (true) {
            if (x < t.dado) {
                if (t.esq == null) {
                    t.esq = novo;
                    return;
                }
                t = t.esq;
            } else {
                if (t.dir == null) {
                    t.dir = novo;
                    return;
                }
                t = t.dir;
            }
        }
    }
}
```

**Codigo do professor (Travessias recursivas):**
```java
// Professor usou recursao para as travessias
void emOrdem(No t) {
    if (t == null) return;
    emOrdem(t.esq);
    System.out.println(t.dado);
    emOrdem(t.dir);
}

void preOrdem(No t) {
    if (t == null) return;
    System.out.println(t.dado);
    preOrdem(t.esq);
    preOrdem(t.dir);
}
```

**Codigo do projeto (ArvoreBinaria.java):**
```java
public class ArvoreBinaria<T extends Comparable<T>> {

    private static class No<T> {
        T dado;
        No<T> esquerda;  // filho esquerdo (menor)
        No<T> direita;   // filho direito (maior)
    }

    private No<T> raiz;

    // INSERCAO ITERATIVA com while (identico ao estilo do professor)
    public void inserir(T dado) {
        if (raiz == null) {
            raiz = new No<>(dado);
            tamanho++;
            return;
        }
        No<T> t = raiz;  // t percorre a arvore (igual ao professor)
        while (true) {
            int cmp = dado.compareTo(t.dado);
            if (cmp == 0) {
                t.dado = dado;     // Valor ja existe, atualiza
                return;
            }
            if (cmp < 0) {         // Menor, vai para esquerda
                if (t.esquerda == null) {
                    t.esquerda = new No<>(dado);
                    tamanho++;
                    return;
                }
                t = t.esquerda;    // t pula para o No esquerdo
            } else {               // Maior, vai para direita
                if (t.direita == null) {
                    t.direita = new No<>(dado);
                    tamanho++;
                    return;
                }
                t = t.direita;     // t pula para o No direito
            }
        }
    }

    // BUSCA ITERATIVA com while (identico ao estilo do professor)
    public T buscar(T chave) {
        No<T> t = raiz;
        while (t != null) {
            int cmp = chave.compareTo(t.dado);
            if (cmp == 0) return t.dado;     // Achou
            if (cmp < 0) t = t.esquerda;     // anda para a esquerda
            else t = t.direita;               // anda para a direita
        }
        return null;  // Nao achou
    }

    // TRAVESSIA EM ORDEM - recursiva (identica ao professor)
    private void emOrdem(No<T> t, Visitante<T> visitante) {
        if (t == null) return;
        emOrdem(t.esquerda, visitante);     // esquerda primeiro
        visitante.visitar(t.dado);           // visita o No
        emOrdem(t.direita, visitante);       // depois direita
    }

    // TRAVESSIA PRE-ORDEM - recursiva (identica ao professor)
    private void preOrdem(No<T> t, Visitante<T> visitante) {
        if (t == null) return;
        visitante.visitar(t.dado);           // visita o No primeiro
        preOrdem(t.esquerda, visitante);     // depois esquerda
        preOrdem(t.direita, visitante);      // depois direita
    }

    // TRAVESSIA POS-ORDEM - recursiva (adicional)
    private void posOrdem(No<T> t, Visitante<T> visitante) {
        if (t == null) return;
        posOrdem(t.esquerda, visitante);     // esquerda primeiro
        posOrdem(t.direita, visitante);      // depois direita
        visitante.visitar(t.dado);           // visita o No por ultimo
    }
}
```

**O que e igual ao professor:**
- Insercao **iterativa com `while (true)`**, percorrendo a arvore com variavel `t`
- Busca **iterativa com `while (t != null)`**
- Travessias **recursivas** (emOrdem, preOrdem) com a mesma logica exata do professor
- Usa variavel `t` para percorrer (padrao do professor)
- Estrutura de No com `esquerda`/`direita` (equivalente a `esq`/`dir` do professor)

**O que foi adicionado no projeto:**
- `Generics <T extends Comparable<T>>` para aceitar qualquer tipo comparavel
- Interface `Visitante<T>` para as travessias (padrao Visitor)
- Travessia `posOrdem` (pos-ordem) adicional
- Metodo `getAltura()` para calcular a altura da arvore (usado no dashboard)
- Metodo `remover()` com logica de substituicao pelo sucessor

#### Onde e usado no sistema (HelpDeskAPI.java)

```java
// Declaracao (linha 45):
private static final ArvoreBinaria<Chamado> arvoreChamados = new ArvoreBinaria<>();

// Ao criar chamado - insere na arvore (linha 694):
arvoreChamados.inserir(c);

// Busca por ID - cria chave e busca (linhas 264-266):
Chamado chave = new Chamado();
chave.setId(id);
Chamado c = arvoreChamados.buscar(chave);

// Travessia em ordem (linha 469):
arvoreChamados.emOrdem(c -> ordenados.adicionar(c.toJson()));

// Travessia pre-ordem (linha 465):
arvoreChamados.preOrdem(c -> ordenados.adicionar(c.toJson()));

// Travessia pos-ordem (linha 467):
arvoreChamados.posOrdem(c -> ordenados.adicionar(c.toJson()));

// Altura da arvore para estatisticas (linha 377):
int alturaArvore = arvoreChamados.getAltura();
```

**Como a busca na arvore funciona (passo a passo):**
1. O usuario digita um ID (ex: 5) na tela de Busca
2. O frontend chama `GET /api/busca?id=5`
3. O backend cria um `Chamado` temporario com `id = 5` (so para comparacao)
4. Chama `arvoreChamados.buscar(chave)` que percorre a arvore:
   - Comeca na raiz. Se 5 < raiz, vai para esquerda. Se 5 > raiz, vai para direita.
   - Repete ate encontrar ou chegar em null
5. Retorna o chamado encontrado (ou null se nao existe)

**Tela na interface:** Menu "Busca (Arvore)" com busca por ID, busca por termo, e seletor de travessia (emOrdem, preOrdem, posOrdem)

---

## Algoritmos Implementados

### 4.1 Selection Sort

**Onde esta:** `HelpDeskAPI.java`, metodo `handleOrdenar()` (linhas 591-606)

**Uso no sistema:** Ordenar o vetor de chamados por criterio (prioridade, ID, status ou setor). O usuario escolhe o criterio na tela "Ordenacao" e o sistema ordena usando Selection Sort.

#### Codigo do projeto vs codigo do professor

**Codigo do professor (Selection Sort):**
```java
// Professor ensinou Selection Sort com laco externo (fim) e interno (busca o maior)
int[] v = {5, 3, 8, 1, 2};
int aux, pos;
for (int fim = v.length - 1; fim >= 1; fim--) {  // laco externo
    pos = 0;  // Chute
    for (int i = 0; i <= fim; i++) {               // laco interno
        if (v[i] > v[pos]) {
            pos = i;  // pos recebe o valor de i
        }
    }  // laco interno
    // Colocar o maior ao final
    aux = v[pos];
    v[pos] = v[fim];
    v[fim] = aux;
}  // laco externo
```

**Codigo do projeto (handleOrdenar):**
```java
// Copia chamados para array
Chamado[] vetor = listaChamados.paraArray(new Chamado[total]);

// Selection Sort (identico ao professor)
Chamado aux;
int pos;
for (int fim = total - 1; fim >= 1; fim--) {    // laco externo (identico)
    pos = 0;  // Chute (identico)
    for (int i = 0; i <= fim; i++) {              // laco interno (identico)
        if (compararChamados(vetor[i], vetor[pos], criterio) > 0) {
            pos = i;  // pos recebe o valor de i (identico)
        }
    }  // laco interno
    // Colocar o maior ao final (identico)
    aux = vetor[pos];
    vetor[pos] = vetor[fim];
    vetor[fim] = aux;
}  // laco externo
```

**O que e identico ao professor:**
- Laco externo de `fim = length-1` ate `fim >= 1`
- Laco interno de `i = 0` ate `i <= fim`
- Variavel `pos` comecando em 0 (chute)
- Troca: `aux = v[pos]; v[pos] = v[fim]; v[fim] = aux;`
- Comentarios no mesmo estilo: "Chute", "pos recebe o valor de i", "Colocar o maior ao final"

**O que foi adaptado:**
- Em vez de `v[i] > v[pos]`, usa `compararChamados(vetor[i], vetor[pos], criterio) > 0` para permitir ordenar por criterios diferentes (prioridade, ID, status, setor)

---

### 4.2 Busca Binaria

**Onde esta:** `HelpDeskAPI.java`, metodo `handleOrdenar()` (linhas 614-637)

**Uso no sistema:** Apos ordenar por prioridade com Selection Sort, o usuario pode buscar um chamado com determinada prioridade usando Busca Binaria no vetor ja ordenado.

#### Codigo do projeto vs codigo do professor

**Codigo do professor (Busca Binaria):**
```java
int ini = 0, fim = v.length - 1, meio;
while (ini <= fim) {
    meio = (ini + fim) / 2;
    if (v[meio] == x) {
        // Achou
        break;
    }
    if (x < v[meio]) {
        fim = meio - 1;
    } else {
        ini = meio + 1;
    }
}
```

**Codigo do projeto (Busca Binaria por prioridade):**
```java
int ini = 0, fimB = total - 1, meio;
int encontrado = -1;
while (ini <= fimB) {
    meio = (ini + fimB) / 2;
    if (vetor[meio].getPrioridade() == buscaPrio) {
        encontrado = meio;
        break;  // Achou
    }
    if (buscaPrio < vetor[meio].getPrioridade()) {
        fimB = meio - 1;
    } else {
        ini = meio + 1;
    }
}
```

**O que e identico ao professor:**
- Variaveis `ini`, `fim` (renomeada para `fimB`), `meio`
- Laco `while (ini <= fim)`
- Calculo `meio = (ini + fim) / 2`
- Logica de divisao: se menor vai para esquerda (`fim = meio - 1`), se maior vai para direita (`ini = meio + 1`)

**Tela na interface:** Menu "Ordenacao" com botao "Ordenar (Selection Sort)" e "Busca Binaria"

---

## Diferenciais do Projeto

### 5.1 Sistema de SLA (Service Level Agreement)

**Onde esta:** `Chamado.java` (linhas 50-126), `HelpDeskAPI.java` (linha 397)

**O que e:** SLA (Service Level Agreement) e o tempo maximo que um chamado pode ficar sem ser atendido. Se o tempo for excedido, o SLA e considerado "estourado".

**Tempos de SLA por prioridade:**

| Prioridade | Texto | Tempo SLA |
|---|---|---|
| 1 | Critica | 30 minutos |
| 2 | Alta | 2 horas (120 min) |
| 3 | Media | 8 horas (480 min) |
| 4 | Baixa | 24 horas (1440 min) |

**Como funciona no codigo:**
```java
// Em Chamado.java - calcula o SLA baseado na prioridade
private int calcularSla(int prio) {
    switch (prio) {
        case 1: return 30;    // Critica: 30 minutos
        case 2: return 120;   // Alta: 2 horas
        case 3: return 480;   // Media: 8 horas
        default: return 1440; // Baixa: 24 horas
    }
}

// Verifica se o SLA estourou comparando com a data de abertura
public boolean isSlaEstourado() {
    if ("FINALIZADO".equals(status)) return false;  // Finalizado nao estoura
    LocalDateTime abertura = LocalDateTime.parse(dataAbertura, fmt);
    long minutosPassados = ChronoUnit.MINUTES.between(abertura, LocalDateTime.now());
    return minutosPassados > tempoSlaMinutos;  // Se passou do tempo, estourou
}
```

**Na interface:**
- Dashboard mostra quantidade de SLAs estourados
- Na lista de chamados, cada um mostra badge verde "SLA: 30 min" ou badge vermelho pulsante "SLA" quando estourado
- Linhas com SLA estourado ficam com fundo vermelho claro

---

### 5.2 Desfazer (Undo) com Pilha

**Onde esta:** `HelpDeskAPI.java`, metodo `handleDesfazer()` (linhas 489-568)

**O que e:** Permite desfazer a ultima operacao realizada. Usa uma segunda `Pilha` (`pilhaUndo`) que armazena cada acao. Ao clicar "Desfazer", a acao no topo da pilha e removida e revertida.

**Por que e um diferencial:** Demonstra o uso pratico e real da estrutura de Pilha (LIFO). A natureza LIFO da pilha garante que a acao mais recente e sempre a primeira a ser desfeita, exatamente como o Ctrl+Z funciona em qualquer editor.

**Como funciona (passo a passo):**

1. Quando uma operacao e realizada (criar, atender, finalizar), o sistema empilha um `RegistroHistorico` na `pilhaUndo`:
```java
// Ao criar chamado:
pilhaUndo.empilhar(registro);  // Empilha na pilha de undo
```

2. Quando o usuario clica "Desfazer":
```java
// Desempilha a ultima acao
RegistroHistorico acao = pilhaUndo.desempilhar();

// Verifica o tipo e reverte
if ("CRIACAO".equals(tipo)) {
    // Remove o chamado de todas as estruturas
    arvoreChamados.remover(c);
    listaChamados.remover(c);

} else if ("ATENDIMENTO".equals(tipo)) {
    // Volta o chamado para ABERTO e re-enfileira
    c.setStatus("ABERTO");
    filaChamados.enfileirar(c);

} else if ("FINALIZACAO".equals(tipo)) {
    // Volta o chamado para EM_ATENDIMENTO
    c.setStatus("EM_ATENDIMENTO");
    c.setSolucao(null);
    c.setTecnicoResponsavel(null);
    c.setDataFinalizacao(null);
}
```

**Na interface:** Botao amarelo "Desfazer" no topo da pagina. Ao clicar, mostra confirmacao com a descricao da acao que sera desfeita.

---

### 5.3 Travessias Completas da Arvore Binaria

**Onde esta:** `ArvoreBinaria.java` (linhas 136-169), `HelpDeskAPI.java` (linhas 460-477)

O projeto implementa as tres travessias classicas da arvore binaria:

**Em Ordem (In-Order):** Esquerda -> Raiz -> Direita
- Resultado: elementos em ordem crescente (por ID)
- Uso: listar chamados ordenados

**Pre-Ordem (Pre-Order):** Raiz -> Esquerda -> Direita
- Resultado: raiz primeiro, depois subarvores
- Uso: representar a estrutura hierarquica da arvore

**Pos-Ordem (Post-Order):** Esquerda -> Direita -> Raiz
- Resultado: folhas primeiro, raiz por ultimo
- Uso: processamento de baixo para cima

**Na interface:** Menu "Busca (Arvore)" com seletor de modo de travessia. O usuario escolhe emOrdem, preOrdem ou posOrdem e ve os chamados naquela ordem.

---

## Classes de Modelo

### Chamado.java (`backend/src/modelo/Chamado.java`)

Representa um chamado tecnico de suporte. E a classe principal do sistema.

**Atributos:**

| Atributo | Tipo | Descricao |
|---|---|---|
| `id` | int | Identificador unico (auto-incrementa) |
| `titulo` | String | Descricao curta do problema |
| `descricao` | String | Descricao detalhada do problema |
| `prioridade` | int | 1=Critica, 2=Alta, 3=Media, 4=Baixa |
| `status` | String | ABERTO, EM_ATENDIMENTO ou FINALIZADO |
| `nomeUsuario` | String | Quem abriu o chamado |
| `setor` | String | Setor do usuario (TI, RH, etc.) |
| `equipamento` | String | Equipamento relacionado |
| `dataAbertura` | String | Data/hora da criacao (dd/MM/yyyy HH:mm:ss) |
| `dataFinalizacao` | String | Data/hora da finalizacao |
| `tecnicoResponsavel` | String | Tecnico que finalizou |
| `solucao` | String | Descricao da solucao aplicada |
| `tempoSlaMinutos` | int | Tempo maximo SLA em minutos |

**Metodos importantes:**
- `compareTo(Chamado outro)` — Compara por ID (necessario para a ArvoreBinaria, que exige `Comparable`)
- `isSlaEstourado()` — Calcula se o tempo desde a abertura excedeu o SLA
- `getMinutosRestantesSla()` — Retorna quantos minutos faltam para estourar
- `getSlaTexto()` — Retorna texto legivel ("30 min", "2h", "8h", "24h")
- `toJson()` — Serializa o chamado para JSON (para enviar ao frontend)

### Usuario.java (`backend/src/modelo/Usuario.java`)

Representa um usuario do sistema. Atributos: `id`, `nome`, `email`, `setor`, `cargo`. Implementa `Comparable` por ID.

### Equipamento.java (`backend/src/modelo/Equipamento.java`)

Representa um equipamento de TI. Atributos: `id`, `tipo`, `marca`, `patrimonio`, `setor`. Implementa `Comparable` por ID.

### RegistroHistorico.java (`backend/src/modelo/RegistroHistorico.java`)

Representa um registro de operacao armazenado na Pilha. Atributos:
- `tipo` — Tipo da operacao (CRIACAO, ATENDIMENTO, FINALIZACAO, UNDO_CRIACAO, UNDO_ATENDIMENTO, UNDO_FINALIZACAO)
- `chamadoId` — ID do chamado afetado
- `descricao` — Texto descritivo da operacao
- `dataHora` — Data/hora em que ocorreu

---

## API REST

### Como funciona o Backend (HelpDeskAPI.java)

O arquivo `HelpDeskAPI.java` e o coracao do sistema. Ele:

1. **Inicializa** as estruturas de dados e dados de exemplo (`carregarDadosIniciais`)
2. **Cria o servidor HTTP** na porta 8080 usando `com.sun.net.httpserver` (nativo do Java)
3. **Registra endpoints** (rotas) para cada funcionalidade
4. **Processa requisicoes** recebendo JSON, manipulando as estruturas e retornando JSON

**Declaracao das estruturas de dados no inicio da classe:**
```java
// FILA CIRCULAR: Chamados aguardando atendimento (FIFO)
private static final Fila<Chamado> filaChamados = new Fila<>();

// PILHA: Historico de operacoes realizadas (LIFO)
private static final Pilha<RegistroHistorico> pilhaHistorico = new Pilha<>();

// PILHA DE UNDO: Armazena acoes para desfazer
private static final Pilha<RegistroHistorico> pilhaUndo = new Pilha<>();

// LISTA LIGADA: Armazenamento de usuarios, equipamentos e todos os chamados
private static final ListaLigada<Usuario> listaUsuarios = new ListaLigada<>();
private static final ListaLigada<Equipamento> listaEquipamentos = new ListaLigada<>();
private static final ListaLigada<Chamado> listaChamados = new ListaLigada<>();

// ARVORE BINARIA: Busca rapida de chamados por ID
private static final ArvoreBinaria<Chamado> arvoreChamados = new ArvoreBinaria<>();
```

### Metodos handler (processam as requisicoes)

| Metodo | O que faz | Estruturas usadas |
|---|---|---|
| `handleUsuarios` | CRUD de usuarios | ListaLigada |
| `handleEquipamentos` | CRUD de equipamentos | ListaLigada |
| `handleChamados` | Criar, listar, atender, finalizar chamados | Todas |
| `handleFila` | Listar fila de atendimento | Fila |
| `handleHistorico` | Listar historico de operacoes | Pilha |
| `handleEstatisticas` | Dashboard com contagens e metricas | Todas |
| `handleBusca` | Buscar por ID, termo ou travessia | ArvoreBinaria, ListaLigada |
| `handleDesfazer` | Desfazer ultima acao | Pilha (undo), ArvoreBinaria, ListaLigada, Fila |
| `handleOrdenar` | Selection Sort + Busca Binaria | ListaLigada (copia para array) |

### Operacoes de negocio (metodos privados)

| Metodo | O que faz | Passo a passo |
|---|---|---|
| `criarChamado()` | Cria novo chamado | 1. Cria objeto Chamado → 2. `listaChamados.adicionar(c)` → 3. `arvoreChamados.inserir(c)` → 4. `filaChamados.enfileirar(c)` → 5. `pilhaHistorico.empilhar(reg)` → 6. `pilhaUndo.empilhar(reg)` |
| `atenderChamado()` | Inicia atendimento | 1. Verifica se e o proximo da fila → 2. `filaChamados.desenfileirar()` → 3. Muda status para EM_ATENDIMENTO → 4. Empilha nas duas pilhas |
| `finalizarChamado()` | Finaliza chamado | 1. Busca na arvore → 2. Muda status para FINALIZADO → 3. Grava solucao e tecnico → 4. Empilha nas duas pilhas |

### JsonParser.java (`backend/src/util/JsonParser.java`)

Parser JSON simples feito sem bibliotecas externas (como Gson ou Jackson). Tem dois metodos:
- `parse(String json)` — Converte string JSON em `Map<String, String>`
- `toJsonArray(String[] items)` — Converte array de strings JSON em array JSON `[{...},{...}]`

Cada classe de modelo tem seu proprio metodo `toJson()` que gera a representacao JSON manualmente usando `String.format`.

---

## Frontend

### index.html

Pagina unica (SPA - Single Page Application) com todas as telas. A navegacao e feita mostrando/escondendo divs com classe `page`.

**Telas disponiveis:**
1. **Dashboard** — Estatisticas gerais (total chamados, na fila, em atendimento, finalizados, SLA estourados, altura da arvore), grafico de prioridades, ultimas operacoes, proximo na fila
2. **Chamados** — Tabela com todos os chamados, filtro por status, badges de SLA, botoes de acao
3. **Fila de Atendimento** — Lista visual dos chamados na fila (FIFO), botao "Atender" no primeiro
4. **Historico** — Timeline das operacoes registradas na pilha (LIFO), incluindo operacoes de undo
5. **Usuarios** — Tabela de usuarios com CRUD
6. **Equipamentos** — Tabela de equipamentos com CRUD
7. **Busca (Arvore)** — Busca por ID (arvore), busca por termo (lista), seletor de travessia
8. **Ordenacao** — Selection Sort por criterio + Busca Binaria por prioridade
9. **Estruturas de Dados** — Pagina informativa sobre cada estrutura utilizada

### app.js

Logica JavaScript que faz chamadas a API e atualiza a interface. Funcoes principais:

| Funcao | O que faz |
|---|---|
| `apiRequest(endpoint, method, body)` | Faz requisicao HTTP ao backend e retorna JSON |
| `carregarDashboard()` | Carrega e exibe estatisticas no dashboard |
| `carregarChamados()` | Lista chamados com badges de SLA |
| `criarChamado(event)` | Envia POST para criar novo chamado |
| `iniciarAtendimento(id)` | Envia POST para atender o proximo da fila |
| `finalizarChamado(event)` | Envia POST para finalizar com solucao |
| `carregarFila()` | Lista chamados na fila de atendimento |
| `carregarHistorico()` | Lista registros do historico (pilha) |
| `buscarPorId()` | Busca na arvore binaria por ID |
| `buscarPorTermo()` | Busca na lista ligada por texto |
| `listarPorTravessia()` | Executa travessia escolhida (emOrdem/preOrdem/posOrdem) |
| `desfazerUltimaAcao()` | Chama GET para ver proximo undo, depois POST para desfazer |
| `ordenarChamados()` | Chama GET /api/ordenar com criterio para Selection Sort |
| `buscaBinaria()` | Chama GET /api/ordenar com buscaPrioridade para Busca Binaria |

### style.css

Estilos visuais do sistema. Destaques:
- Layout responsivo (sidebar colapsavel em telas pequenas)
- Badges coloridos para prioridade (critica=vermelho, alta=laranja, media=azul, baixa=verde)
- Badges de SLA (verde = dentro do prazo, vermelho pulsante = estourado)
- Cards com bordas coloridas para estatisticas
- Timeline visual para o historico
- Modais para formularios

---

## Fluxo Completo

### Fluxo de criacao e atendimento de um chamado:

```
1. Usuario clica "Novo Chamado"
   └─> Frontend envia POST /api/chamados

2. Backend recebe e executa criarChamado():
   ├─> listaChamados.adicionar(c)      [Lista Ligada: armazena]
   ├─> arvoreChamados.inserir(c)       [Arvore BST: indexa por ID]
   ├─> filaChamados.enfileirar(c)      [Fila: entra na espera]
   ├─> pilhaHistorico.empilhar(reg)    [Pilha: registra operacao]
   └─> pilhaUndo.empilhar(reg)         [Pilha Undo: pode desfazer]

3. Tecnico clica "Atender" no proximo da fila
   └─> Frontend envia POST /api/chamados/atender/{id}

4. Backend executa atenderChamado():
   ├─> filaChamados.espiar()           [Fila: verifica se e o proximo]
   ├─> filaChamados.desenfileirar()    [Fila: remove da fila]
   ├─> c.setStatus("EM_ATENDIMENTO")  [Chamado: muda status]
   ├─> pilhaHistorico.empilhar(reg)    [Pilha: registra]
   └─> pilhaUndo.empilhar(reg)         [Pilha Undo: pode desfazer]

5. Tecnico clica "Finalizar" com solucao
   └─> Frontend envia POST /api/chamados/finalizar/{id}

6. Backend executa finalizarChamado():
   ├─> arvoreChamados.buscar(chave)    [Arvore: localiza o chamado]
   ├─> c.setStatus("FINALIZADO")       [Chamado: muda status]
   ├─> c.setSolucao(solucao)           [Chamado: grava solucao]
   ├─> pilhaHistorico.empilhar(reg)    [Pilha: registra]
   └─> pilhaUndo.empilhar(reg)         [Pilha Undo: pode desfazer]
```

### Fluxo de busca por ID na arvore:

```
1. Usuario digita ID na tela de Busca
   └─> Frontend envia GET /api/busca?id=5

2. Backend executa handleBusca():
   ├─> Cria Chamado chave com id=5
   └─> arvoreChamados.buscar(chave)
       ├─> t = raiz (ex: id=3)
       ├─> 5 > 3: t = t.direita (ex: id=7)
       ├─> 5 < 7: t = t.esquerda (ex: id=5)
       └─> 5 == 5: Achou! Retorna o chamado
```

### Fluxo do Undo (desfazer):

```
1. Usuario clica "Desfazer"
   └─> Frontend envia GET /api/desfazer (para ver o que sera desfeito)

2. Usuario confirma
   └─> Frontend envia POST /api/desfazer

3. Backend executa handleDesfazer():
   ├─> pilhaUndo.desempilhar()         [Remove do topo da pilha]
   ├─> Verifica o tipo da acao:
   │   ├─> CRIACAO: remove chamado da arvore e da lista
   │   ├─> ATENDIMENTO: volta status para ABERTO, re-enfileira
   │   └─> FINALIZACAO: volta status para EM_ATENDIMENTO, limpa solucao
   └─> pilhaHistorico.empilhar(...)    [Registra o undo no historico]
```

---

## Como Executar

### Pre-requisitos
- **Java JDK** instalado (o projeto usa JDK 25 em `C:\JDK\openJdk-25`, mas funciona com JDK 8+)
- **Navegador web** moderno (Chrome, Firefox, Edge)

### Passo 1: Compilar o Backend
```
cd backend
compilar.bat
```
O script `compilar.bat` executa:
```
javac -encoding UTF-8 -d bin src/estruturas/*.java src/modelo/*.java src/util/*.java src/api/*.java
```
Isso compila todos os `.java` e coloca os `.class` na pasta `bin/` com a estrutura de pacotes correta (`bin/helpdesk/estruturas/`, `bin/helpdesk/modelo/`, etc.)

### Passo 2: Executar o Backend
```
cd backend
executar.bat
```
O script `executar.bat` executa:
```
java -cp bin helpdesk.api.HelpDeskAPI
```
A API estara disponivel em `http://localhost:8080`. Voce vera no console:
```
Dados iniciais carregados com sucesso!
===========================================
  Help Desk API rodando em http://localhost:8080
===========================================
```

### Passo 3: Abrir o Frontend
1. Abra o arquivo `frontend/index.html` diretamente no navegador, **ou**
2. Use a extensao "Live Server" do VS Code: clique com botao direito em `index.html` → "Open with Live Server"

**Importante:** O backend precisa estar rodando (Passo 2) antes de usar o frontend.

---

## Endpoints da API

| Metodo | Endpoint | Descricao | Estrutura(s) |
|---|---|---|---|
| GET | `/api/estatisticas` | Dashboard (totais, SLA, altura arvore, undo) | Todas |
| GET | `/api/chamados` | Lista todos os chamados | ListaLigada |
| GET | `/api/chamados/{id}` | Busca chamado por ID | ArvoreBinaria |
| POST | `/api/chamados` | Cria novo chamado | Lista, Fila, Arvore, Pilha (x2) |
| POST | `/api/chamados/atender/{id}` | Inicia atendimento | Fila, Pilha (x2) |
| POST | `/api/chamados/finalizar/{id}` | Finaliza com solucao | Arvore, Pilha (x2) |
| DELETE | `/api/chamados/{id}` | Remove chamado | Arvore, Lista |
| GET | `/api/fila` | Lista fila de atendimento | Fila |
| GET | `/api/historico` | Lista historico | Pilha |
| GET | `/api/usuarios` | Lista usuarios | ListaLigada |
| POST | `/api/usuarios` | Cria usuario | ListaLigada |
| DELETE | `/api/usuarios/{id}` | Remove usuario | ListaLigada |
| GET | `/api/equipamentos` | Lista equipamentos | ListaLigada |
| POST | `/api/equipamentos` | Cria equipamento | ListaLigada |
| DELETE | `/api/equipamentos/{id}` | Remove equipamento | ListaLigada |
| GET | `/api/busca?id={id}` | Busca na arvore por ID | ArvoreBinaria |
| GET | `/api/busca?termo={texto}` | Busca por termo | ListaLigada (filtrar) |
| GET | `/api/busca?modo={modo}` | Travessia (emOrdem/preOrdem/posOrdem) | ArvoreBinaria |
| GET | `/api/desfazer` | Consulta proxima acao desfazivel | Pilha (undo) |
| POST | `/api/desfazer` | Desfaz a ultima acao | Pilha (undo), Arvore, Lista, Fila |
| GET | `/api/ordenar?criterio={c}` | Ordena com Selection Sort | ListaLigada → array |
| GET | `/api/ordenar?criterio=prioridade&buscaPrioridade={p}` | Selection Sort + Busca Binaria | ListaLigada → array |

---

## Tecnologias Utilizadas

- **Java** (`com.sun.net.httpserver`) — API REST sem dependencias externas, nativo do JDK
- **HTML5 / CSS3** — Interface web responsiva com layout moderno
- **JavaScript (Vanilla)** — Logica do frontend usando Fetch API (sem frameworks)
- **Font Awesome 6.5** — Icones
- **Google Fonts (Inter)** — Tipografia

**Nenhuma dependencia externa foi utilizada no backend.** Todo o codigo foi escrito do zero, incluindo:
- As 4 estruturas de dados (Fila, Pilha, Lista Ligada, Arvore Binaria)
- O servidor HTTP (usando API nativa do Java)
- O parser JSON (JsonParser.java)
- A serializacao de objetos para JSON (metodos `toJson()` em cada modelo)

---

## Resumo: Estrutura vs Codigo do Professor

| Estrutura | Estilo do Professor | Como esta no Projeto | Identico? |
|---|---|---|---|
| **Fila** | Array circular, `v[]`, `i`, `f`, `tam`, `N` | Array circular, `v[]`, `i`, `f`, `tam`, `capacidade` | Sim, mesma logica. Adicionado Generics e expansao automatica |
| **Pilha** | Array, `v[]`, `topo`, `N`, topo=-1 vazia | Array, `v[]`, `topo`, `capacidade`, topo=-1 vazia | Sim, mesma logica. Adicionado Generics e expansao automatica |
| **Lista Ligada** | Nos com `dado`/`prox`, `ini` cabeca, `t` percorre | Nos com `dado`/`prox`, `ini` cabeca, `t` percorre | Sim, mesma logica. Adicionado Generics, filtro e busca |
| **Arvore BST** | Insercao iterativa com `while`, travessias recursivas | Insercao iterativa com `while`, travessias recursivas | Sim, mesma logica. Adicionado Generics, posOrdem e getAltura |
| **Selection Sort** | `for(fim)` + `for(i)` + `pos` + troca | `for(fim)` + `for(i)` + `pos` + troca | Sim, identico. Adaptado para objetos Chamado |
| **Busca Binaria** | `while(ini<=fim)` + `meio=(ini+fim)/2` | `while(ini<=fimB)` + `meio=(ini+fimB)/2` | Sim, identico. Aplicado em vetor de Chamados |

Todas as estruturas seguem a mesma abordagem ensinada em aula, com nomes de variaveis consistentes (`t` para percorrer, `ini` para cabeca, `topo` para topo, `v[]` para vetor). As adaptacoes feitas foram para permitir o uso com tipos genericos (`<T>`) e para adicionar funcionalidades extras necessarias ao sistema (como expansao automatica de capacidade e metodos de filtro).
