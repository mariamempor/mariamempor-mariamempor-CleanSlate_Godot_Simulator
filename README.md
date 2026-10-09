<img width="500" height="700" alt="gemini-svg (1)" src="https://github.com/user-attachments/assets/3e486e2e-8972-4624-b1cd-60e9ea49af4a" />
  <!-- BANNER PRINCIPAL DO PROJETO -->


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
