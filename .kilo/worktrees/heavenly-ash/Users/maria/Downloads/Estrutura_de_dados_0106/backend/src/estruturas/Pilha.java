package helpdesk.estruturas;


public class Pilha<T> {

    //Atributos
    private Object[] v;     //vetor que armazena os elementos da Pilha
    private int topo;        //indica o topo da Pilha (-1 = vazia)
    private int capacidade;  //tamanho máximo do vetor

    //Construtor
    public Pilha() {
        this.capacidade = 100; //capacidade inicial
        this.v = new Object[capacidade];
        this.topo = -1; //Pilha Vazia
    }

    //Inserir no topo da Pilha (push/empilhar)
    public void empilhar(T dado) {
        topo++;
        if (topo == capacidade) {
            //Pilha Cheia, aumenta capacidade
            aumentarCapacidade();
        }
        v[topo] = dado;
    }

    //Remover do topo da Pilha (pop/desempilhar)
    @SuppressWarnings("unchecked")
    public T desempilhar() {
        if (topo == -1) {
            return null; //Pilha Vazia
        }
        T x = (T) v[topo];
        v[topo] = null;
        topo--;
        return x;
    }

    //Espiar o topo sem remover
    @SuppressWarnings("unchecked")
    public T espiar() {
        if (topo == -1) {
            return null; //Pilha Vazia
        }
        return (T) v[topo];
    }

    public boolean estaVazia() {
        return topo == -1;
    }

    public int getTamanho() {
        return topo + 1;
    }

    //Converte a Pilha para array (do topo para a base)
    @SuppressWarnings("unchecked")
    public T[] paraArray(T[] array) {
        int j = 0;
        for (int k = topo; k >= 0 && j < array.length; k--) {
            array[j] = (T) v[k];
            j++;
        }
        return array;
    }

    //Aumenta a capacidade do vetor quando a pilha fica cheia
    private void aumentarCapacidade() {
        int novaCapacidade = capacidade * 2;
        Object[] novoV = new Object[novaCapacidade];
        for (int k = 0; k < capacidade; k++) {
            novoV[k] = v[k];
        }
        v = novoV;
        capacidade = novaCapacidade;
    }
}
