extends RefCounted
## BALANCEAMENTO — todos os números do jogo ficam aqui.
##
## Para deixar o jogo mais fácil ou mais difícil, mexa só neste arquivo:
## nenhuma regra em outro script tem número "solto". Os sistemas leem daqui com
##   const B = preload("res://scripts/data/balance.gd")

# ---------------------------------------------------------
# Início de campanha e regras gerais
# ---------------------------------------------------------
const START_DIRTY: float = 125000.0
const START_CLEAN: float = 15000.0
const START_SUSPICION: float = 15.5
const MAX_SUSPICION: float = 100.0
const MIN_OPERATION: float = 1000.0       # menor valor de uma operação
const WORK_START_MINUTES: int = 8 * 60

## Dinheiro sujo parado chama atenção: acima de PILE_DAYS remessas acumuladas,
## a suspeita sobe PILE_PENALTY por noite.
const PILE_DAYS: float = 3.0
const PILE_PENALTY: float = 2.0

# ---------------------------------------------------------
# Atos
# ---------------------------------------------------------
## goal      meta de PATRIMÔNIO (saldo limpo + bens + empresas + carteira)
## days      prazo do ato
## remessa   dinheiro sujo que o cliente entrega por dia
## bonus     adiantamento em saldo limpo que o cliente paga ao promover você
## scale     multiplicador de custos (ações de risco, multas, propinas, fuga)
## limit     suspeita que encerra o jogo naquele ato
## decay     fração da suspeita que some sozinha a cada noite (0.10 = 10%)
const ACTS: Array = [
	{
		"id": 1,
		"name": "O Pequeno Operador",
		"focus": "Lavagem básica em pequenos negócios locais.",
		"threat": "Receita Federal",
		"threat_text": "Fiscalizações de rotina.",
		"goal": 2000000.0,
		"days": 30,
		"remessa": 140000.0,
		"bonus": 0.0,
		"scale": 1.0,
		"limit": 100.0,
		"decay": 0.10,
		"unlocks": ["Lavanderia e bar já são seus.", "Laranjas aumentam a capacidade das empresas.", "Bens de luxo dão prestígio, mas chamam a Receita."]
	},
	{
		"id": 2,
		"name": "O Consultor Político e Corporativo",
		"focus": "Contratos públicos, doações eleitorais e negócios maiores.",
		"threat": "Polícia Federal",
		"threat_text": "Investigações, grampos telefônicos e delações.",
		"goal": 15000000.0,
		"days": 45,
		"remessa": 750000.0,
		"bonus": 400000.0,
		"scale": 6.0,
		"limit": 100.0,
		"decay": 0.10,
		"unlocks": ["Boate, concessionária e construtora à venda.", "Operadores: laranjas de capacidade maior.", "Doações eleitorais geram influência política.", "Fundos de investimento na aba Carteira.", "Suspeita acima de 80% por 3 dias gera mandado de prisão."]
	},
	{
		"id": 3,
		"name": "O Sindicato Global e Offshores",
		"focus": "Criptomoedas, paraísos fiscais e obras de arte.",
		"threat": "Interpol e o cartel",
		"threat_text": "A Interpol não esquece: a suspeita cai mais devagar. Acima de 90%, o cartel queima o arquivo.",
		"goal": 100000000.0,
		"days": 60,
		"remessa": 3000000.0,
		"bonus": 4000000.0,
		"scale": 20.0,
		"limit": 90.0,
		"decay": 0.08,
		"unlocks": ["Galeria de arte e trading offshore à venda.", "Doleiros: o nível mais alto de operador.", "Fundo offshore na aba Carteira.", "O limite de suspeita cai para 90%.", "A suspeita cai mais devagar: 8% por noite.", "Bater a meta inicia a Operação Fuga."]
	}
]

const DEADLINE_EXTENSION_DAYS: int = 5      # prorrogação única por ato
const DEADLINE_PENALTY: float = 0.15        # fatia do saldo limpo cobrada pelo atraso

## Mandado de prisão (atos 2 e 3): suspeita no fim do dia >= MANDADO_LEVEL por
## MANDADO_DAYS dias seguidos.
const MANDADO_LEVEL: float = 80.0
const MANDADO_DAYS: int = 3

