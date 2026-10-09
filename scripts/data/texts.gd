extends RefCounted
## TEXTOS — tudo o que o jogo explica ao jogador.
##
## HELP alimenta o botão "Como funciona" de cada aba (e a tecla F1).
## MANUAL são as páginas do Manual do Consultor.
## Os números entre chaves, como {tax}, vêm do balanceamento: se você mudar
## um valor em balance.gd, o texto acompanha sozinho (veja fill()).

const B = preload("res://scripts/data/balance.gd")

## [rótulo, id, ícone]. A Dark Web só aparece na Operação Fuga.
const TABS: Array = [
	["VISÃO GERAL", "overview", "overview"],
	["EMPRESAS", "companies", "companies"],
	["LARANJAS", "staff", "staff"],
	["BENS", "lifestyle", "lifestyle"],
	["CARTEIRA", "wallet", "wallet"],
	["TRANSAÇÕES", "transactions", "transactions"],
	["NOTÍCIAS", "news", "news"],
	["RISCO", "risk", "risk"],
	["DARK WEB", "darkweb", "darkweb"]
]
## Abas disponíveis durante a fuga.
const ESCAPE_TABS: Array = ["darkweb", "overview", "news", "risk"]

const HELP: Dictionary = {
	"overview": {
		"title": "VISÃO GERAL",
		"subtitle": "A situação do turno antes de você agir.",
		"lead": "Este painel resume a campanha: o que falta processar, o que já é seu, o quanto falta para a meta do ato e o quão perto você está de ser descoberto.",
		"terms": [
			["Saldo sujo", "O dinheiro que o cliente entrega toda noite. Precisa passar pelas empresas para virar saldo limpo."],
			["Saldo limpo", "O que você pode gastar: laranjas, empresas, bens, ações de risco."],
			["Patrimônio", "Saldo limpo + empresas + bens + carteira. É ele que conta para a meta do ato."],
			["Suspeita", "Sobe a cada operação e perde {decay}% do valor a cada noite ({decay3}% no Ato 3). No limite do ato, a campanha acaba."]
		],
		"how": [
			"Leia o topo da tela: dia, caixa, suspeita e patrimônio ficam visíveis em todas as abas.",
			"Siga o próximo passo sugerido no rodapé ou escolha uma aba no menu.",
			"Quando terminar o que queria fazer no dia, clique em Finalizar turno."
		]
	},
	"companies": {
		"title": "EMPRESAS DE FACHADA",
		"subtitle": "Onde o saldo sujo vira saldo limpo.",
		"lead": "Cada empresa processa um valor por dia. Elas diferem em capacidade, custo e risco, e escolher quais usar, e quanto, é o centro do jogo.",
		"terms": [
			["Capacidade de hoje", "Quanto a empresa ainda aceita processar neste dia. Volta ao total toda manhã. Laranjas aumentam o total."],
			["Custo", "A parte que se perde. Com custo de 12%, de R$ 10.000 chegam R$ 8.800 ao saldo limpo. O prestígio reduz o custo."],
			["Risco no teto", "Pontos de suspeita gerados se você usar 100% da capacidade do dia. Usar metade gera metade."],
			["Empresas à venda", "Negócios maiores aparecem a cada ato. Alguns exigem um nível de prestígio para abrir as portas."]
		],
		"how": [
			"Clique em Operar na empresa escolhida.",
			"Defina o valor, digitando ou usando os atalhos de 25%, 50% e Máx.",
			"Confira a prévia do que entra limpo e da suspeita gerada, e execute."
		]
	},
	"staff": {
		"title": "LARANJAS E OPERADORES",
		"subtitle": "Gente que empresta o nome para a operação crescer.",
		"lead": "Um laranja soma capacidade à empresa em que trabalha, sem aumentar o risco no teto. Em troca, cobra uma diária e pode quebrar sob pressão.",
		"terms": [
			["Capacidade", "Quanto ele acrescenta, por dia, à empresa em que foi alocado."],
			["Diária", "Custo por noite. Sai do saldo limpo; se faltar, do sujo. Sem pagamento, o estresse dispara."],
			["Lealdade", "Quanto maior, mais devagar o estresse sobe."],
			["Estresse", "Com a suspeita acima de {stress_level}%, sobe toda noite. Abaixo disso, alivia. Um agrado baixa o estresse na hora."],
			["Delação premiada", "Com estresse 100, o laranja procura a Polícia Federal. Você tem {delation_days} noites para intervir, ou a campanha termina com você preso."]
		],
		"how": [
			"Escolha um candidato do dia e clique em Contratar.",
			"Aloque na empresa em que a capacidade extra rende mais.",
			"Vigie o estresse. Em uma delação, as saídas são pagar o silêncio, exilar (pago em cripto) ou descartar."
		]
	},
	"lifestyle": {
		"title": "BENS E ESTILO DE VIDA",
		"subtitle": "O que fazer com o saldo limpo, e o preço de aparecer.",
		"lead": "Bens de luxo rendem prestígio e continuam valendo como patrimônio. O problema é a ostentação: patrimônio à vista sem renda declarada chama a Receita Federal.",
		"terms": [
			["Prestígio", "Cada nível reduz o custo de todas as empresas e abre negócios maiores no ato seguinte."],
			["Ostentação", "O quanto os seus bens aparecem. Um iate aparece mais que um quadro guardado em casa."],
			["Renda declarada", "Você paga {tax}% de imposto sobre o que declara. A renda declarada justifica metade do seu valor em ostentação."],
			["Malha fina", "Se a ostentação passar do que a renda justifica, toda noite há uma chance de auditoria. As saídas são multa, confisco ou contestação."]
		],
		"how": [
			"Compre um bem. Veja o efeito no prestígio e na ostentação.",
			"Se a barra de ostentação passar da cobertura, declare renda ou aceite o risco.",
			"Um bem pode ser vendido a qualquer momento, com deságio."
		]
	},
	"wallet": {
		"title": "CARTEIRA",
		"subtitle": "Cripto e fundos: patrimônio que não aparece na garagem.",
		"lead": "O que está na carteira conta para a meta do ato, mas não gera ostentação. Cripto oscila todo dia e paga o exílio de laranjas. Fundos rendem por noite.",
		"terms": [
			["Cripto", "Compra e venda com taxa. O preço muda toda noite, para cima ou para baixo."],
			["Fundos", "Aplicações que rendem por noite. Abrem no Ato 2; o offshore, no Ato 3."],
			["Exposição", "No Ato 3, uma auditoria da Interpol pode congelar parte da cripto e do fundo offshore."]
		],
		"how": [
			"Clique em Comprar ou Aplicar e informe o valor.",
			"Mantenha alguma cripto: é a única forma de pagar um exílio."
		]
	},
	"transactions": {
		"title": "HISTÓRICO DE TRANSAÇÕES",
		"subtitle": "Tudo o que você já processou.",
		"lead": "Cada operação fica registrada aqui. Use o histórico para ver quais empresas renderam mais e quais custaram mais suspeita.",
		"terms": [
			["Valor", "Quanto saiu do saldo sujo naquela operação."],
			["Custo", "Quanto ficou pelo caminho."],
			["Impacto", "Quanto a suspeita subiu por causa dela."]
		],
		"how": []
	},
	"news": {
		"title": "CENTRAL DE NOTÍCIAS",
		"subtitle": "O que mudou no ambiente, e por quanto tempo.",
		"lead": "Notícias mexem de verdade no jogo: aumentam a capacidade de uma empresa, encarecem as operações ou elevam a suspeita por alguns dias.",
		"terms": [
			["Efeitos ativos", "O que está valendo agora e por quantos dias ainda."],
			["Histórico", "Tudo o que já aconteceu na campanha, do mais recente ao mais antigo."]
		],
		"how": [
			"Confira os efeitos ativos antes de decidir onde operar.",
			"Clique em Abrir para reler uma notícia."
		]
	},
	"risk": {
		"title": "RISCO / SUSPEITA",
		"subtitle": "A condição de derrota, sempre à vista.",
		"lead": "A suspeita mede o quanto a operação chama atenção. Sobe com operações e eventos, perde {decay}% do valor a cada noite ({decay3}% no Ato 3) e pode ser reduzida com ações pagas. Quanto mais alta, mais ela cai sozinha: operar no limite rende mais, e qualquer susto custa caro.",
		"terms": [
			["Limite do ato", "100% nos atos 1 e 2. No Ato 3, o cartel age aos 90%."],
			["Mandado de prisão", "Nos atos 2 e 3, {mandado_days} noites seguidas com a suspeita acima de {mandado_level}% geram um mandado e iniciam a fuga antes da hora."],
			["Ações de controle", "Reduzem a suspeita, custam saldo limpo e têm dias de espera entre um uso e outro."],
			["Influência", "A partir do Ato 2, doações eleitorais rendem influência. Cada ponto faz a suspeita cair mais rápido toda noite."]
		],
		"how": [
			"Compare o custo por ponto das ações disponíveis.",
			"Use as ações antes de a suspeita passar de {stress_level}%: é aí que os laranjas começam a se estressar."
		]
	},
	"darkweb": {
		"title": "DARK WEB / OPERAÇÃO FUGA",
		"subtitle": "Você tem {escape_hours} horas. Cada ação gasta tempo.",
		"lead": "A fuga não tem noites: é um orçamento de horas. Só o Monero sai do país com você. Quanto mais tempo você fica liquidando e convertendo, mais leva e maior a chance de ser interceptado.",
		"terms": [
			["Liquidar", "Vender empresas, bens e carteira transforma patrimônio em saldo limpo, com deságio."],
			["Monero", "Converta o saldo limpo em lotes. É o único dinheiro que embarca."],
			["Passaporte e avião", "Sem os dois, não há fuga. Os melhores custam caro e reduzem a chance de interceptação."],
			["Chance de interceptação", "Depende da suspeita, das horas já gastas, do passaporte, do avião e de haver mandado."]
		],
		"how": [
			"Garanta primeiro o passaporte e o avião: sem eles, o resto não adianta.",
			"Liquide o que vale mais e converta em Monero.",
			"Clique em Decolar quando a troca entre levar mais e arriscar mais deixar de valer."
		]
	}
}

