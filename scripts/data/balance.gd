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
## Um turno é um dia de operação. Os prazos são curtos de propósito: o ato termina
## assim que a meta é batida, e o prazo existe para pressionar, não para fazer
## o jogador esperar.
##
## goal      meta de PATRIMÔNIO (saldo limpo + bens + empresas + carteira)
## days      prazo do ato, em turnos
## remessa   dinheiro sujo que o cliente entrega por turno
## bonus     adiantamento em saldo limpo que o cliente paga ao promover você
## scale     multiplicador de custos (ações de risco, multas, propinas, fuga)
## limit     suspeita que encerra o jogo naquele ato
## decay     fração da suspeita que some sozinha a cada noite (0.10 = 10%)
## identity  o que muda no jogo neste ato (aparece na abertura do ato)
const ACTS: Array = [
	{
		"id": 1,
		"name": "O Pequeno Operador",
		"focus": "Lavagem básica em pequenos negócios locais.",
		"threat": "Receita Federal",
		"threat_text": "Fiscalizações de rotina e malha fina.",
		"goal": 900000.0,
		"days": 7,
		"remessa": 220000.0,
		"bonus": 0.0,
		"scale": 1.0,
		"limit": 100.0,
		"decay": 0.10,
		"identity": "Recursos curtos: escolha onde lavar, quem contratar e quanto arriscar.",
		"unlocks": ["Lavanderia e bar já são seus.", "Laranjas aumentam a capacidade das empresas.", "Objetivos do ato ensinam o básico e pagam bônus.", "Bens de luxo dão prestígio, mas chamam a Receita."]
	},
	{
		"id": 2,
		"name": "O Consultor Político e Corporativo",
		"focus": "Contratos públicos, doações eleitorais e negócios maiores.",
		"threat": "Polícia Federal",
		"threat_text": "Investigações, grampos telefônicos e delações.",
		"goal": 4000000.0,
		"days": 8,
		"remessa": 1300000.0,
		"bonus": 300000.0,
		"scale": 5.0,
		"limit": 100.0,
		"decay": 0.10,
		"identity": "Política e gente: influência abre portas, operadores querem mais, a PF escuta.",
		"unlocks": ["Boate, concessionária e construtora à venda.", "Operadores: laranjas de capacidade maior.", "Doações eleitorais geram influência política.", "Fundos de investimento na aba Carteira.", "Suspeita acima de 80% por 3 turnos gera mandado de prisão."]
	},
	{
		"id": 3,
		"name": "O Sindicato Global e Offshores",
		"focus": "Criptomoedas, paraísos fiscais e obras de arte.",
		"threat": "Interpol e o cartel",
		"threat_text": "A Interpol não esquece: a suspeita cai mais devagar. Acima de 90%, o cartel queima o arquivo.",
		"goal": 15000000.0,
		"days": 9,
		"remessa": 4000000.0,
		"bonus": 1500000.0,
		"scale": 12.0,
		"limit": 90.0,
		"decay": 0.08,
		"identity": "Escala e saída: patrimônio no exterior, crises internacionais e a preparação da fuga.",
		"unlocks": ["Galeria de arte e trading offshore à venda.", "Doleiros: o nível mais alto de operador.", "Fundo offshore na aba Carteira.", "Preparar a saída reduz a chance de interceptação.", "O limite de suspeita cai para 90%.", "Bater a meta inicia a Operação Fuga."]
	}
]

const DEADLINE_EXTENSION_DAYS: int = 2      # prorrogação única por ato
const DEADLINE_PENALTY: float = 0.20        # fatia do saldo limpo cobrada pelo atraso

## Personalidade dos laranjas: cada um tem um traço que muda como ele reage
## à pressão. O traço é fixo por pessoa (sai do id, não do sorteio), aparece no
## cartão e no quadro de pessoal.
##   stress     multiplica o quanto o estresse sobe nas noites tensas
##   capacity   multiplica a capacidade na contratação
##   cost       multiplica a diária na contratação
##   bonus      multiplica o efeito do agrado
##   leak       suspeita somada toda noite (gente que fala demais)
const STAFF_TRAITS: Dictionary = {
	"leal": {"name": "Leal", "about": "Segura a pressão: o estresse sobe 25% mais devagar.", "stress": 0.75, "capacity": 1.0, "cost": 1.0, "bonus": 1.0, "leak": 0.0},
	"nervoso": {"name": "Nervoso", "about": "Trabalha muito e dorme pouco: +6% de capacidade, estresse 15% mais rápido.", "stress": 1.15, "capacity": 1.06, "cost": 1.0, "bonus": 1.0, "leak": 0.0},
	"ganancioso": {"name": "Ganancioso", "about": "Só se acalma com dinheiro: diária 5% maior, agrado vale quase o dobro.", "stress": 1.0, "capacity": 1.0, "cost": 1.05, "bonus": 1.8, "leak": 0.0},
	"falastrao": {"name": "Falastrão", "about": "Barato e simpático, mas fala demais no bar: diária 12% menor, um pouco de suspeita toda noite.", "stress": 1.0, "capacity": 1.0, "cost": 0.88, "bonus": 1.0, "leak": 0.08},
}
const STAFF_TRAIT_ORDER: Array = ["leal", "nervoso", "ganancioso", "falastrao"]