# ---------------------------------------------------------
# Empresas de fachada
# ---------------------------------------------------------
## capacity  quanto a empresa processa por DIA (sem laranjas)
## loss      fatia perdida na operação
## risk      pontos de suspeita gerados ao usar 100% da capacidade do dia
## act       ato em que fica disponível      price  preço de compra (0 = já é sua)
## value     valor contábil (entra no patrimônio e é a base da venda na fuga)
## prestige  nível de prestígio exigido      slots  vagas para laranjas
const COMPANIES: Dictionary = {
	"lavanderia": {
		"name": "Lavanderia Pura Vida", "tag": "Varejo / Serviços",
		"capacity": 18000.0, "loss": 0.12, "risk": 4.5, "reputation": 72,
		"act": 1, "price": 0.0, "value": 60000.0, "prestige": 0, "slots": 2,
		"description": "Operação de giro rápido, com capacidade pequena e risco controlável."
	},
	"bar": {
		"name": "Bar Oasis", "tag": "Entretenimento",
		"capacity": 26000.0, "loss": 0.16, "risk": 7.0, "reputation": 64,
		"act": 1, "price": 0.0, "value": 90000.0, "prestige": 0, "slots": 2,
		"description": "Alta circulação de dinheiro vivo e mais exposição a fiscalização."
	},
	"boate": {
		"name": "Boate Necturne", "tag": "Vida Noturna",
		"capacity": 120000.0, "loss": 0.20, "risk": 9.0, "reputation": 51,
		"act": 2, "price": 250000.0, "value": 250000.0, "prestige": 0, "slots": 2,
		"description": "Caixa alto todas as noites. O custo é pesado e a fiscalização fica de olho."
	},
	"concessionaria": {
		"name": "Concessionária Nova", "tag": "Automotivo",
		"capacity": 180000.0, "loss": 0.18, "risk": 10.0, "reputation": 58,
		"act": 2, "price": 400000.0, "value": 400000.0, "prestige": 0, "slots": 2,
		"description": "Movimentações grandes e espaçadas. Exige gestão de risco."
	},
	"construtora": {
		"name": "Construtora Horizonte", "tag": "Contratos Públicos",
		"capacity": 420000.0, "loss": 0.14, "risk": 11.0, "reputation": 60,
		"act": 2, "price": 1200000.0, "value": 1200000.0, "prestige": 2, "slots": 3,
		"description": "Obras públicas superfaturadas. Só abre as portas para quem tem nome na praça."
	},
	"galeria": {
		"name": "Galeria Meridiano", "tag": "Arte e Leilões",
		"capacity": 1200000.0, "loss": 0.10, "risk": 12.0, "reputation": 77,
		"act": 3, "price": 4500000.0, "value": 4500000.0, "prestige": 3, "slots": 3,
		"description": "O preço de uma obra é o que alguém aceita pagar. Margem ótima, clientela discreta."
	},
	"trading": {
		"name": "Atlântica Trading", "tag": "Offshore",
		"capacity": 2500000.0, "loss": 0.08, "risk": 16.0, "reputation": 69,
		"act": 3, "price": 10000000.0, "value": 10000000.0, "prestige": 4, "slots": 3,
		"description": "Importação e exportação entre paraísos fiscais. O maior volume e o maior holofote."
	}
}

const COMPANY_ORDER: Array = ["lavanderia", "bar", "boate", "concessionaria", "construtora", "galeria", "trading"]

# ---------------------------------------------------------
# Laranjas e operadores
# ---------------------------------------------------------
## capacity e cost são faixas [mínimo, máximo] sorteadas para cada candidato.
const STAFF_TIERS: Array = [
	{"tier": 1, "title": "Laranja", "act": 1, "capacity": [18000.0, 30000.0], "cost": [700.0, 1300.0]},
	{"tier": 2, "title": "Operador", "act": 2, "capacity": [95000.0, 160000.0], "cost": [6000.0, 11000.0]},
	{"tier": 3, "title": "Doleiro", "act": 3, "capacity": [250000.0, 450000.0], "cost": [18000.0, 32000.0]}
]
const STAFF_HIRE_DAYS: float = 4.0          # taxa de contratação = 4 diárias
const STAFF_CANDIDATES: int = 3
const STAFF_STRESS_LEVEL: float = 50.0      # suspeita a partir da qual o estresse sobe
const STAFF_STRESS_BASE: float = 4.0
const STAFF_STRESS_RELIEF: float = 5.0      # queda por noite com a suspeita baixa
const STAFF_BONUS_DAYS: float = 3.0         # um agrado custa 3 diárias
const STAFF_BONUS_STRESS: float = 22.0
const STAFF_BONUS_LOYALTY: float = 6.0
const STAFF_UNPAID_STRESS: float = 15.0
const STAFF_UNPAID_LOYALTY: float = 10.0
const STAFF_DISMISS_DAYS: float = 3.0       # dispensa amigável = 3 diárias
## Delação premiada
const DELATION_DEADLINE: int = 2            # noites até o acordo ser fechado
const DELATION_SILENCE_DAYS: float = 25.0   # pagar silêncio = 25 diárias
const DELATION_EXILE_DAYS: float = 12.0     # exílio = 12 diárias, em cripto
const DELATION_DISCARD_SUSPICION: float = 15.0
const DELATION_DISCARD_BLOCK: int = 3       # dias com a empresa parada
const DELATION_DISCARD_LOSS: float = 2.0    # dinheiro retido = 2x a capacidade do laranja