const MANUAL: Array = [
	{
		"nav": "Objetivo",
		"title": "Três atos e uma saída",
		"body": "Você é o consultor de uma operação fictícia. O cliente entrega dinheiro sujo toda noite, e você tem um prazo para transformar isso em patrimônio limpo, sem chamar atenção demais.",
		"points": [
			"Ato 1: {goal1} em {days1} dias, com pequenos negócios locais.",
			"Ato 2: {goal2} em {days2} dias. Entram a política e a Polícia Federal.",
			"Ato 3: {goal3} em {days3} dias. Bater essa meta inicia a Operação Fuga.",
			"O fim da campanha depende das suas escolhas: há cinco finais."
		],
		"map": ["all", -1],
		"map_note": "A tela do jogo: menu lateral, topo, centro e rodapé."
	},
	{
		"nav": "A tela",
		"title": "Como ler a tela",
		"body": "O painel tem quatro áreas fixas. Elas nunca mudam de lugar.",
		"points": [
			"Menu lateral: troca de módulo. As teclas de 1 a 8 fazem o mesmo.",
			"Topo: dia, caixa, suspeita e patrimônio, visíveis em todas as abas.",
			"Centro: o módulo aberto. O botão Como funciona explica cada um.",
			"Rodapé: o próximo passo sugerido e o botão Finalizar turno."
		],
		"map": ["all", -1],
		"map_note": "As quatro áreas fixas do painel."
	},
	{
		"nav": "O turno",
		"title": "O que acontece em um dia",
		"body": "Cada dia é um turno. Você age quanto quiser e, quando terminar, finaliza o turno. A noite faz o resto.",
		"points": [
			"De dia: processe saldo sujo nas empresas. Cada uma tem um teto diário.",
			"À noite: os laranjas recebem, a suspeita perde {decay}% do valor e chega uma nova remessa.",
			"Dinheiro sujo parado por muitos dias chama atenção e eleva a suspeita.",
			"A troca de turno mostra o fechamento do dia, linha por linha."
		],
		"map": ["footer", -1],
		"map_note": "Finalizar turno fica no rodapé, à direita."
	},
	{
		"nav": "Empresas",
		"title": "Empresas e laranjas",
		"body": "As empresas transformam saldo sujo em limpo, com uma perda no caminho. Os laranjas aumentam o quanto cada uma processa por dia.",
		"points": [
			"Abra Empresas e clique em Operar. A prévia mostra o que entra limpo e a suspeita gerada.",
			"Abra Laranjas para contratar. Mais capacidade, com o mesmo risco no teto.",
			"Com a suspeita acima de {stress_level}%, os laranjas se estressam. No limite, delatam.",
			"A cada ato aparecem negócios maiores para comprar."
		],
		"map": ["center", 1],
		"map_note": "Empresas é o item 2 do menu. Laranjas, o 3."
	},
	{
		"nav": "Bens",
		"title": "Prestígio e malha fina",
		"body": "O saldo limpo compra bens de luxo. Eles dão prestígio, que barateia as operações e abre portas. Mas patrimônio à vista precisa de renda declarada.",
		"points": [
			"Cada nível de prestígio reduz o custo de todas as empresas.",
			"Declarar renda custa {tax}% de imposto e justifica metade do valor em ostentação.",
			"Ostentar além disso arrisca uma malha fina: multa, confisco ou contestação.",
			"Bens continuam contando para a meta do ato."
		],
		"map": ["center", 3],
		"map_note": "Bens é o item 4 do menu lateral."
	},
	{
		"nav": "Risco",
		"title": "Suspeita, ameaças e mandado",
		"body": "A suspeita é o que encerra a campanha. Cada ato traz uma ameaça nova, e cada ameaça pede uma decisão.",
		"points": [
			"Ato 1: fiscalizações de rotina da Receita Federal.",
			"Ato 2: intimações, grampos e delações. Suspeita acima de {mandado_level}% por {mandado_days} noites gera mandado de prisão.",
			"Ato 3: auditoria da Interpol. Aos 90% de suspeita, o cartel queima o arquivo.",
			"A aba Risco tem ações pagas para reduzir a suspeita."
		],
		"map": ["top", 7],
		"map_note": "Risco é o item 8. A suspeita também fica no topo, em todas as abas."
	},
	{
		"nav": "Carteira",
		"title": "Cripto e fundos",
		"body": "Nem todo patrimônio precisa aparecer. O que fica na carteira conta para a meta e não gera ostentação.",
		"points": [
			"Cripto oscila toda noite. É a única forma de pagar o exílio de um laranja.",
			"Fundos rendem por noite e abrem a partir do Ato 2.",
			"No Ato 3, a Interpol pode congelar parte da carteira."
		],
		"map": ["center", 4],
		"map_note": "Carteira é o item 5 do menu lateral."
	},
	{
		"nav": "A fuga",
		"title": "Operação Fuga e os finais",
		"body": "Bater a meta do Ato 3, ou receber um mandado de prisão, inicia a fuga: {escape_hours} horas para sumir. Só o Monero embarca com você.",
		"points": [
			"Liquide empresas e bens, converta em Monero, compre passaporte e avião.",
			"Cada ação gasta horas. Ficar mais tempo rende mais e arrisca mais.",
			"Fugir sem mandado, com as três metas batidas, é a vitória perfeita.",
			"No fim do Ato 2, há uma saída alternativa: comprar imunidade parlamentar."
		],
		"map": ["all", -1],
		"map_note": "Na fuga, a aba Dark Web aparece no menu lateral."
	}
]

