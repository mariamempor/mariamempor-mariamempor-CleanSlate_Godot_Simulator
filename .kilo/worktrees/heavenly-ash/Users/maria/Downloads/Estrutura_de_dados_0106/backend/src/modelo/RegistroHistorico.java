package helpdesk.modelo;

/**
 * Modelo que representa um registro no histórico de operações (usado na Pilha).
 */
public class RegistroHistorico {
    private String tipo;       // ATENDIMENTO, FINALIZACAO, CRIACAO
    private int chamadoId;
    private String descricao;
    private String dataHora;

    public RegistroHistorico() {}

    public RegistroHistorico(String tipo, int chamadoId, String descricao, String dataHora) {
        this.tipo = tipo;
        this.chamadoId = chamadoId;
        this.descricao = descricao;
        this.dataHora = dataHora;
    }

    public String getTipo() { return tipo; }
    public void setTipo(String tipo) { this.tipo = tipo; }
    public int getChamadoId() { return chamadoId; }
    public void setChamadoId(int chamadoId) { this.chamadoId = chamadoId; }
    public String getDescricao() { return descricao; }
    public void setDescricao(String descricao) { this.descricao = descricao; }
    public String getDataHora() { return dataHora; }
    public void setDataHora(String dataHora) { this.dataHora = dataHora; }

    public String toJson() {
        return String.format(
            "{\"tipo\":\"%s\",\"chamadoId\":%d,\"descricao\":\"%s\",\"dataHora\":\"%s\"}",
            esc(tipo), chamadoId, esc(descricao), esc(dataHora)
        );
    }

    private String esc(String s) {
        if (s == null) return "";
        return s.replace("\\", "\\\\").replace("\"", "\\\"").replace("\n", "\\n").replace("\r", "\\r");
    }
}