const STAFF_FIRST_NAMES: Array = ["Ademir", "Sueli", "Jurandir", "Cleide", "Valdeci", "Marlene", "Edson", "Neusa", "Gilmar", "Rosângela", "Osvaldo", "Ivone", "Wagner", "Dirce", "Nilton", "Aparecida", "Reginaldo", "Solange", "Claudemir", "Zuleica", "Hélio", "Marli", "Roberval", "Odete"]
const STAFF_LAST_NAMES: Array = ["Pacheco", "Tavares", "Bezerra", "Queiroz", "Fontes", "Nogueira", "Barreto", "Siqueira", "Macedo", "Brandão", "Coutinho", "Falcão", "Guedes", "Lacerda", "Meireles", "Prates", "Sardinha", "Vasques"]

# ---------------------------------------------------------
# Bens e estilo de vida
# ---------------------------------------------------------
## weight: quanto do preço conta como ostentação (um iate aparece mais que um quadro).
const GOODS: Array = [
	{"id": "relogio", "cat": "Relógios", "name": "Relógio suíço", "price": 45000.0, "prestige": 3, "act": 1, "weight": 0.6},
	{"id": "gravura", "cat": "Arte", "name": "Gravura assinada", "price": 120000.0, "prestige": 6, "act": 1, "weight": 0.4},
	{"id": "seda", "cat": "Carros", "name": "Sedã de luxo", "price": 280000.0, "prestige": 8, "act": 1, "weight": 1.0},
	{"id": "cobertura", "cat": "Imóveis", "name": "Cobertura duplex", "price": 950000.0, "prestige": 18, "act": 1, "weight": 0.8},
	{"id": "relogio_colecao", "cat": "Relógios", "name": "Relógio de colecionador", "price": 320000.0, "prestige": 10, "act": 2, "weight": 0.6},
	{"id": "lancha", "cat": "Iates", "name": "Lancha esportiva", "price": 750000.0, "prestige": 14, "act": 2, "weight": 1.2},
	{"id": "esportivo", "cat": "Carros", "name": "Esportivo italiano", "price": 1900000.0, "prestige": 26, "act": 2, "weight": 1.0},
	{"id": "tela", "cat": "Arte", "name": "Tela modernista", "price": 2400000.0, "prestige": 34, "act": 2, "weight": 0.4},
	{"id": "mansao", "cat": "Imóveis", "name": "Mansão no litoral", "price": 6500000.0, "prestige": 50, "act": 2, "weight": 0.8},
	{"id": "iate", "cat": "Iates", "name": "Iate de 40 metros", "price": 9000000.0, "prestige": 60, "act": 3, "weight": 1.2},
	{"id": "hipercarro", "cat": "Carros", "name": "Hipercarro de série limitada", "price": 14000000.0, "prestige": 70, "act": 3, "weight": 1.0},
	{"id": "obra_prima", "cat": "Arte", "name": "Obra-prima de leilão", "price": 22000000.0, "prestige": 95, "act": 3, "weight": 0.4},
	{"id": "villa", "cat": "Imóveis", "name": "Villa na Riviera", "price": 38000000.0, "prestige": 110, "act": 3, "weight": 0.8}
]