## Mandado de prisão (atos 2 e 3): suspeita no fim do dia >= MANDADO_LEVEL por
## MANDADO_DAYS turnos seguidos.
const MANDADO_LEVEL: float = 80.0
const MANDADO_DAYS: int = 3

# ---------------------------------------------------------
# Empresas de fachada
# ---------------------------------------------------------
## capacity  quanto a empresa processa por TURNO (sem laranjas)
## loss      fatia perdida na operação
## risk      pontos de suspeita gerados ao usar 100% da capacidade do dia
## act       ato em que fica disponível      price  preço de compra (0 = já é sua)
## value     valor contábil (entra no patrimônio e é a base da venda na fuga)
## prestige  nível de prestígio exigido      slots  vagas para laranjas
const COMPANIES: Dictionary = {
	"lavanderia": {
		"name": "Lavanderia Pura Vida", "tag": "Varejo / Serviços",
		"capacity": 40000.0, "loss": 0.12, "risk": 4.5, "reputation": 72,
		"act": 1, "price": 0.0, "value": 80000.0, "prestige": 0, "slots": 2,
		"description": "Operação de giro rápido, com capacidade pequena e risco controlável."
	},
	"bar": {
		"name": "Bar Oasis", "tag": "Entretenimento",
		"capacity": 60000.0, "loss": 0.16, "risk": 7.0, "reputation": 64,
		"act": 1, "price": 0.0, "value": 120000.0, "prestige": 0, "slots": 2,
		"description": "Alta circulação de dinheiro vivo e mais exposição a fiscalização."
	},
	"boate": {
		"name": "Boate Necturne", "tag": "Vida Noturna",
		"capacity": 220000.0, "loss": 0.20, "risk": 9.0, "reputation": 51,
		"act": 2, "price": 450000.0, "value": 450000.0, "prestige": 0, "slots": 2,
		"description": "Caixa alto todas as noites. O custo é pesado e a fiscalização fica de olho."
	},
	"concessionaria": {
		"name": "Concessionária Nova", "tag": "Automotivo",
		"capacity": 320000.0, "loss": 0.18, "risk": 10.0, "reputation": 58,
		"act": 2, "price": 700000.0, "value": 700000.0, "prestige": 0, "slots": 2,
		"description": "Movimentações grandes e espaçadas. Exige gestão de risco."
	},
	"construtora": {
		"name": "Construtora Horizonte", "tag": "Contratos Públicos",
		"capacity": 650000.0, "loss": 0.14, "risk": 11.0, "reputation": 60,
		"act": 2, "price": 1500000.0, "value": 1500000.0, "prestige": 2, "slots": 3,
		"description": "Obras públicas superfaturadas. Só abre as portas para quem tem nome na praça."
	},
	"galeria": {
		"name": "Galeria Meridiano", "tag": "Arte e Leilões",
		"capacity": 1400000.0, "loss": 0.10, "risk": 12.0, "reputation": 77,
		"act": 3, "price": 4000000.0, "value": 4000000.0, "prestige": 3, "slots": 3,
		"description": "O preço de uma obra é o que alguém aceita pagar. Margem ótima, clientela discreta."
	},
	"trading": {
		"name": "Atlântica Trading", "tag": "Offshore",
		"capacity": 2600000.0, "loss": 0.08, "risk": 16.0, "reputation": 69,
		"act": 3, "price": 8000000.0, "value": 8000000.0, "prestige": 4, "slots": 3,
		"description": "Importação e exportação entre paraísos fiscais. O maior volume e o maior holofote."
	}
}

const COMPANY_ORDER: Array = ["lavanderia", "bar", "boate", "concessionaria", "construtora", "galeria", "trading"]

