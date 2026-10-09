package helpdesk.estruturas;

/**
 * Implementação de Lista Ligada (Linked List) usando nós encadeados.
 * Utilizada para armazenar usuários, equipamentos, setores e chamados.
 *
 * Cada Nó (Node) possui um dado e um ponteiro 'prox' para o próximo Nó.
 * A variável 'ini' aponta para a cabeça (primeiro Nó) da Lista.
 */
public class ListaLigada<T> {

    //Classe interna que representa cada Nó da Lista
    private static class No<T> {
        T dado;
        No<T> prox; //aponta para o próximo Nó

        //Construtor
        No(T dado) {
            this.dado = dado;
            this.prox = null; //Importante: aterra o Nó
        }
    }

    //Atributos
    private No<T> ini; //aponta para a Cabeça da Lista Ligada
    private int tamanho;

    //Construtor
    public ListaLigada() {
        this.ini = null; //Lista Vazia
        this.tamanho = 0;
    }

    //Inserir ao final da Lista (percorre até o último Nó)
    public void adicionar(T dado) {
        No<T> novoNo = new No<>(dado);
        if (ini == null) {
            //Lista estava vazia, insere na cabeça
            ini = novoNo;
        } else {
            No<T> t = ini; //t aponta para a cabeça
            while (t.prox != null) {
                t = t.prox; //anda na Lista
            }
            //Chegou ao final, conecta o novo Nó
            t.prox = novoNo;
        }
        tamanho++;
    }

    //Obter elemento por índice (percorre a Lista)
    public T obter(int indice) {
        if (indice < 0 || indice >= tamanho) {
            return null;
        }
        No<T> t = ini; //t aponta para a cabeça
        for (int k = 0; k < indice; k++) {
            t = t.prox; //anda na Lista
        }
        return t.dado;
    }

    //Remover elemento da Lista
    public boolean remover(T dado) {
        if (ini == null) return false; //Lista Vazia

        //Se o elemento está na cabeça
        if (ini.dado.equals(dado)) {
            ini = ini.prox;
            tamanho--;
            return true;
        }

        //Percorre a lista procurando o elemento
        No<T> t = ini;
        while (t.prox != null) {
            if (t.prox.dado.equals(dado)) {
                t.prox = t.prox.prox; //remove o Nó (pula ele)
                tamanho--;
                return true;
            }
            t = t.prox; //anda na Lista
        }
        return false; //Não encontrou
    }

    //Remover por índice
    public boolean removerPorIndice(int indice) {
        if (indice < 0 || indice >= tamanho) return false;

        if (indice == 0) {
            ini = ini.prox;
            tamanho--;
            return true;
        }

        No<T> t = ini;
        for (int k = 0; k < indice - 1; k++) {
            t = t.prox;
        }
        t.prox = t.prox.prox;
        tamanho--;
        return true;
    }

    public int getTamanho() {
        return tamanho;
    }

    public boolean estaVazia() {
        return tamanho == 0;
    }

    //Converte a Lista para array
    @SuppressWarnings("unchecked")
    public T[] paraArray(T[] array) {
        No<T> t = ini;
        int k = 0;
        while (t != null && k < array.length) {
            array[k] = t.dado;
            k++;
            t = t.prox;
        }
        return array;
    }

    //Interface para filtro de busca
    public interface Filtro<T> {
        boolean aceitar(T item);
    }

    //Buscar um elemento na Lista usando filtro
    public T buscar(Filtro<T> filtro) {
        No<T> t = ini; //t aponta para a cabeça
        while (t != null) {
            if (filtro.aceitar(t.dado)) {
                return t.dado; //Encontrou
            }
            t = t.prox; //anda na Lista
        }
        return null; //Não encontrou
    }

    //Filtrar elementos da Lista (retorna nova lista com os que passam no filtro)
    public ListaLigada<T> filtrar(Filtro<T> filtro) {
        ListaLigada<T> resultado = new ListaLigada<>();
        No<T> t = ini; //t aponta para a cabeça
        while (t != null) {
            if (filtro.aceitar(t.dado)) {
                resultado.adicionar(t.dado);
            }
            t = t.prox; //anda na Lista
        }
        return resultado;
    }
}