## Pontos de prestígio para cada nível e o nome do nível.
const PRESTIGE_TIERS: Array = [10, 30, 80, 160]
const PRESTIGE_NAMES: Array = ["Desconhecido", "Conhecido", "Respeitado", "Influente", "Intocável"]
const PRESTIGE_LOSS_DISCOUNT: float = 0.015   # desconto bancário por nível, no custo das empresas

## Malha fina
const INCOME_TAX: float = 0.15              # imposto pago sobre a renda declarada
const OSTENTATION_COVER: float = 0.5        # renda declarada cobre metade em ostentação
const AUDIT_MIN_CHANCE: float = 0.05
const AUDIT_MAX_CHANCE: float = 0.45
const AUDIT_FINE: float = 0.30              # multa sobre a ostentação sem cobertura
const AUDIT_CONTEST_COST: float = 0.05
const AUDIT_CONTEST_ODDS: float = 0.5
const AUDIT_CONTEST_FINE: float = 0.45
const AUDIT_SEIZE_SUSPICION: float = 4.0
const GOODS_RESALE: float = 0.70            # venda de um bem fora da fuga

# ---------------------------------------------------------
# Carteira: cripto e fundos
# ---------------------------------------------------------
const CRYPTO_START_PRICE: float = 180000.0
const CRYPTO_FEE: float = 0.025
const CRYPTO_DRIFT: float = 0.003           # tendência diária
const CRYPTO_SWING: float = 0.06            # oscilação diária máxima (para cima ou para baixo)

## yield: rendimento médio por dia   swing: oscilação do rendimento
## exposed: pode ser congelado pela Interpol
const FUNDS: Array = [
	{"id": "titulos", "name": "Títulos privados", "act": 2, "yield": 0.003, "swing": 0.0, "exposed": false, "about": "Rendimento baixo e previsível."},
	{"id": "global", "name": "Mercado global", "act": 2, "yield": 0.005, "swing": 0.012, "exposed": false, "about": "Rende mais na média, mas oscila todo dia."},
	{"id": "offshore", "name": "Fundo offshore", "act": 3, "yield": 0.008, "swing": 0.004, "exposed": true, "about": "O melhor rendimento. Fica na mira da Interpol."}
]
const FUND_FEE: float = 0.015

# ---------------------------------------------------------
# Ações de controle de risco
# ---------------------------------------------------------
## cost é multiplicado pela escala do ato. cooldown em dias.
const RISK_ACTIONS: Array = [
	{"id": "revisao", "name": "Revisão de contratos", "reduce": 4.0, "cost": 9000.0, "cooldown": 2, "act": 1, "about": "Arruma a papelada das empresas."},
	{"id": "auditoria", "name": "Auditoria interna", "reduce": 6.0, "cost": 14000.0, "cooldown": 3, "act": 1, "about": "Fecha os furos antes que alguém de fora ache."},
	{"id": "consultoria", "name": "Consultoria de compliance", "reduce": 8.0, "cost": 18000.0, "cooldown": 4, "act": 1, "about": "Um selo de boa conduta comprado a preço de ouro."},
	{"id": "doacao", "name": "Doação eleitoral", "reduce": 5.0, "cost": 60000.0, "cooldown": 3, "act": 2, "influence": 1, "about": "Reduz a suspeita e rende 1 ponto de influência política."},
	{"id": "varredura", "name": "Varredura eletrônica", "reduce": 0.0, "cost": 25000.0, "cooldown": 0, "act": 2, "clears_wiretap": true, "about": "Remove um grampo telefônico ativo."},
	{"id": "banca", "name": "Banca internacional", "reduce": 7.0, "cost": 22000.0, "cooldown": 4, "act": 3, "about": "Advogados em três fusos horários."}
]

const INFLUENCE_MAX: int = 10
const INFLUENCE_DECAY: float = 0.4          # suspeita extra que cai por noite, por ponto
const IMMUNITY_INFLUENCE: int = 5           # influência exigida para a imunidade parlamentar
const IMMUNITY_COST: float = 6000000.0

const WIRETAP_DAYS: int = 6
const WIRETAP_RISK: float = 0.5             # +50% de suspeita por operação

