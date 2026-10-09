package helpdesk.modelo;

/**
 * Modelo que representa um usuário do sistema de help desk.
 */
public class Usuario implements Comparable<Usuario> {
    private int id;
    private String nome;
    private String email;
    private String setor;
    private String cargo;

    public Usuario() {}

    public Usuario(int id, String nome, String email, String setor, String cargo) {
        this.id = id;
        this.nome = nome;
        this.email = email;
        this.setor = setor;
        this.cargo = cargo;
    }

    public int getId() { return id; }
    public void setId(int id) { this.id = id; }
    public String getNome() { return nome; }
    public void setNome(String nome) { this.nome = nome; }
    public String getEmail() { return email; }
    public void setEmail(String email) { this.email = email; }
    public String getSetor() { return setor; }
    public void setSetor(String setor) { this.setor = setor; }
    public String getCargo() { return cargo; }
    public void setCargo(String cargo) { this.cargo = cargo; }

    @Override
    public int compareTo(Usuario outro) {
        return Integer.compare(this.id, outro.id);
    }

    @Override
    public boolean equals(Object obj) {
        if (this == obj) return true;
        if (obj == null || getClass() != obj.getClass()) return false;
        Usuario usuario = (Usuario) obj;
        return id == usuario.id;
    }

    @Override
    public int hashCode() {
        return Integer.hashCode(id);
    }

    public String toJson() {
        return String.format(
            "{\"id\":%d,\"nome\":\"%s\",\"email\":\"%s\",\"setor\":\"%s\",\"cargo\":\"%s\"}",
            id, escapeJson(nome), escapeJson(email), escapeJson(setor), escapeJson(cargo)
        );
    }

    private String escapeJson(String s) {
        if (s == null) return "";
        return s.replace("\\", "\\\\").replace("\"", "\\\"").replace("\n", "\\n").replace("\r", "\\r");
    }
}
