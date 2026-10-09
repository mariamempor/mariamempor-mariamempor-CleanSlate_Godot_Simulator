package helpdesk.modelo;

/**
 * Modelo que representa um equipamento de informática.
 */
public class Equipamento implements Comparable<Equipamento> {
    private int id;
    private String tipo;
    private String marca;
    private String patrimonio;
    private String setor;

    public Equipamento() {}

    public Equipamento(int id, String tipo, String marca, String patrimonio, String setor) {
        this.id = id;
        this.tipo = tipo;
        this.marca = marca;
        this.patrimonio = patrimonio;
        this.setor = setor;
    }

    public int getId() { return id; }
    public void setId(int id) { this.id = id; }
    public String getTipo() { return tipo; }
    public void setTipo(String tipo) { this.tipo = tipo; }
    public String getMarca() { return marca; }
    public void setMarca(String marca) { this.marca = marca; }
    public String getPatrimonio() { return patrimonio; }
    public void setPatrimonio(String patrimonio) { this.patrimonio = patrimonio; }
    public String getSetor() { return setor; }
    public void setSetor(String setor) { this.setor = setor; }

    @Override
    public int compareTo(Equipamento outro) {
        return Integer.compare(this.id, outro.id);
    }

    @Override
    public boolean equals(Object obj) {
        if (this == obj) return true;
        if (obj == null || getClass() != obj.getClass()) return false;
        Equipamento equip = (Equipamento) obj;
        return id == equip.id;
    }

    @Override
    public int hashCode() {
        return Integer.hashCode(id);
    }

    public String toJson() {
        return String.format(
            "{\"id\":%d,\"tipo\":\"%s\",\"marca\":\"%s\",\"patrimonio\":\"%s\",\"setor\":\"%s\"}",
            id, escapeJson(tipo), escapeJson(marca), escapeJson(patrimonio), escapeJson(setor)
        );
    }

    private String escapeJson(String s) {
        if (s == null) return "";
        return s.replace("\\", "\\\\").replace("\"", "\\\"").replace("\n", "\\n").replace("\r", "\\r");
    }
}
