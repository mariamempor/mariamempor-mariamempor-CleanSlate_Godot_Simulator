package helpdesk.estruturas;

/**
 * Implementação de Fila Circular (Queue) usando array.
 * Utilizada para organizar chamados aguardando atendimento (FIFO).
 *
 * Estrutura baseada em Fila Circular com ponteiros i (início) e f (fim),
 * e variável tam para controlar o número de elementos.
 */
public class Fila<T> {

    //Atributos
    private Object[] v;     //vetor que armazena os elementos da Fila
    private int i;           //posição do início da Fila
    private int f;           //posição do fim da Fila
    private int tam;         //número de elementos na Fila
    private int capacidade;  //tamanho máximo do vetor

    //Construtor
    public Fila() {
        this.capacidade = 100; //capacidade inicial
        this.v = new Object[capacidade];
        this.i = 0;
        this.f = -1;  //Fila Vazia no Início
        this.tam = 0;
    }

    //Inserir elemento na Fila (enfileirar)
    public void enfileirar(T dado) {
        //Se a fila estiver cheia, aumenta o vetor
        if (tam == capacidade) {
            aumentarCapacidade();
        }
        f++; //incrementa f (posição do fim)
        if (f >= capacidade) {
            f = 0; //Circular
        }
        v[f] = dado;
        tam++;
    }

    //Remover elemento da Fila (desenfileirar)
    @SuppressWarnings("unchecked")
    public T desenfileirar() {
        if (tam == 0) {
            return null; //Fila Vazia
        }
        T saiu = (T) v[i]; //pega o valor do início
        v[i] = null;
        tam--;
        i++;
        if (i >= capacidade) {
            i = 0; //Circular
        }
        return saiu;
    }

    //Espiar o primeiro elemento sem remover
    @SuppressWarnings("unchecked")
    public T espiar() {
        if (tam == 0) {
            return null; //Fila Vazia
        }
        return (T) v[i];
    }

    public boolean estaVazia() {
        return tam == 0;
    }

    public int getTamanho() {
        return tam;
    }

    //Converte a Fila para um array (percorre circularmente)
    @SuppressWarnings("unchecked")
    public T[] paraArray(T[] array) {
        int j = i; //j percorre a fila circular a partir do início
        for (int k = 0; k < tam && k < array.length; k++) {
            array[k] = (T) v[j];
            j++;
            if (j >= capacidade) {
                j = 0; //Circular
            }
        }
        return array;
    }

    //Aumenta a capacidade do vetor quando a fila fica cheia
    private void aumentarCapacidade() {
        int novaCapacidade = capacidade * 2;
        Object[] novoV = new Object[novaCapacidade];
        int j = i; //j percorre a fila circular
        for (int k = 0; k < tam; k++) {
            novoV[k] = v[j];
            j++;
            if (j >= capacidade) {
                j = 0; //Circular
            }
        }
        v = novoV;
        i = 0;
        f = tam - 1;
        capacidade = novaCapacidade;
    }
}