# ---------------------------------------------------------
# Operação Fuga
# ---------------------------------------------------------
const ESCAPE_HOURS: float = 72.0
const ESCAPE_COMPANY_SALE: float = 0.60
const ESCAPE_GOODS_SALE: float = 0.55
const ESCAPE_MONERO_FEE: float = 0.08
const ESCAPE_BATCH_SHARE: float = 0.25      # cada lote converte até 25% do patrimônio inicial da fuga
const ESCAPE_HOURS_COMPANY: float = 5.0
const ESCAPE_HOURS_GOOD: float = 3.0
const ESCAPE_HOURS_WALLET: float = 2.0
const ESCAPE_HOURS_CONVERT: float = 4.0
const ESCAPE_HOURS_PASSPORT: float = 6.0
const ESCAPE_HOURS_JET: float = 6.0
const ESCAPE_DAILY_SUSPICION: float = 6.0   # a cada 24 h de fuga, o cerco fecha
## Chance de interceptação = suspeita * SUSPICION + horas gastas * HOUR
##                           + MANDADO (se houver) - bônus do passaporte - bônus do jato
const ESCAPE_CHANCE_SUSPICION: float = 0.7
const ESCAPE_CHANCE_HOUR: float = 0.25
const ESCAPE_CHANCE_MANDADO: float = 15.0
const ESCAPE_CHANCE_MIN: float = 4.0
const ESCAPE_CHANCE_MAX: float = 92.0
## cost é multiplicado pela escala do ato.
const PASSPORTS: Array = [
	{"id": "comum", "name": "Passaporte falso comum", "cost": 40000.0, "bonus": 0.0, "about": "Passa em fronteira distraída."},
	{"id": "bom", "name": "Passaporte de 2ª nacionalidade", "cost": 150000.0, "bonus": 12.0, "about": "Documento verdadeiro, história inventada."},
	{"id": "diplomatico", "name": "Passaporte diplomático", "cost": 500000.0, "bonus": 28.0, "about": "Ninguém revista mala diplomática."}
]
const JETS: Array = [
	{"id": "turbo", "name": "Turboélice fretado", "cost": 100000.0, "bonus": 0.0, "about": "Lento, barulhento e fácil de seguir."},
	{"id": "executivo", "name": "Jato executivo", "cost": 350000.0, "bonus": 10.0, "about": "Decola de pista curta, sem plano de voo."},
	{"id": "fantasma", "name": "Jato com transponder clonado", "cost": 900000.0, "bonus": 24.0, "about": "No radar, é um voo comercial qualquer."}
]

# ---------------------------------------------------------
# Finais
# ---------------------------------------------------------
const ENDINGS: Dictionary = {
	"rei": {"title": "O Rei do Offshore", "short": "Rei do Offshore", "kind": "Vitória perfeita", "win": true, "text": "Você bateu as três metas, converteu o patrimônio e pousou em Mônaco sem nenhum mandado no seu nome."},
	"foragido": {"title": "Foragido", "short": "Foragido", "kind": "Vitória amarga", "win": true, "text": "Você saiu do país, mas com um mandado de prisão no encalço. O dinheiro foi junto. A paz, não."},
	"politico": {"title": "O Político Influente", "short": "Político", "kind": "Vitória neutra", "win": true, "text": "Você comprou imunidade parlamentar e se elegeu Deputado Federal. O esquema continua, agora com foro privilegiado."},
	"preso": {"title": "Preso na Operação Lava-Jato", "short": "Preso", "kind": "Derrota jurídica", "win": false, "text": "A Polícia Federal bateu à porta às seis da manhã."},
	"queima": {"title": "Queima de Arquivo", "short": "Queima de Arquivo", "kind": "Derrota crítica", "win": false, "text": "Você sabia demais e chamou atenção demais. O cartel resolveu o problema."}
}
const ENDING_ORDER: Array = ["rei", "foragido", "politico", "preso", "queima"]