# ---------------------------------------------------------
# Laranjas e operadores
# ---------------------------------------------------------
## capacity e cost são faixas [mínimo, máximo] sorteadas para cada candidato.
const STAFF_TIERS: Array = [
	{"tier": 1, "title": "Laranja", "act": 1, "capacity": [30000.0, 50000.0], "cost": [1500.0, 2600.0]},
	{"tier": 2, "title": "Operador", "act": 2, "capacity": [140000.0, 220000.0], "cost": [9000.0, 15000.0]},
	{"tier": 3, "title": "Doleiro", "act": 3, "capacity": [350000.0, 600000.0], "cost": [26000.0, 42000.0]}
]
const STAFF_HIRE_DAYS: float = 3.0          # taxa de contratação = 3 diárias
const STAFF_CANDIDATES: int = 3
const STAFF_STRESS_LEVEL: float = 50.0      # suspeita a partir da qual o estresse sobe
const STAFF_STRESS_BASE: float = 6.0
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
	{"id": "relogio_colecao", "cat": "Relógios", "name": "Relógio de colecionador", "price": 250000.0, "prestige": 10, "act": 2, "weight": 0.6},
	{"id": "lancha", "cat": "Iates", "name": "Lancha esportiva", "price": 600000.0, "prestige": 14, "act": 2, "weight": 1.2},
	{"id": "esportivo", "cat": "Carros", "name": "Esportivo italiano", "price": 1200000.0, "prestige": 26, "act": 2, "weight": 1.0},
	{"id": "tela", "cat": "Arte", "name": "Tela modernista", "price": 1800000.0, "prestige": 34, "act": 2, "weight": 0.4},
	{"id": "mansao", "cat": "Imóveis", "name": "Mansão no litoral", "price": 3500000.0, "prestige": 50, "act": 2, "weight": 0.8},
	{"id": "iate", "cat": "Iates", "name": "Iate de 40 metros", "price": 4500000.0, "prestige": 60, "act": 3, "weight": 1.2},
	{"id": "hipercarro", "cat": "Carros", "name": "Hipercarro de série limitada", "price": 7000000.0, "prestige": 70, "act": 3, "weight": 1.0},
	{"id": "obra_prima", "cat": "Arte", "name": "Obra-prima de leilão", "price": 11000000.0, "prestige": 95, "act": 3, "weight": 0.4},
	{"id": "villa", "cat": "Imóveis", "name": "Villa na Riviera", "price": 18000000.0, "prestige": 110, "act": 3, "weight": 0.8}
]

## Pontos de prestígio para cada nível e o nome do nível.
const PRESTIGE_TIERS: Array = [8, 25, 60, 120]
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
const CRYPTO_DRIFT: float = 0.008           # tendência por turno
const CRYPTO_SWING: float = 0.09            # oscilação máxima por turno (para cima ou para baixo)

## yield: rendimento médio por turno   swing: oscilação do rendimento
## exposed: pode ser congelado pela Interpol
const FUNDS: Array = [
	{"id": "titulos", "name": "Títulos privados", "act": 2, "yield": 0.008, "swing": 0.0, "exposed": false, "about": "Rendimento baixo e previsível."},
	{"id": "global", "name": "Mercado global", "act": 2, "yield": 0.013, "swing": 0.03, "exposed": false, "about": "Rende mais na média, mas oscila a cada turno."},
	{"id": "offshore", "name": "Fundo offshore", "act": 3, "yield": 0.02, "swing": 0.01, "exposed": true, "about": "O melhor rendimento. Fica na mira da Interpol."}
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
const IMMUNITY_COST: float = 3000000.0

const WIRETAP_DAYS: int = 4
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
	{"tag": "MERCADO", "title": "Movimento noturno cresce e lota casas de entretenimento", "body": "Com mais gente na rua, o caixa das casas noturnas sobe e um volume maior passa despercebido.", "stat": "capacity", "target": "bar", "value": 0.15, "days": 3, "effect": "Bar Oasis +15% de capacidade por 3 turnos"},
	{"tag": "BANCO", "title": "Nova rotina de compliance afeta contas de passagem", "body": "Os bancos passaram a pedir mais documentos para depósitos em espécie, o que encarece cada operação.", "stat": "loss", "target": "*", "value": 0.02, "days": 3, "effect": "Custo de todas as empresas +2 pontos por 3 turnos"},
	{"tag": "ECONOMIA", "title": "Crédito farto aquece o comércio de bairro", "body": "Com o consumo em alta, lavanderias e pequenos serviços faturam mais, e ninguém estranha o caixa cheio.", "stat": "capacity", "target": "lavanderia", "value": 0.20, "days": 3, "effect": "Lavanderia +20% de capacidade por 3 turnos"},
	{"tag": "POLÍTICA", "title": "CPI muda de assunto e esvazia investigação financeira", "body": "O escândalo da semana tirou os holofotes do sistema financeiro. Por alguns dias, ninguém está olhando.", "stat": "risk", "target": "*", "value": -0.20, "days": 3, "effect": "Operações geram 20% menos suspeita por 3 turnos"},
	{"tag": "URGENTE", "title": "Operação policial fecha o cerco a empresas de fachada", "body": "Mandados de busca foram cumpridos em três capitais. Empresários do setor de serviços estão entre os alvos.", "stat": "risk", "target": "*", "value": 0.25, "days": 3, "effect": "Operações geram 25% mais suspeita por 3 turnos"},
	{"tag": "ECONOMIA", "title": "Setor automotivo registra alta de liquidez", "body": "As vendas de veículos à vista dispararam, e as concessionárias giram mais dinheiro do que o normal.", "stat": "capacity", "target": "concessionaria", "value": 0.15, "days": 3, "effect": "Concessionária +15% de capacidade por 3 turnos", "act": 2},
	{"tag": "MERCADO", "title": "Leilão bate recorde e aquece o mercado de arte", "body": "Colecionadores disputaram lances por telefone. Preços altos e compradores anônimos viraram rotina.", "stat": "capacity", "target": "galeria", "value": 0.20, "days": 3, "effect": "Galeria +20% de capacidade por 3 turnos", "act": 3}
]
const NEWS_CHANCE: float = 0.35

