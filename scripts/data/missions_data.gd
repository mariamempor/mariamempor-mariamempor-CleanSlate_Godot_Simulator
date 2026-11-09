extends RefCounted
## MISSÕES — catálogo de objetivos e contratos.
##
## Objetivos do ato: no começo de cada ato, o jogo sorteia MISSIONS_PER_ACT
## objetivos do grupo daquele ato. Os marcados com "pinned" sempre entram (são
## os que ensinam o básico). Os outros variam de partida para partida, e alguns
## só entram se a condição "requires" fizer sentido no estado atual.
##
## Contratos: pedidos avulsos do cliente, oferecidos de tempos em tempos. O
## jogador aceita ou deixa passar. Aceito, o contrato tem prazo: cumprir dá a
## recompensa, falhar cobra a penalidade.
##
## Campos de um objetivo:
##   metric   o que é medido (ver Missions._metric_value)
##   target   valor a alcançar        param  detalhe da métrica (empresa, limite)
##   reward   clean, prestige, influence, suspicion (pontos, negativo reduz),
##            perk {id, value} (vantagem permanente), candidate (bool),
##            unlock (empresa liberada antes do ato, com desconto)
##   action   (opcional) botão na aba Missões que avança o objetivo:
##            {label, cost (multiplicado pela escala do ato), metric}

const MISSIONS_PER_ACT: int = 4
## Concluir todos os objetivos do ato rende este bônus, além das recompensas.
const PERFECT_BONUS: Dictionary = {"prestige": 8, "suspicion": -6.0, "perk": {"id": "interception", "value": 3.0}}

const CATALOG: Array = [
	# ------------------------------------------------- ATO 1: aprender e crescer
	{"id": "abrir_caixa", "act": 1, "pinned": true, "title": "Abra o caixa",
		"text": "Faça {target} operações nas suas empresas.", "metric": "ops", "target": 4.0,
		"reward": {"clean": 25000.0}},
	{"id": "gente_confianca", "act": 1, "pinned": true, "title": "Gente de confiança",
		"text": "Tenha {target} laranjas trabalhando para você.", "metric": "staff", "target": 2.0,
		"reward": {"clean": 20000.0, "candidate": true}},
	{"id": "volume_caixa", "act": 1, "title": "Volume de caixa",
		"text": "Lave {target_money} neste ato.", "metric": "laundered", "target": 700000.0,
		"reward": {"clean": 60000.0}},
	{"id": "livros_ordem", "act": 1, "title": "Livros em ordem",
		"text": "Resolva uma fiscalização da Receita sem ignorá-la.", "metric": "threats", "param": "fiscalizacao", "target": 1.0,
		"reward": {"prestige": 4, "suspicion": -5.0}},
	{"id": "perfil_discreto", "act": 1, "title": "Perfil discreto",
		"text": "Feche {target} turnos seguidos com a suspeita abaixo de {param}%.", "metric": "calm_streak", "param": 35.0, "target": 3.0,
		"reward": {"perk": {"id": "loss_discount", "value": 0.01}}},
	{"id": "primeiro_luxo", "act": 1, "title": "Primeiro luxo",
		"text": "Chegue a {target} pontos de prestígio.", "metric": "prestige", "target": 8.0,
		"reward": {"clean": 40000.0}},
	{"id": "rede_laranjas", "act": 1, "title": "Sócio da noite",
		"text": "Monte uma rede de {target} laranjas. Um empresário da noite quer conhecer você.", "metric": "staff", "target": 4.0,
		"reward": {"unlock": "boate"}},
	{"id": "linha_receita", "act": 1, "title": "Na linha da Receita",
		"text": "Declare {target_money} de renda.", "metric": "declared", "target": 80000.0,
		"reward": {"prestige": 4, "suspicion": -3.0}},

	# ------------------------------------------------- ATO 2: política e gente
	{"id": "portfolio", "act": 2, "pinned": true, "title": "Portfólio diversificado",
		"text": "Tenha {target} empresas.", "metric": "companies", "target": 4.0,
		"reward": {"clean": 250000.0}},
	{"id": "equipe_pro", "act": 2, "title": "Equipe profissional",
		"text": "Tenha {target} operadores (ou acima) na rede.", "metric": "staff_tier", "param": 2.0, "target": 3.0,
		"reward": {"perk": {"id": "staff_cost", "value": 0.2}}},
	{"id": "ninguem_fala", "act": 2, "title": "Ninguém fala",
		"text": "Cuide da rede: agrados contam 1, delações resolvidas sem descarte contam 2. Some {target}.", "metric": "care", "target": 3.0,
		"reward": {"influence": 1, "clean": 120000.0}},
	{"id": "nome_praca", "act": 2, "title": "Nome na praça",
		"text": "Chegue ao nível Respeitado ({target} pontos de prestígio).", "metric": "prestige", "target": 25.0,
		"reward": {"clean": 300000.0, "perk": {"id": "loss_discount", "value": 0.01}}},
	{"id": "brasilia", "act": 2, "title": "Amigos em Brasília",
		"text": "Chegue a {target} pontos de influência política.", "metric": "influence", "target": 4.0,
		"reward": {"prestige": 10, "suspicion": -5.0}},
	{"id": "inquerito", "act": 2, "title": "Sobreviver ao inquérito",
		"text": "Resolva {target} ameaças da Polícia Federal sem ignorá-las.", "metric": "threats", "param": "pf", "target": 2.0,
		"reward": {"clean": 350000.0, "suspicion": -6.0}},
	{"id": "dinheiro_trabalha", "act": 2, "title": "Dinheiro trabalhando",
		"text": "Tenha {target_money} aplicados em fundos.", "metric": "funds", "target": 1000000.0,
		"reward": {"perk": {"id": "yield", "value": 0.002}}},
	{"id": "lavanderia_grande", "act": 2, "title": "Máquina de lavar",
		"text": "Lave {target_money} neste ato.", "metric": "laundered", "target": 4500000.0,
		"reward": {"clean": 300000.0}},

	# ------------------------------------------------- ATO 3: escala e saída
	{"id": "rota_saida", "act": 3, "pinned": true, "title": "Preparar a saída",
		"text": "Monte a rota de fuga em {target} etapas: piloto, documentos e pista. Uma etapa por turno.", "metric": "prep", "target": 3.0,
		"action": {"label": "FINANCIAR ETAPA", "cost": 60000.0, "metric": "prep"},
		"reward": {"perk": {"id": "escape", "value": 1.0}}},
	{"id": "patrimonio_exterior", "act": 3, "title": "Patrimônio internacional",
		"text": "Tenha {target_money} no fundo offshore.", "metric": "offshore", "target": 4000000.0,
		"reward": {"perk": {"id": "interception", "value": 6.0}}},
	{"id": "rota_atlantica", "act": 3, "title": "Rota atlântica",
		"text": "Compre a Atlântica Trading.", "metric": "owns", "param": "trading", "target": 1.0,
		"reward": {"clean": 1200000.0}},
	{"id": "carteira_fria", "act": 3, "title": "Carteira fria",
		"text": "Tenha {target_money} em cripto.", "metric": "crypto", "target": 2500000.0,
		"reward": {"perk": {"id": "monero_fee", "value": 0.03}}},
	{"id": "sem_rastros", "act": 3, "title": "Sem rastros",
		"text": "Resolva uma auditoria da Interpol ou uma crise internacional sem ignorá-la.", "metric": "threats", "param": "intl", "target": 1.0,
		"reward": {"suspicion": -8.0, "prestige": 8}},
	{"id": "confianca_cartel", "act": 3, "title": "Confiança do cartel",
		"text": "Feche {target} turnos seguidos com a suspeita abaixo de {param}%.", "metric": "calm_streak", "param": 50.0, "target": 4.0,
		"reward": {"perk": {"id": "interception", "value": 5.0}}},
	{"id": "intocavel", "act": 3, "title": "Intocável",
		"text": "Chegue ao nível Intocável ({target} pontos de prestígio).", "metric": "prestige", "target": 120.0,
		"reward": {"perk": {"id": "loss_discount", "value": 0.02}}},
	{"id": "escala_global", "act": 3, "title": "Escala global",
		"text": "Lave {target_money} neste ato.", "metric": "laundered", "target": 20000000.0,
		"reward": {"clean": 1500000.0}}
]