## Troca os marcadores {…} pelos valores atuais do balanceamento.
static func fill(text: String) -> String:
	var out: String = text
	var values: Dictionary = {
		"decay": "%d" % int(round(float(B.ACTS[0]["decay"]) * 100.0)),
		"decay3": "%d" % int(round(float(B.ACTS[2]["decay"]) * 100.0)),
		"stress_level": "%d" % int(B.STAFF_STRESS_LEVEL),
		"delation_days": "%d" % B.DELATION_DEADLINE,
		"tax": "%d" % int(round(B.INCOME_TAX * 100.0)),
		"mandado_level": "%d" % int(B.MANDADO_LEVEL),
		"mandado_days": "%d" % B.MANDADO_DAYS,
		"escape_hours": "%d" % int(B.ESCAPE_HOURS)
	}
	for i: int in range(B.ACTS.size()):
		values["goal%d" % (i + 1)] = GameManager.format_money(float(B.ACTS[i]["goal"]))
		values["days%d" % (i + 1)] = "%d" % int(B.ACTS[i]["days"])
	for key: String in values:
		out = out.replace("{%s}" % key, str(values[key]))
	return out

static func tab_label(tab_id: String) -> String:
	for entry_v: Variant in TABS:
		var entry: Array = entry_v as Array
		if str(entry[1]) == tab_id:
			return str(entry[0])
	return tab_id.to_upper()