# ---------------------------------------------------------
# Ameaças por ato (chance diária = base + (suspeita - from) / slope, se positiva)
# ---------------------------------------------------------
const THREAT_COOLDOWN: int = 2
const THREATS: Dictionary = {
	"fiscalizacao": {"act": 1, "base": 0.12, "from": 30.0, "slope": 200.0},
	"intimacao": {"act": 2, "base": 0.08, "from": 40.0, "slope": 160.0},
	"grampo": {"act": 2, "base": 0.08, "from": 35.0, "slope": 0.0},
	"aliado": {"act": 2, "base": 0.05, "from": 0.0, "slope": 0.0},
	"interpol": {"act": 3, "base": 0.08, "from": 40.0, "slope": 200.0}
}
const CARTEL_WARNING_LEVEL: float = 75.0

# ---------------------------------------------------------
# Ritmo dos acontecimentos (Director) e contratos
# ---------------------------------------------------------
## Chance de um acontecimento numa noite = BASE + QUIET_BONUS x noites tranquilas
## seguidas. Com estes valores, algo relevante aparece a cada 1 ou 2 turnos.
const DIRECTOR_BASE_CHANCE: float = 0.45
const DIRECTOR_QUIET_BONUS: float = 0.35
const DIRECTOR_MAX_POPUPS: int = 2          # decisões por noite, no máximo
const DIRECTOR_RARE_CHANCE: float = 0.08    # parte dos sorteios que vira evento raro
const DIRECTOR_EVENT_COOLDOWN: int = 4      # turnos até o mesmo acontecimento voltar
const DIRECTOR_RARE_COOLDOWN: int = 12
const EXPANSION_DISCOUNT: float = 0.70      # empresa oferecida com 30% de desconto
const CONTRACT_INTERVAL: int = 2            # turnos entre ofertas de contrato
const CONTRACT_OFFER_DAYS: int = 2          # turnos que uma oferta fica disponível
const EARLY_UNLOCK_PRICE: float = 0.75      # empresa liberada antes do ato por um objetivo

# ---------------------------------------------------------
# Mundo 3D: malotes, batida, grampos e minigames
# ---------------------------------------------------------
## Quantos malotes aparecem no quarto no máximo, e a fatia da remessa por malote.
const CASES_MAX: int = 8
const CASE_SHARE: float = 0.25

## Batida na porta: ao acordar, com a suspeita acima de RAID_MIN_SUSPICION, pode
## haver uma batida. O jogador tem RAID_SECONDS para guardar os malotes no cofre.
const RAID_MIN_SUSPICION: float = 40.0
const RAID_CHANCE_SLOPE: float = 0.007      # chance = (suspeita - mínimo) x slope
const RAID_CHANCE_MAX: float = 0.40
const RAID_SECONDS: float = 22.0
const RAID_COOLDOWN_DAYS: int = 3
const RAID_MIN_DIRTY: float = 50000.0       # sem dinheiro sujo à vista, não há batida
const RAID_SEIZE: float = 0.15              # fatia do saldo sujo apreendida se falhar
const RAID_FAIL_SUSPICION: float = 4.0
const RAID_WIN_SUSPICION: float = -2.0

## Grampos físicos: cada um precisa ser achado no quarto e removido.
const BUGS_COUNT: int = 3

## Minigames (um de cada por turno).
const HACK_SUSPICION_BASE: float = 2.0      # redução mínima de suspeita
const HACK_SUSPICION_BONUS: float = 5.0     # a mais, proporcional ao desempenho
const HACK_MINUTES: int = 30
const SHRED_RISK_PER_HIT: float = 0.08      # menos suspeita por operação, por acerto
const SHRED_DAYS: int = 2
const SHRED_MINUTES: int = 20

# ---------------------------------------------------------
# Troca de turno
# ---------------------------------------------------------
## Duração da cena da noite, em segundos. A completa roda na primeira noite, ao
## mudar de ato ou quando o jogador pede nas Configurações.
const NIGHT_SHORT: float = 3.2
const NIGHT_FULL: float = 7.2
const NIGHT_REDUCED: float = 1.4

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
