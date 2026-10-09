package helpdesk.estruturas;

/**
 * Implementação de Árvore Binária de Busca (BST).
 * Utilizada para buscar e organizar chamados por código/prioridade.
 *
 * Inserção e busca usam laços iterativos (while),
 * enquanto as travessias (inOrder, preOrder, posOrder) usam recursão.
 */
public class ArvoreBinaria<T extends Comparable<T>> {

    //Classe interna que representa cada Nó da Árvore
    private static class No<T> {
        T dado;
        No<T> esquerda; //filho esquerdo (menor)
        No<T> direita;  //filho direito (maior)

        //Construtor
        No(T dado) {
            this.dado = dado;
            this.esquerda = null;
            this.direita = null;
        }
    }

    //Atributos
    private No<T> raiz;
    private int tamanho;

    //Construtor
    public ArvoreBinaria() {
        this.raiz = null;
        this.tamanho = 0;
    }

    //Inserção iterativa (percorre a árvore com while)
    public void inserir(T dado) {
        if (raiz == null) {
            raiz = new No<>(dado);
            tamanho++;
            return;
        }
        No<T> t = raiz; //t percorre a árvore a partir da raiz
        while (true) {
            int cmp = dado.compareTo(t.dado);
            if (cmp == 0) {
                //Valor já existe, atualiza o dado
                t.dado = dado;
                return;
            }
            if (cmp < 0) { //dado é menor, vai para a esquerda
                if (t.esquerda == null) {
                    t.esquerda = new No<>(dado);
                    tamanho++;
                    return;
                }
                t = t.esquerda; //t pula para o Nó esquerdo
            } else { //dado é maior, vai para a direita
                if (t.direita == null) {
                    t.direita = new No<>(dado);
                    tamanho++;
                    return;
                }
                t = t.direita; //t pula para o Nó direito
            }
        }
    }

    //Busca iterativa (percorre a árvore com while)
    public T buscar(T chave) {
        if (raiz == null) {
            return null;
        }
        No<T> t = raiz; //t percorre a árvore a partir da raiz
        while (t != null) {
            int cmp = chave.compareTo(t.dado);
            if (cmp == 0) {
                return t.dado; //Achou
            }
            if (cmp < 0) {
                t = t.esquerda; //anda para a esquerda
            } else {
                t = t.direita; //anda para a direita
            }
        }
        return null; //Não achou
    }

    //Remoção de um elemento da árvore
    public boolean remover(T dado) {
        int tamanhoAntes = tamanho;
        raiz = removerNo(raiz, dado);
        return tamanho < tamanhoAntes;
    }

    //Método auxiliar para remover nó (usa recursão por necessidade estrutural)
    private No<T> removerNo(No<T> no, T dado) {
        if (no == null) return null;

        int cmp = dado.compareTo(no.dado);
        if (cmp < 0) {
            no.esquerda = removerNo(no.esquerda, dado);
        } else if (cmp > 0) {
            no.direita = removerNo(no.direita, dado);
        } else {
            tamanho--;
            if (no.esquerda == null) return no.direita;
            if (no.direita == null) return no.esquerda;

            //Encontra o menor da subárvore direita (sucessor)
            No<T> sucessor = no.direita;
            while (sucessor.esquerda != null) {
                sucessor = sucessor.esquerda;
            }
            no.dado = sucessor.dado;
            no.direita = removerNo(no.direita, sucessor.dado);
            tamanho++;
        }
        return no;
    }

    public int getTamanho() {
        return tamanho;
    }

    public boolean estaVazia() {
        return tamanho == 0;
    }

    //Interface para o padrão Visitante nas travessias
    public interface Visitante<T> {
        void visitar(T dado);
    }

    //Travessia Em Ordem (esquerda, raiz, direita) - mostra em ordem crescente
    public void emOrdem(Visitante<T> visitante) {
        emOrdem(raiz, visitante);
    }

    private void emOrdem(No<T> t, Visitante<T> visitante) {
        if (t == null) return;
        emOrdem(t.esquerda, visitante);
        visitante.visitar(t.dado);
        emOrdem(t.direita, visitante);
    }

    //Travessia Pré-Ordem (raiz, esquerda, direita)
    public void preOrdem(Visitante<T> visitante) {
        preOrdem(raiz, visitante);
    }

    private void preOrdem(No<T> t, Visitante<T> visitante) {
        if (t == null) return;
        visitante.visitar(t.dado);
        preOrdem(t.esquerda, visitante);
        preOrdem(t.direita, visitante);
    }

    //Travessia Pós-Ordem (esquerda, direita, raiz)
    public void posOrdem(Visitante<T> visitante) {
        posOrdem(raiz, visitante);
    }

    private void posOrdem(No<T> t, Visitante<T> visitante) {
        if (t == null) return;
        posOrdem(t.esquerda, visitante);
        posOrdem(t.direita, visitante);
        visitante.visitar(t.dado);
    }

    //Retorna a altura da árvore (usado nas estatísticas)
    public int getAltura() {
        return calcularAltura(raiz);
    }

    private int calcularAltura(No<T> t) {
        if (t == null) return 0;
        int altEsq = calcularAltura(t.esquerda);
        int altDir = calcularAltura(t.direita);
        if (altEsq > altDir) return altEsq + 1;
        return altDir + 1;
    }
}