# ---------------------------------------------------------
# Notícias de ambiente (efeitos temporários)
# ---------------------------------------------------------
## stat: "capacity", "loss" ou "risk" (somado como percentual) ou "suspicion" (pontos, na hora)
## target: id de uma empresa ou "*" para todas
const NEWS: Array = [
	{"tag": "URGENTE", "title": "Fiscalização amplia monitoramento de movimentações atípicas", "body": "Uma força-tarefa passou a cruzar dados de pequenos comércios com movimentação acima da média do setor.", "stat": "suspicion", "target": "*", "value": 3.0, "days": 0, "effect": "+3.0 de suspeita"},
	{"tag": "MERCADO", "title": "Movimento noturno cresce e lota casas de entretenimento", "body": "Com mais gente na rua, o caixa das casas noturnas sobe e um volume maior passa despercebido.", "stat": "capacity", "target": "bar", "value": 0.15, "days": 3, "effect": "Bar Oasis +15% de capacidade por 3 dias"},
	{"tag": "BANCO", "title": "Nova rotina de compliance afeta contas de passagem", "body": "Os bancos passaram a pedir mais documentos para depósitos em espécie, o que encarece cada operação.", "stat": "loss", "target": "*", "value": 0.02, "days": 3, "effect": "Custo de todas as empresas +2 pontos por 3 dias"},
	{"tag": "ECONOMIA", "title": "Crédito farto aquece o comércio de bairro", "body": "Com o consumo em alta, lavanderias e pequenos serviços faturam mais, e ninguém estranha o caixa cheio.", "stat": "capacity", "target": "lavanderia", "value": 0.20, "days": 3, "effect": "Lavanderia +20% de capacidade por 3 dias"},
	{"tag": "POLÍTICA", "title": "CPI muda de assunto e esvazia investigação financeira", "body": "O escândalo da semana tirou os holofotes do sistema financeiro. Por alguns dias, ninguém está olhando.", "stat": "risk", "target": "*", "value": -0.20, "days": 3, "effect": "Operações geram 20% menos suspeita por 3 dias"},
	{"tag": "URGENTE", "title": "Operação policial fecha o cerco a empresas de fachada", "body": "Mandados de busca foram cumpridos em três capitais. Empresários do setor de serviços estão entre os alvos.", "stat": "risk", "target": "*", "value": 0.25, "days": 3, "effect": "Operações geram 25% mais suspeita por 3 dias"},
	{"tag": "ECONOMIA", "title": "Setor automotivo registra alta de liquidez", "body": "As vendas de veículos à vista dispararam, e as concessionárias giram mais dinheiro do que o normal.", "stat": "capacity", "target": "concessionaria", "value": 0.15, "days": 3, "effect": "Concessionária +15% de capacidade por 3 dias", "act": 2},
	{"tag": "MERCADO", "title": "Leilão bate recorde e aquece o mercado de arte", "body": "Colecionadores disputaram lances por telefone. Preços altos e compradores anônimos viraram rotina.", "stat": "capacity", "target": "galeria", "value": 0.20, "days": 3, "effect": "Galeria +20% de capacidade por 3 dias", "act": 3}
]
const NEWS_CHANCE: float = 0.30

# ---------------------------------------------------------
# Ameaças por ato (chance diária = base + (suspeita - from) / slope, se positiva)
# ---------------------------------------------------------
const THREAT_COOLDOWN: int = 3
const THREATS: Dictionary = {
	"fiscalizacao": {"act": 1, "base": 0.07, "from": 30.0, "slope": 250.0},
	"intimacao": {"act": 2, "base": 0.05, "from": 40.0, "slope": 200.0},
	"grampo": {"act": 2, "base": 0.06, "from": 35.0, "slope": 0.0},
	"aliado": {"act": 2, "base": 0.03, "from": 0.0, "slope": 0.0},
	"interpol": {"act": 3, "base": 0.05, "from": 40.0, "slope": 250.0}
}
const CARTEL_WARNING_LEVEL: float = 75.0

# ---------------------------------------------------------
# Funções de apoio
# ---------------------------------------------------------
static func act_data(act: int) -> Dictionary:
	return ACTS[clampi(act, 1, ACTS.size()) - 1]

static func good_data(good_id: String) -> Dictionary:
	for good_v: Variant in GOODS:
		var good: Dictionary = good_v as Dictionary
		if str(good["id"]) == good_id:
			return good
	return {}

static func fund_data(fund_id: String) -> Dictionary:
	for fund_v: Variant in FUNDS:
		var fund: Dictionary = fund_v as Dictionary
		if str(fund["id"]) == fund_id:
			return fund
	return {}

static func risk_action(action_id: String) -> Dictionary:
	for action_v: Variant in RISK_ACTIONS:
		var action: Dictionary = action_v as Dictionary
		if str(action["id"]) == action_id:
			return action
	return {}

static func tier_item(list: Array, item_id: String) -> Dictionary:
	for item_v: Variant in list:
		var item: Dictionary = item_v as Dictionary
		if str(item["id"]) == item_id:
			return item
	return {}
