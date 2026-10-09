<img width="300" height="107" alt="gemini-svg" src="https://github.com/user-attachments/assets/b4a0c2d6-23b1-4cca-a987-e36119cb84c6" />
https://github.com/user-attachments/assets/279e1bf8-ca1c-4840-b4ae-793f9b3d6874
<div align="center">

  <!-- BANNER PRINCIPAL DO PROJETO -->
  ![Uploading gemini-<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 900 320" width="100%" height="100%">
  <defs>
    <!-- Background Gradient -->
    <linearGradient id="bgGlow" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#0a0d14"/>
      <stop offset="50%" stop-color="#101726"/>
      <stop offset="100%" stop-color="#06080e"/>
    </linearGradient>

    <!-- Neon Gradients -->
    <linearGradient id="cyanGrad" x1="0%" y1="0%" x2="100%" y2="0%">
      <stop offset="0%" stop-color="#00f0ff"/>
      <stop offset="100%" stop-color="#0072ff"/>
    </linearGradient>

    <linearGradient id="greenGrad" x1="0%" y1="0%" x2="100%" y2="0%">
      <stop offset="0%" stop-color="#00ff87"/>
      <stop offset="100%" stop-color="#60efff"/>
    </linearGradient>

    <linearGradient id="redGrad" x1="0%" y1="0%" x2="100%" y2="0%">
      <stop offset="0%" stop-color="#ff3366"/>
      <stop offset="100%" stop-color="#ff0055"/>
    </linearGradient>

    <!-- Neon Glow Filter -->
    <filter id="glow" x="-20%" y="-20%" width="140%" height="140%">
      <feGaussianBlur stdDeviation="3" result="blur" />
      <feMerge>
        <feMergeNode in="blur" />
        <feMergeNode in="SourceGraphic" />
      </feMerge>
    </filter>

    <style>
      .font-title { font-family: 'Segoe UI', system-ui, -apple-system, sans-serif; font-weight: 900; font-size: 38px; fill: url(#cyanGrad); letter-spacing: 4px; }
      .font-sub { font-family: 'Courier New', Consolas, monospace; font-weight: bold; font-size: 14px; fill: #8a9bb2; letter-spacing: 3px; }
      .font-code { font-family: Consolas, 'Courier New', monospace; font-size: 13px; fill: #00ff87; font-weight: bold; }
      .font-card-title { font-family: Consolas, 'Courier New', monospace; font-weight: bold; font-size: 13px; }
      .font-card-sub { font-family: Consolas, 'Courier New', monospace; font-size: 11px; fill: #94a3b8; }
      .font-card-val { font-family: Consolas, 'Courier New', monospace; font-weight: bold; font-size: 14px; fill: #ffffff; }

      @keyframes pulseGlow {
        0%, 100% { opacity: 0.25; transform: scale(1); }
        50% { opacity: 0.65; transform: scale(1.08); }
      }

      @keyframes scanbeam {
        0% { transform: translateY(0px); }
        100% { transform: translateY(320px); }
      }

      @keyframes dashFlow {
        0% { stroke-dashoffset: 24; }
        100% { stroke-dashoffset: 0; }
      }

      @keyframes blinker {
        0%, 100% { opacity: 1; }
        50% { opacity: 0; }
      }

      .bg-orb { animation: pulseGlow 4s infinite ease-in-out; transform-origin: center; }
      .beam-line { animation: scanbeam 5s linear infinite; }
      .dash-arrow { stroke-dasharray: 8 4; animation: dashFlow 1s linear infinite; }
      .cursor { animation: blinker 0.8s infinite; }
    </style>
  </defs>

  <!-- Frame Background -->
  <rect width="900" height="320" rx="12" fill="url(#bgGlow)" stroke="#1e293b" stroke-width="2"/>

  <!-- Subtle Cyber Grid -->
  <g opacity="0.08" stroke="#00f0ff" stroke-width="1">
    <line x1="0" y1="80" x2="900" y2="80"/><line x1="0" y1="160" x2="900" y2="160"/><line x1="0" y1="240" x2="900" y2="240"/>
    <line x1="180" y1="0" x2="180" y2="320"/><line x1="360" y1="0" x2="360" y2="320"/><line x1="540" y1="0" x2="540" y2="320"/><line x1="720" y1="0" x2="720" y2="320"/>
  </g>

  <!-- Ambient Glow -->
  <circle cx="150" cy="110" r="130" fill="#00f0ff" opacity="0.08" class="bg-orb"/>
  <circle cx="750" cy="210" r="120" fill="#00ff87" opacity="0.08" class="bg-orb"/>

  <!-- Top OS Window Bar -->
  <path d="M 0 12 C 0 5, 5 0, 12 0 L 888 0 C 895 0, 900 5, 900 12 L 900 36 L 0 36 Z" fill="#111827"/>
  <circle cx="20" cy="18" r="5" fill="#ff5f56"/>
  <circle cx="35" cy="18" r="5" fill="#ffbd2e"/>
  <circle cx="50" cy="18" r="5" fill="#27c93f"/>
  <text x="75" y="22" font-family="Consolas, monospace" font-size="12" fill="#64748b" font-weight="bold">CLEAN_SLATE_OS_v4.2 // WORKSTATION_TERMINAL</text>
  <rect x="765" y="9" width="120" height="18" rx="4" fill="#1e293b"/>
  <text x="825" y="22" font-family="Consolas, monospace" font-size="10" fill="#00f0ff" text-anchor="middle" font-weight="bold">ONLINE :: GODOT 4</text>

  <!-- Header Title -->
  <text x="45" y="95" class="font-title">CLEAN SLATE</text>
  <text x="47" y="118" class="font-sub">SIMULADOR DE LAVAGEM DE DINHEIRO</text>

  <!-- Terminal Status Box -->
  <g transform="translate(45, 142)">
    <rect x="0" y="-12" width="810" height="26" rx="4" fill="#090d16" stroke="#1e293b" stroke-width="1"/>
    <text x="12" y="5" class="font-code">&gt; STATUS: OPERAÇÕES_FINANCEIRAS_ATIVAS [RISCO: 15.5%] <tspan class="cursor" fill="#00f0ff">█</tspan></text>
  </g>

  <!-- Flow Cards -->
  <!-- 1. Colocação -->
  <g transform="translate(45, 185)">
    <rect width="225" height="90" rx="8" fill="#170c10" stroke="url(#redGrad)" stroke-width="1.5" filter="url(#glow)"/>
    <text x="16" y="26" class="font-card-title" fill="#ff3366">1. COLOCAÇÃO</text>
    <text x="16" y="46" class="font-card-sub">Saldo Sujo (Entrada)</text>
    <text x="16" y="68" class="font-card-val" fill="#ff5577">R$ 1.250.000,00</text>
  </g>

  <!-- Arrow 1 -->
  <path d="M 285 230 L 325 230" stroke="#00f0ff" stroke-width="2.5" class="dash-arrow"/>
  <polygon points="328,230 320,225 320,235" fill="#00f0ff"/>

  <!-- 2. Ocultação -->
  <g transform="translate(338, 185)">
    <rect width="225" height="90" rx="8" fill="#0a1520" stroke="url(#cyanGrad)" stroke-width="1.5" filter="url(#glow)"/>
    <text x="16" y="26" class="font-card-title" fill="#00f0ff">2. OCULTAÇÃO</text>
    <text x="16" y="46" class="font-card-sub">Empresas &amp; Cripto</text>
    <text x="16" y="68" class="font-card-val" fill="#60efff">Boate | Lavanderia | XMR</text>
  </g>

  <!-- Arrow 2 -->
  <path d="M 578 230 L 618 230" stroke="#00ff87" stroke-width="2.5" class="dash-arrow"/>
  <polygon points="621,230 613,225 613,235" fill="#00ff87"/>

  <!-- 3. Integração -->
  <g transform="translate(630, 185)">
    <rect width="225" height="90" rx="8" fill="#081c12" stroke="url(#greenGrad)" stroke-width="1.5" filter="url(#glow)"/>
    <text x="16" y="26" class="font-card-title" fill="#00ff87">3. INTEGRAÇÃO</text>
    <text x="16" y="46" class="font-card-sub">Lucro Legalizado</text>
    <text x="16" y="68" class="font-card-val" fill="#00ff87">R$ 1.062.500,00</text>
  </g>

  <!-- Laser Scanline -->
  <rect x="0" y="0" width="900" height="3" fill="url(#cyanGrad)" opacity="0.3" class="beam-line"/>
</svg>
svg.svg…]()


  # 💼 Clean Slate: Simulador de Lavagem de Dinheiro

  [![Godot Engine](https://img.shields.io/badge/Godot_Engine-4.3_Stable-478cbf?style=for-the-badge&logo=godotengine&logoColor=white)](https://godotengine.org/)
  [![Linguagem](https://img.shields.io/badge/Linguagem-GDScript_2.0-478cbf?style=for-the-badge)](https://docs.godotengine.org/)
  [![Plataforma](https://img.shields.io/badge/Plataforma-PC_%2F_Desktop-black?style=for-the-badge)](https://godotengine.org/)
  [![Status](https://img.shields.io/badge/Status-Projeto_Acad%C3%Aamico-orange?style=for-the-badge)](#)

  <p align="center">
    <b>Jogo 2D de Estratégia, Gestão Financeira e Simulação de Sistemas em Godot Engine 4.3</b><br>
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
|   • Compra de Bens de Luxo                                       • Início do Novo Dia |
+-----------------------------------------------------------------------------------+
```

1. **Loop de Trabalho (Workstation Terminal OS v4.2):** Interface rica baseada em nós `Control`, `Containers` e `CanvasLayer`. Funciona como um sistema operacional simulado com abas de finanças, gestão de negócios, contratação de operadores e alertas de crise.
2. **Loop de Rotina (Cutscenes em Pixel Art):** Animações 2D no final do turno mostrando a rotina do personagem (desligar o PC, apagar as luzes, dormir e acordar às 07:00 AM para um novo dia).

---

## 📈 Progressão da Campanha em 3 Atos

O jogo não encerra passivamente ao atingir a primeira meta. A evolução do jogador desbloqueia novas camadas de poder e ameaças em uma campanha estruturada por Atos:

### 🟢 Ato 1: O Pequeno Operador
* **Meta Financeira:** R$ 2.000.000 em Saldo Limpo | **Prazo:** 30 Dias
* **Foco:** Alocação inicial em pequenos negócios locais (Lavanderia Pura Vida, Bar Central).
* **Principais Ameaças:** Fiscalizações de rotina da Receita Federal e ajuste de margem de risco.

### 🟡 Ato 2: O Consultor Político e Corporativo
* **Meta Financeira:** R$ 15.000.000 em Saldo Limpo | **Prazo:** 45 Dias
* **Foco:** Expansão para grandes estabelecimentos (Boate Neon, Concessionárias), contratos públicos e doações eleitorais fraudulentas.
* **Principais Ameaças:** Investigações da Polícia Federal, grampos telefônicos e risco de delação premiada de laranjas estressados.

### 🔴 Ato 3: O Sindicato Global e Offshores
* **Meta Financeira:** R$ 100.000.000 em Saldo Limpo | **Prazo:** 60 Dias
* **Foco:** Abertura de contas offshore nas Bahamas, transações em criptomoedas (Monero / XMR) e aquisição de obras de arte.
* **Principais Ameaças:** Auditoria internacional da Interpol e queima de arquivo executada pelo próprio cartel caso a Taxa de Suspeita ultrapasse 90%.

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
$$\text{SuspeitaGerada} = \left(\frac{\text{DinheiroLavadoHoje}}{\text{CapacidadeDiaria}}\right) \times \text{FatorRiscoEmpresa}$$

* **Boate Neon:** Capacidade R$ 50.000/dia | Taxa Imposto: 12.0% | Fator Risco: 5.0%
* **Lavanderia Pura Vida:** Capacidade R$ 30.000/dia | Taxa Imposto: 8.0% | Fator Risco: 2.5%
* **Bar Central:** Capacidade R$ 20.000/dia | Taxa Imposto: 10.0% | Fator Risco: 3.0%

### 3. 💎 Lifestyle e "Índice de Ostentação" (Uso do Saldo Limpo)
O Saldo Limpo é utilizado na aba **Bens & Estilo de Vida** para adquirir carros esportivos, mansões, iates e relógios.
* **Benefício:** Aumenta o Prestígio do jogador, concedendo descontos bancários e acesso a novos negócios nos Atos seguintes.
* **Mecânica da Malha Fina:** Se $\text{ÍndiceOstentação} > (\text{ImpostoDeclarado} \times 0.5)$, é ativada uma probabilidade diária de auditoria por Malha Fina pela Receita Federal, exigindo o pagamento de multas ou o confisco de bens.

### 4. 👔 Gestão de "Laranjas" e Delação Premiada
Para expandir a capacidade das empresas, o jogador contrata testas de ferro ("Laranjas").
* **Atributos:** Capacidade Adicional (R$), Custo Diário (R$), Lealdade (0-100) e Estresse (0-100).
* **Delação Premiada:** Quando a Suspeita Global ultrapassa 50%, o estresse dos laranjas sobe diariamente. Ao atingir 100% de estresse, o laranja inicia uma delação com a Polícia Federal.
* **Ações de Intervenção:**
  * *Pagar Silêncio:* Custo elevado em dinheiro para restaurar a lealdade.
  * *Exilar Laranja:* Enviar o operador para o exterior gastando criptomoedas.
  * *Descartar Laranja:* Interrompe as operações na empresa, perde os valores retidos e aumenta a Suspeita Global em +15%.

### 5. 🚨 Clímax: Operação Fuga (Endgame Ativo)
Ao atingir a meta do Ato 3 ou em caso de emissão de Mandado de Prisão Preventiva, o jogo entra na **Operação Fuga** com um cronômetro de 72 horas (3 turnos):
1. Liquidar ativos das empresas no menor tempo possível.
2. Converter Saldo Limpo em Criptomoedas Monero na Dark Web.
3. Comprar passaportes falsos e fretar um jatinho clandestino para escapar.

---

## 🏆 Os 4 Finais Dinâmicos

| Final | Condição | Resultado |
| :--- | :--- | :--- |
| 👑 **O Rei do Offshore** | Bateu todas as metas, converteu o patrimônio e fugiu sem mandados ativos. | **Vitória Perfeita:** Cutscene de aposentadoria em Mônaco. |
| 🏛️ **O Político Influente** | Lavou dinheiro suficiente para comprar imunidade parlamentar. | **Vitória Neutra:** Eleito Deputado Federal e blindado de processos. |
| 🚔 **Preso na Operação** | Suspeita atingiu 100% ou um Laranja concluiu uma Delação Premiada. | **Derrota Jurídica:** Prisão preventiva e confisco total de bens. |
| 💀 **Queima de Arquivo** | Suspeita ultrapassou 90% no Ato 3. | **Derrota Crítica:** O cartel elimina o operador para evitar vazamentos. |

---

## 🚀 Como Executar o Projeto

1. Faça o download do **[Godot Engine 4.3 Stable](https://godotengine.org/download)**.
2. Clone o repositório em sua máquina:
   ```bash
   git clone [https://github.com/SEU_USUARIO/clean-slate.git](https://github.com/SEU_USUARIO/clean-slate.git)
   ```
3. Abra o Godot Engine, clique em **Importar** (*Import*) e escolha o arquivo `project.godot` na pasta raiz do projeto.
4. Clique em **Importar e Editar** (*Import & Edit*).
5. Pressione **F5** para rodar o jogo.

---

<div align="center">
  <p>Desenvolvido para fins acadêmicos e educacionais em arquitetura de jogos 2D e programação GDScript na Godot Engine 4.</p>
</div>
