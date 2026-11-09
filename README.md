<img width="1267" height="422" alt="Captura de tela 2026-10-09 135116" src="https://github.com/user-attachments/assets/49c70339-99f1-439b-b73a-83ee000261b9" />

<div align="center">

  <!-- BANNER PRINCIPAL DO PROJETO -->


  # 💼 Clean Slate: Simulador de Lavagem de Dinheiro

  [![Godot Engine](https://img.shields.io/badge/Godot_Engine-4.7_Stable-478cbf?style=for-the-badge&logo=godotengine&logoColor=white)](https://godotengine.org/)
  [![Linguagem](https://img.shields.io/badge/Linguagem-GDScript_2.0-478cbf?style=for-the-badge)](https://docs.godotengine.org/)
  [![Plataforma](https://img.shields.io/badge/Plataforma-PC_%2F_Desktop-black?style=for-the-badge)](https://godotengine.org/)
  [![Status](https://img.shields.io/badge/Status-Projeto_Acad%C3%Aamico-orange?style=for-the-badge)](#)

  <p align="center">
    <b>Jogo 3D de Estratégia, Gestão Financeira e Simulação de Sistemas em Godot Engine 4.7</b><br>
    Assuma o papel de um operador financeiro ilícito. Aloque recursos em empresas de fachada, gerencie laranjas, fure a malha fina da Receita Federal e escale sua operação pelo crime organizado.
  </p>

</div>

---

## 📹 Demonstração do Jogo em Ação

<div align="center">  

https://github.com/user-attachments/assets/44cd69d8-5c89-4b6d-bc87-fefed8e6948e

</div>

---

## 🎮 Conceito Geral e Dois Loops Principais

**Clean Slate** equilibra a simulação complexa de sistemas financeiros ilícitos com uma narrativa envolvente através de dois loops visuais complementares:

```
+-----------------------------------------------------------------------------------+
|                                 LOOP PRINCIPAL                                    |
|                                                                                   |
|  [ 🖥️ LOOP DE TRABALHO (UI Terminal) ] ──► Finalizar Turno ──► [ 🛌 LOOP DE ROTINA ]  |
|   • Gestão de Empresas de Fachada                                • Cutscenes Pixel Art|
|   • Alocação de Saldo Sujo                                       • Transição Dia/Noite|
|   • Gestão de Laranjas & Cripto                                  • Fade via Tweens    |
|   • Compra de Bens de Luxo                                       • Relatório do Turno |
|   • Missões, Contratos e Decisões                                • Início do Novo Dia |
+-----------------------------------------------------------------------------------+
```

1. **Loop de Trabalho (Workstation Terminal OS v4.2):** Interface rica baseada em nós `Control`, `Containers` e `CanvasLayer`. Funciona como um sistema operacional simulado com abas de finanças, gestão de negócios, contratação de operadores e alertas de crise. Ela abre quando o jogador **senta no computador dentro do quarto 3D**.
2. **Loop de Rotina (Quarto 3D + Cutscenes em Pixel Art):** O jogo roda em primeira pessoa dentro do apartamento do operador: WASD para andar (Shift corre), mouse para olhar, **E** para usar o objeto sob a mira, **ESC** vai ao computador e, dentro de um objeto, levanta. **V** esconde a interface para ver o objeto. Cada aba é um objeto: computador (Visão geral), quadro de cortiça (Missões), maquete (Empresas), quadro de pessoal (Laranjas), vitrine (Bens, os itens comprados aparecem lá), cofre (Carteira), arquivo (Transações), TV (Notícias), painel de risco (Suspeita) e notebook (Dark Web, só na fuga). A cama finaliza o turno e a porta vira a decolagem na fuga. Um marcador amarelo indica o próximo passo. A iluminação do quarto acompanha o relógio do turno — sol pela janela de dia, luminária e monitor de noite. Dormir na cama finaliza o turno e roda a cutscene da noite (~3 s, ~7 s na primeira noite e nas trocas de ato), com o relatório do turno por cima.

---

## 🎨 Direção de Arte: "Concreto & Latão"

Noir de arranha-céu brasileiro. O jogador mora no 12º andar e a cidade inteira cabe na janela.

| Elemento | Escolha |
| :--- | :--- |
| **Paleta** | Grafite e concreto nas superfícies; âmbar de tungstênio nas luzes práticas; **latão** em tudo que é dinheiro e luxo; oxblood no couro e no tapete; o azul-sódio frio da cidade entrando pela janela (é a cor da ameaça). |
| **Luz** | Só luz motivada, com fonte visível: luminária articulada na mesa (luz-chave, com sombra), pendente sobre a maquete, abajur de arco, abajur de cabeceira, arandelas sobre os quadros, monitores e a cidade. Tonemap AgX, SSAO, SSIL, SSR e névoa volumétrica (qualidade alta). |
| **Vista** | Skyline procedural em três camadas (cada prédio com janelas que acendem e apagam), letreiro vermelho de hotel pulsando no quarto, faróis correndo lá embaixo, luzes de aviação, lua. Chuva escorrendo no vidro em parte dos dias. |
| **Tipografia** | IBM Plex Serif nos títulos (tom de dossiê/thriller), Plex Sans no texto, Plex Mono nos números. |
| **Interface** | Pasta de dossiê: painéis grafite, filete e marcador de latão, cantos secos, botões primários em latão translúcido. |

### O apartamento evolui com a campanha
* **Ato 1 — improviso:** mesa de aço, um monitor, caixas de mudança fechadas, uma planta na janela, tapete gasto.
* **Ato 2 — dinheiro chegando:** segundo monitor, poltrona de leitura virada para a janela, taças e uísque, vinhos no rack, quadro sobre o sofá, tapete oxblood, cabeceira de couro, sanca de LED âmbar.
* **Ato 3 — bunker de luxo:** terceiro monitor, busto de mármore, segundo quadro, câmeras de segurança com LED piscando nos cantos.
* **Sempre:** a maquete acende as janelas das empresas que são suas; a vitrine mostra os bens comprados; o cofre empilha dinheiro.

### O quarto reage à pressão
* Suspeita acima de 60%, à noite: viaturas com giroflex lá embaixo, refletindo no teto.
* Acima de 80%: helicóptero com holofote varrendo o quarto pela janela, coração batendo no som.
* Durante a batida: a luz do corredor pisca por baixo da porta (alguém parado do outro lado).
* **Janela (E):** descreve a rua sem números — de "ninguém olhando para cima" a "a mesma viatura passou três vezes".

---

## 📈 Progressão da Campanha em 3 Atos

Cada turno é um ciclo de decisões. O ato termina **na noite em que a meta é batida**, mesmo antes do prazo: o prazo existe para pressionar, não para obrigar o jogador a esperar. Uma campanha completa leva **cerca de 15 a 20 turnos**.

| Ato | Meta de patrimônio | Prazo | Remessa por turno | O que muda no jogo |
| :--- | :--- | :--- | :--- | :--- |
| 🟢 **1. O Pequeno Operador** | R$ 900.000 | 7 turnos | R$ 220.000 | Recursos curtos: onde lavar, quem contratar, quanto arriscar. Ameaça: Receita Federal. |
| 🟡 **2. O Consultor Político e Corporativo** | R$ 4.000.000 | 8 turnos | R$ 1.300.000 | Política e gente: influência, operadores ambiciosos, padrinho político, grampos e delações. Ameaça: Polícia Federal. |
| 🔴 **3. O Sindicato Global e Offshores** | R$ 15.000.000 | 9 turnos | R$ 4.000.000 | Escala e saída: fundos offshore, crises internacionais, cartel e a preparação da fuga. Limite de suspeita cai para 90%. |

Patrimônio = saldo limpo + empresas + bens + carteira. Se o prazo vencer, há uma prorrogação de 2 turnos que custa 20% do saldo limpo; na segunda vez, a campanha acaba.

---

## 🕹️ Jogando em 3D: o que dá para fazer

| Mecânica | Como funciona |
| :--- | :--- |
| **Lavar com as mãos** | A remessa vira malotes no canto do quarto (**ENTREGA DO CLIENTE**). Pegue um malote com **E** e leve até uma empresa: na **maquete** (mire no prédio) ou na **rua** (porta da empresa). A entrega é uma operação normal do jogo: mesma perda, mesma suspeita, mesma capacidade do dia. |
| **Cidade explorável** | A porta do apartamento leva à rua. As 7 empresas são prédios: acesos e abertos se são suas, com placa de preço se estão à venda, escuros se ainda estão fora de alcance. Há pedestres, carros e, com a suspeita acima de 50%, uma viatura da PF. |
| **Grampo físico** | Com um grampo ativo, três aparelhos com LED vermelho piscando surgem escondidos no quarto. Ache e remova todos para acabar com o grampo, sem pagar a varredura. |
| **Batida na porta** | Ao acordar, com suspeita acima de 40% e dinheiro sujo à vista, a PF pode bater na porta. Você tem 22 s para levar os malotes ao **cofre**. Se sobrar dinheiro, 15% do saldo sujo é apreendido e a suspeita sobe; se guardar tudo, ela cai. |
| **Notebook: invasão** | Minigame de sequência de setas (3 rodadas). Apaga rastros: de 2 a 7 pontos de suspeita. Uma vez por turno, custa 30 min. Na fuga, o mesmo notebook abre a Dark Web. |
| **Triturador** | Minigame de timing (4 rodadas). Cada acerto reduz 8% da suspeita gerada por operação, por 2 turnos. Uma vez por turno, custa 20 min. |

Todos os números (malotes, batida, minigames) estão em `scripts/data/balance.gd`.

---

## 🎯 Turnos com Propósito: Missões, Acontecimentos e Relatório

### Aba Missões
* **Objetivo principal:** a meta de patrimônio do ato, com a trilha da campanha.
* **Objetivos do ato (4 por ato):** sorteados no início de cada ato, de acordo com a situação da partida (um objetivo que já está quase cumprido não entra). Os dois primeiros do Ato 1 ensinam o básico. Exemplos: *Abra o caixa*, *Gente de confiança*, *Livros em ordem* (resolver uma fiscalização), *Sócio da noite* (libera a boate antes do Ato 2), *Equipe profissional*, *Sobreviver ao inquérito*, *Patrimônio internacional*, *Preparar a saída* (etapas financiadas, uma por turno).
* **Recompensas:** dinheiro, prestígio, influência, redução de suspeita, candidatos de elite, empresas liberadas antes do ato e vantagens permanentes (custo menor nas empresas, diárias menores, fundos rendendo mais, chance menor de interceptação na fuga). Concluir todos os objetivos de um ato dá o bônus **Ato impecável**.
* **Contratos do cliente:** pedidos avulsos a cada ~3 turnos (*Lote urgente*, *Nota fria*, *Fique quieto*, *Abaixo do radar*, *Favor político*, *Comprador de arte*). Estados: **disponível**, **em andamento**, **concluída** ou **falhou**. Falhar cobra penalidade.

### Acontecimentos (Director)
Quase toda noite traz uma decisão. A chance de um acontecimento sobe a cada noite tranquila, então algo relevante aparece a cada 1 ou 2 turnos, com no máximo 2 decisões por noite. Cada acontecimento tem de 2 a 3 escolhas com consequências diferentes, e algumas agendam consequências futuras:
* **Empresas:** queda de desempenho (investir, aceitar a queda ou vender), proposta de compra, ponto comercial com desconto, blitz na vida noturna.
* **Gente:** laranja pedindo aumento, operador querendo virar sócio, doleiro preso em Miami.
* **Dinheiro e mercado:** investidor com capital rápido (a cobrança volta 3 turnos depois), pânico na cripto (com rebote), banco suíço pedindo a origem dos recursos.
* **Política e imprensa:** vereador com contrato de obra (ele pode ser preso depois), reportagem investigativa, capa de revista.
* **Reações ao jogador:** usar uma empresa no teto por 3 turnos seguidos gera um alerta de movimento atípico; deixar dinheiro sujo parado faz o cliente cobrar resultado.
* **Raros:** malote retido na alfândega, denúncia anônima, gerente de banco com uma janela única.
* **Passagem de ato:** um padrinho político no Ato 2 (que cobra um favor mais tarde) e o contador do cartel no Ato 3.

### Relatório do Turno
O fechamento mostra só o que importa naquele turno: resultado financeiro, suspeita, patrimônio em relação à meta, objetivos e contratos concluídos ou falhos, laranjas em situação crítica, prazo apertado, decisões pendentes e oportunidades para o próximo turno.

---

## ⚙️ Sistemas Principais e Mecânicas de Gameplay

### 1. 📖 Tutorial Interativo (As 3 Fases da Lavagem)
Antes de iniciar, o modal **Manual de Boas-Vindas do Consultor** explica o fluxo financeiro do jogo:
* **Colocação (Placement):** Injetar dinheiro sujo no fluxo comercial das empresas de fachada.
* **Ocultação (Layering):** Mover valores através de criptoativos e contas offshore para fragmentar o rastro fiscal.
* **Integração (Integration):** Retirar os fundos legalizados na forma de lucros e dividendos limpos.

```
 [ DINHEIRO SUJO ] ──► (1. COLOCAÇÃO) ──► [ EMPRESAS DE FACHADA ]
                                                 │
                                         (2. OCULTAÇÃO)
                                                 │
                                                 ▼
 [ LUCRO LIMPO ]   ◄── (3. INTEGRAÇÃO) ◄── [ CRIPTO & OFFSHORE ]
```

### 2. 🏬 Empresas de Fachada e Cálculo de Risco
Cada empresa possui parâmetros operacionais específicos:
$$\text{SuspeitaGerada} = \left(\frac{\text{DinheiroLavadoNoTurno}}{\text{CapacidadeDoTurno}}\right) \times \text{RiscoNoTeto}$$

| Empresa | Ato | Capacidade por turno | Custo | Risco no teto | Preço |
| :--- | :---: | ---: | ---: | ---: | ---: |
| Lavanderia Pura Vida | 1 | R$ 40 mil | 12% | 4,5 | já é sua |
| Bar Oasis | 1 | R$ 60 mil | 16% | 7,0 | já é sua |
| Boate Necturne | 2 | R$ 220 mil | 20% | 9,0 | R$ 450 mil |
| Concessionária Nova | 2 | R$ 320 mil | 18% | 10,0 | R$ 700 mil |
| Construtora Horizonte | 2 | R$ 650 mil | 14% | 11,0 | R$ 1,5 mi (exige prestígio) |
| Galeria Meridiano | 3 | R$ 1,4 mi | 10% | 12,0 | R$ 4 mi (exige prestígio) |
| Atlântica Trading | 3 | R$ 2,6 mi | 8% | 16,0 | R$ 8 mi (exige prestígio) |

A suspeita perde 10% do próprio valor a cada noite (8% no Ato 3).

### 3. 💎 Lifestyle e "Índice de Ostentação" (Uso do Saldo Limpo)
O Saldo Limpo é utilizado na aba **Bens & Estilo de Vida** para adquirir carros esportivos, mansões, iates e relógios.
* **Benefício:** Aumenta o Prestígio do jogador, concedendo descontos bancários e acesso a novos negócios nos Atos seguintes.
* **Mecânica da Malha Fina:** Se $\text{ÍndiceOstentação} > (\text{ImpostoDeclarado} \times 0.5)$, é ativada uma probabilidade, a cada turno, de auditoria por Malha Fina pela Receita Federal, exigindo o pagamento de multas ou o confisco de bens.

### 4. 👔 Gestão de "Laranjas" e Delação Premiada
Para expandir a capacidade das empresas, o jogador contrata testas de ferro ("Laranjas").
* **Atributos:** Capacidade Adicional (R$), Diária (R$), Lealdade (0-100) e Estresse (0-100).
* **Delação Premiada:** Quando a Suspeita Global ultrapassa 50%, o estresse dos laranjas sobe a cada turno. Ao atingir 100% de estresse, o laranja inicia uma delação com a Polícia Federal.
* **Ações de Intervenção:**
  * *Pagar Silêncio:* Custo elevado em dinheiro para restaurar a lealdade.
  * *Exilar Laranja:* Enviar o operador para o exterior gastando criptomoedas.
  * *Descartar Laranja:* Interrompe as operações na empresa, perde os valores retidos e aumenta a Suspeita Global em +15%.

### 5. 🚨 Clímax: Operação Fuga (Endgame Ativo)
Ao atingir a meta do Ato 3 ou em caso de Mandado de Prisão Preventiva (suspeita acima de 80% por 3 turnos nos Atos 2 e 3), o jogo entra na **Operação Fuga**: um orçamento de 72 horas em que cada ação gasta tempo.
1. Comprar passaporte falso e contratar o avião (sem os dois, não há fuga).
2. Liquidar empresas, bens e carteira, com deságio.
3. Converter o saldo limpo em Monero na Dark Web, em lotes.
4. Decolar. A chance de interceptação sobe com a suspeita e com as horas gastas, e cai com bons documentos, um bom avião e as vantagens do Ato 3 (*Preparar a saída*, *Patrimônio internacional*, *Confiança do cartel*).


### 📱 Celular de trabalho
O celular na mesa toca durante o dia. Parte dos acontecimentos noturnos passa a chegar como ligação de um **elenco recorrente**: Beto Vidal (gerente das empresas), Marina Prado (repórter), Lúcio (doleiro), Dra. Vera Castro (advogada), Vereador Siqueira, Dona Célia (contadora), Sr. Albrecht (banco suíço), O Contador (cartel) e O Cliente. O aparelho vibra, acende e anda na mesa; atenda com **E**. Se ninguém atender, vira "ligação perdida" e a decisão cai na noite. O número de decisões por turno não muda.

### 🧠 Personalidade dos laranjas
Cada laranja tem um traço fixo, visível no cartão e no quadro de pessoal:

| Traço | Efeito |
| :--- | :--- |
| Leal | Estresse sobe 25% mais devagar. |
| Nervoso | +6% de capacidade, estresse 15% mais rápido. |
| Ganancioso | Diária 5% maior; o agrado vale quase o dobro. |
| Falastrão | Diária 12% menor, mas deixa um pouco de suspeita toda noite. |

### 🎧 Som e sensação de controle
Chuva, cidade, tensão que cresce com a suspeita, coração no limite, helicóptero, passos no taco e o celular vibrando — tudo gerado em código (`scripts/world/synth.gd`). O andar tem inércia, balanço de câmera e um leve aumento de campo de visão ao correr.

---

## 🏆 Os 5 Finais Dinâmicos

| Final | Condição | Resultado |
| :--- | :--- | :--- |
| 👑 **O Rei do Offshore** | Bateu todas as metas, converteu o patrimônio e fugiu sem mandados ativos. | **Vitória Perfeita:** Cutscene de aposentadoria em Mônaco. |
| ✈️ **Foragido** | Fugiu com um mandado de prisão no encalço. | **Vitória Amarga:** o dinheiro foi junto; a paz, não. |
| 🏛️ **O Político Influente** | Bateu a meta do Ato 2 com influência 5 e comprou imunidade parlamentar. | **Vitória Neutra:** Eleito Deputado Federal e blindado de processos. |
| 🚔 **Preso na Operação** | Suspeita atingiu 100%, um laranja fechou a delação, o prazo venceu duas vezes ou o avião foi interceptado. | **Derrota Jurídica:** Prisão preventiva e confisco total de bens. |
| 💀 **Queima de Arquivo** | Suspeita ultrapassou 90% no Ato 3. | **Derrota Crítica:** O cartel elimina o operador para evitar vazamentos. |

---

## 🚀 Como Executar o Projeto

1. Faça o download do **[Godot Engine 4.7](https://godotengine.org/download)**.
2. Clone o repositório e abra o `project.godot` no Godot (**Importar** > **Importar e Editar**).
3. Espere a importação terminar na primeira abertura e pressione **F5**. Resolução: 1366×768. O jogo usa o renderer **Forward+** (precisa de GPU com Vulkan). Em placa integrada, a qualidade gráfica começa em *Média* (Configurações → Qualidade gráfica alta liga luz indireta, reflexos e névoa volumétrica).

Saves de versões anteriores (atos de 30/45/60 dias ou de 12/14/16 turnos) continuam funcionando: o turno é convertido para a mesma fração do prazo novo; dinheiro, empresas, laranjas, bens e carteira são preservados.

---

## 🧪 Testes e Balanceamento

Todos rodam pela linha de comando e não alteram o save do jogador.

```bash
# Balanceamento e ritmo: 7 estilos de jogador, campanha inteira (~10 s)
godot --headless --path . res://tests/sim.tscn
#   RUNS=50 STYLES=sensato,ruim VERBOSE=1 TRACE=1

# Interface com cliques e teclas reais: um turno completo, salvar/carregar, migração
# de save antigo, uma campanha inteira e todos os finais (~3 min)
godot --path . res://tests/play.tscn

# Capturas de todas as telas em tests/out/, com auditoria de texto fora do painel
godot --path . res://tests/shots.tscn

# Capturas do apartamento 3D (dia e noite, 9 pontos de vista) em tests/out/room/,
# com FPS e draw calls.  PREFIX=nome  STAGE=1|2|3 (evolução)  RAIN=0|1  SCENE=tensao
godot --path . res://tests/room_shots.tscn

# FPS numa vista fixa, ligando e desligando cada efeito
godot --path . res://tests/tools/perf.tscn
```

Referência atual (`sim.tscn`, 20 partidas por estilo, semente padrão):

| Estilo de jogador | Turnos até cada ato (1 / 2 / 3) | Finais |
| :--- | :--- | :--- |
| Equilibrado (sensato) | 4,4 / 6,7 / 8,3 (≈ 19 turnos) | 65% Rei do Offshore, o resto preso na decolagem |
| Opera sem parar | 6,2 / 8,0 / 8,8 (≈ 23 turnos) | 30% Rei, 30% Queima de Arquivo, 40% preso |
| Prioriza empresas | 4,4 / 6,6 / 7,7 | 95% Rei do Offshore |
| Investe em funcionários | 4,2 / 7,2 / 7,7 | 75% Rei do Offshore |
| Prioriza investimentos | 4,3 / 7,0 / 8,1 | 55% Rei do Offshore |
| Cuida da suspeita | 4,7 / 6,4 / 8,4 | 85% Rei do Offshore |
| Toma decisões ruins | não passa do Ato 1 | preso |

A vitória depende de um sorteio na decolagem, então os números variam bastante com a semente: rode com `SEED=5000` ou `SEED=9000` e `RUNS=30` para comparar mudanças (o estilo equilibrado fica entre 65% e 80%).

Cerca de 1,3 decisões por turno e no máximo 2 noites seguidas sem nenhuma decisão.

## 🛠️ Onde Ajustar

| Para mudar | Arquivo |
| :--- | :--- |
| Metas, prazos, preços, riscos, ritmo dos acontecimentos, duração da noite, malotes, batida, minigames | `scripts/data/balance.gd` |
| Quarto 3D: interações, câmera, HUD | `scripts/world_3d.gd` |
| Construção do apartamento, luz, vista, evolução por ato, qualidade gráfica | `scripts/world/apartment.gd` |
| Conteúdo das telas (monitores, TV, notebook) | `scripts/world/screen_ui.gd` |
| Celular | `scripts/world/phone.gd` (quem liga: `CALLERS` em `scripts/systems/director.gd`) |
| Som ambiente e sons gerados | `scripts/world/ambience.gd`, `scripts/world/synth.gd` |
| Janelas da cidade e chuva no vidro | `assets/shaders/city_facade.gdshader`, `assets/shaders/rain_glass.gdshader` |
| Traços dos laranjas | `STAFF_TRAITS` em `scripts/data/balance.gd` |
| Rua, prédios, pedestres e carros | `scripts/world/city.gd` |
| Grampos físicos e batida | `scripts/world/events_3d.gd` |
| Minigames | `scripts/ui/minigames.gd` |
| Objetivos e contratos | `scripts/data/missions_data.gd` |
| Acontecimentos e suas consequências | `scripts/systems/director.gd` |
| Textos de ajuda e manual | `scripts/data/texts.gd` |

---

## 📜 Créditos de Assets

* Modelos e texturas 3D: [Poly Haven](https://polyhaven.com), domínio público (CC0). Lista e autores em `assets/CREDITS_POLYHAVEN.md`.
* Fontes: família IBM Plex (Sans, Mono, Serif), SIL Open Font License (`assets/fonts/OFL.txt`).
* Skills de desenvolvimento usadas com o Claude Code: [GodotPrompter](https://github.com/jame581/GodotPrompter) (MIT), em `.claude/skills/`.

<div align="center">
  <p>Desenvolvido para fins acadêmicos e educacionais em arquitetura de jogos 3D e programação GDScript na Godot Engine 4.</p>
</div>
