package helpdesk.modelo;

import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.time.temporal.ChronoUnit;

/**
 * Modelo que representa um chamado técnico de suporte.
 * Inclui sistema de SLA (Service Level Agreement) baseado na prioridade.
 */
public class Chamado implements Comparable<Chamado> {
    //Atributos
    private int id;
    private String titulo;
    private String descricao;
    private int prioridade; // 1=Critica, 2=Alta, 3=Media, 4=Baixa
    private String status; // ABERTO, EM_ATENDIMENTO, FINALIZADO
    private String nomeUsuario;
    private String setor;
    private String equipamento;
    private String dataAbertura;
    private String dataFinalizacao;
    private String tecnicoResponsavel;
    private String solucao;
    private int tempoSlaMinutos; // tempo maximo em minutos para atender (SLA)

    private static final DateTimeFormatter fmt = DateTimeFormatter.ofPattern("dd/MM/yyyy HH:mm:ss");

    //Construtor sem parametros
    public Chamado() {
        this.status = "ABERTO";
    }

    //Construtor com parametros
    public Chamado(int id, String titulo, String descricao, int prioridade,
                   String nomeUsuario, String setor, String equipamento, String dataAbertura) {
        this.id = id;
        this.titulo = titulo;
        this.descricao = descricao;
        this.prioridade = prioridade;
        this.status = "ABERTO";
        this.nomeUsuario = nomeUsuario;
        this.setor = setor;
        this.equipamento = equipamento;
        this.dataAbertura = dataAbertura;
        //Define o tempo de SLA baseado na prioridade
        this.tempoSlaMinutos = calcularSla(prioridade);
    }

    //Calcula o tempo maximo de SLA em minutos baseado na prioridade
    private int calcularSla(int prio) {
        switch (prio) {
            case 1: return 30;   //Critica: 30 minutos
            case 2: return 120;  //Alta: 2 horas
            case 3: return 480;  //Media: 8 horas
            default: return 1440; //Baixa: 24 horas
        }
    }

    public int getId() { return id; }
    public void setId(int id) { this.id = id; }
    public String getTitulo() { return titulo; }
    public void setTitulo(String titulo) { this.titulo = titulo; }
    public String getDescricao() { return descricao; }
    public void setDescricao(String descricao) { this.descricao = descricao; }
    public int getPrioridade() { return prioridade; }
    public void setPrioridade(int prioridade) { this.prioridade = prioridade; }
    public String getStatus() { return status; }
    public void setStatus(String status) { this.status = status; }
    public String getNomeUsuario() { return nomeUsuario; }
    public void setNomeUsuario(String nomeUsuario) { this.nomeUsuario = nomeUsuario; }
    public String getSetor() { return setor; }
    public void setSetor(String setor) { this.setor = setor; }
    public String getEquipamento() { return equipamento; }
    public void setEquipamento(String equipamento) { this.equipamento = equipamento; }
    public String getDataAbertura() { return dataAbertura; }
    public void setDataAbertura(String dataAbertura) { this.dataAbertura = dataAbertura; }
    public String getDataFinalizacao() { return dataFinalizacao; }
    public void setDataFinalizacao(String dataFinalizacao) { this.dataFinalizacao = dataFinalizacao; }
    public String getTecnicoResponsavel() { return tecnicoResponsavel; }
    public void setTecnicoResponsavel(String tecnicoResponsavel) { this.tecnicoResponsavel = tecnicoResponsavel; }
    public String getSolucao() { return solucao; }
    public void setSolucao(String solucao) { this.solucao = solucao; }

    public int getTempoSlaMinutos() { return tempoSlaMinutos; }
    public void setTempoSlaMinutos(int tempoSlaMinutos) { this.tempoSlaMinutos = tempoSlaMinutos; }

    public String getPrioridadeTexto() {
        switch (prioridade) {
            case 1: return "Critica";
            case 2: return "Alta";
            case 3: return "Media";
            default: return "Baixa";
        }
    }

    //Retorna o texto do SLA (ex: "30 min", "2h", "8h", "24h")
    public String getSlaTexto() {
        if (tempoSlaMinutos < 60) return tempoSlaMinutos + " min";
        return (tempoSlaMinutos / 60) + "h";
    }

    //Verifica se o SLA esta estourado (tempo desde abertura > tempoSlaMinutos)
    public boolean isSlaEstourado() {
        if ("FINALIZADO".equals(status)) return false;
        if (dataAbertura == null || dataAbertura.isEmpty()) return false;
        try {
            LocalDateTime abertura = LocalDateTime.parse(dataAbertura, fmt);
            long minutosPassados = ChronoUnit.MINUTES.between(abertura, LocalDateTime.now());
            return minutosPassados > tempoSlaMinutos;
        } catch (Exception e) {
            return false;
        }
    }

    //Retorna quantos minutos restam para o SLA (negativo = estourado)
    public long getMinutosRestantesSla() {
        if (dataAbertura == null || dataAbertura.isEmpty()) return tempoSlaMinutos;
        try {
            LocalDateTime abertura = LocalDateTime.parse(dataAbertura, fmt);
            long minutosPassados = ChronoUnit.MINUTES.between(abertura, LocalDateTime.now());
            return tempoSlaMinutos - minutosPassados;
        } catch (Exception e) {
            return tempoSlaMinutos;
        }
    }

    @Override
    public int compareTo(Chamado outro) {
        return Integer.compare(this.id, outro.id);
    }

    @Override
    public boolean equals(Object obj) {
        if (this == obj) return true;
        if (obj == null || getClass() != obj.getClass()) return false;
        Chamado chamado = (Chamado) obj;
        return id == chamado.id;
    }

    @Override
    public int hashCode() {
        return Integer.hashCode(id);
    }

    public String toJson() {
        return String.format(
            "{\"id\":%d,\"titulo\":\"%s\",\"descricao\":\"%s\",\"prioridade\":%d,\"prioridadeTexto\":\"%s\"," +
            "\"status\":\"%s\",\"nomeUsuario\":\"%s\",\"setor\":\"%s\",\"equipamento\":\"%s\"," +
            "\"dataAbertura\":\"%s\",\"dataFinalizacao\":\"%s\",\"tecnicoResponsavel\":\"%s\",\"solucao\":\"%s\"," +
            "\"tempoSlaMinutos\":%d,\"slaTexto\":\"%s\",\"slaEstourado\":%b,\"minutosRestantesSla\":%d}",
            id, esc(titulo), esc(descricao), prioridade, getPrioridadeTexto(),
            esc(status), esc(nomeUsuario), esc(setor), esc(equipamento),
            esc(dataAbertura), esc(dataFinalizacao), esc(tecnicoResponsavel), esc(solucao),
            tempoSlaMinutos, esc(getSlaTexto()), isSlaEstourado(), getMinutosRestantesSla()
        );
    }

    private String esc(String s) {
        if (s == null) return "";
        return s.replace("\\", "\\\\").replace("\"", "\\\"").replace("\n", "\\n").replace("\r", "\\r");
    }
}