## Contratos avulsos. "size" é multiplicado pela remessa do ato; "turns" é o prazo.
## Métricas: laundered (volume total), company (volume em uma empresa),
## quiet (turnos fechados sem operar), calm (turnos abaixo de uma suspeita),
## donation (doações eleitorais).
const CONTRACTS: Array = [
	{"id": "lote_urgente", "act": 1, "title": "Lote urgente",
		"text": "O cliente precisa de {target_money} limpos em {turns} turnos.", "metric": "laundered", "size": 1.6, "turns": 2,
		"reward_share": 0.10, "penalty": {"suspicion": 6.0, "clean_share": 0.04}},
	{"id": "pela_empresa", "act": 1, "title": "Nota fria",
		"text": "Passe {target_money} pela {company} em {turns} turnos: o cliente quer essa empresa no papel.", "metric": "company", "size": 1.2, "turns": 3,
		"reward_share": 0.12, "reward_prestige": 4, "penalty": {"prestige": -3}},
	{"id": "fique_quieto", "act": 1, "title": "Fique quieto",
		"text": "Há olhos no setor. Feche {turns} turno sem nenhuma operação.", "metric": "quiet", "target": 1.0, "turns": 2,
		"reward_suspicion": -8.0, "reward_share": 0.05, "penalty": {"suspicion": 5.0}},
	{"id": "abaixo_radar", "act": 1, "title": "Abaixo do radar",
		"text": "Feche {target} turnos seguidos com a suspeita abaixo de {param}%.", "metric": "calm", "param": 45.0, "target": 2.0, "turns": 3,
		"reward_share": 0.08, "penalty": {"clean_share": 0.03}},
	{"id": "favor_politico", "act": 2, "title": "Favor político",
		"text": "Um aliado precisa de caixa de campanha. Faça {target} doação eleitoral em {turns} turnos.", "metric": "donation", "target": 1.0, "turns": 2,
		"reward_influence": 1, "reward_share": 0.05, "penalty": {"influence": -1}},
	{"id": "comprador_arte", "act": 3, "title": "Comprador de arte",
		"text": "Um colecionador quer {target_money} em obras \"vendidas\" pela {company} em {turns} turnos.", "metric": "company", "company": "galeria", "size": 0.6, "turns": 3,
		"reward_share": 0.12, "reward_prestige": 6, "penalty": {"suspicion": 6.0}}
]
