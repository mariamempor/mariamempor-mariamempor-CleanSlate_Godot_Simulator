# CLEAN SLATE — Simulador de Lavagem de Dinheiro

Projeto acadêmico 2D em Godot 4.7 / GDScript. Versão 2.0: campanha em três atos, laranjas, bens de luxo, Operação Fuga e cinco finais.

## Como abrir

1. Abra `project.godot` no Godot 4.7.x.
2. Espere a importação terminar na primeira abertura (fontes, ícones e sons).
3. Execute o projeto (F5). A resolução é 1366×768.

O save fica em `user://clean_slate_save.json` e a galeria de finais em `user://clean_slate_meta.json`. Saves da versão 1 são carregados, mas começam no Ato 1.

## Como o jogo funciona

Toda noite o cliente entrega uma remessa de dinheiro sujo. Você tem um prazo para transformá-la em **patrimônio** (saldo limpo + empresas + bens + carteira). Bater a meta abre o ato seguinte.

| Ato | Meta de patrimônio | Prazo | Remessa por noite | Ameaça | Limite de suspeita |
|---|---|---|---|---|---|
| 1. O Pequeno Operador | R$ 2 mi | 30 dias | R$ 140 mil | Receita Federal | 100% |
| 2. O Consultor Político e Corporativo | R$ 15 mi | 45 dias | R$ 750 mil | Polícia Federal: grampos, intimações, delações | 100% |
| 3. O Sindicato Global e Offshores | R$ 100 mi | 60 dias | R$ 3 mi | Interpol e o cartel | 90% |

Regras centrais:

- **Empresas** têm capacidade diária. A suspeita de uma operação é `risco no teto × valor ÷ capacidade do dia`.
- **Suspeita** perde 10% do próprio valor a cada noite (8% no Ato 3). Operar com a suspeita alta rende mais por dia, e qualquer imprevisto custa mais caro.
- **Laranjas** somam capacidade a uma empresa sem aumentar o risco no teto. Cobram diária. Com a suspeita acima de 50%, o estresse sobe; em 100, começa uma delação premiada, que você resolve pagando silêncio (limpo ou sujo), exilando (cripto) ou descartando (+15 de suspeita, empresa parada).
- **Bens** dão prestígio (desconto no custo das empresas e acesso a negócios maiores) e geram ostentação. Ostentação acima de `renda declarada × 0,5` abre chance diária de malha fina. Declarar renda custa 15% de imposto.
- **Mandado de prisão** (Atos 2 e 3): suspeita em 80% ou mais por 3 noites seguidas inicia a fuga antes da hora.
- **Prazo vencido**: uma prorrogação de 5 dias, que custa 15% do saldo limpo. Na segunda vez, a campanha acaba.
- **Operação Fuga**: 72 horas. Cada ação gasta horas (passaporte, avião, vender ativos, converter em Monero). A chance de interceptação sobe com a suspeita e com as horas gastas.

Finais: O Rei do Offshore, Foragido, O Político Influente, Preso na Operação Lava-Jato e Queima de Arquivo.

## Onde mexer

| Para mudar | Arquivo |
|---|---|
| Qualquer número do jogo (metas, preços, riscos, chances) | `scripts/data/balance.gd` |
| Textos de ajuda e do manual | `scripts/data/texts.gd` |
| Cores, fontes e componentes da interface | `scripts/ui/ui_kit.gd` |
| Uma aba do painel | `scripts/ui/tabs/tab_*.gd` |
| Cena da troca de turno | `scripts/ui/night_scene.gd` |
| Cenas dos finais | `scripts/ui/ending_scene.gd` |

## Estrutura

```
scripts/
  game_manager.gd      estado do dia, operações, save/load        (autoload GameManager)
  systems/
    campaign.gd        atos, ameaças, mandado, fuga e finais      (autoload Campaign)
    staff.gd           laranjas, estresse e delações              (autoload Staff)
    lifestyle.gd       bens, prestígio, ostentação e malha fina   (autoload Lifestyle)
    portfolio.gd       cripto, fundos e Monero                    (autoload Portfolio)
  data/                balance.gd (números) e texts.gd (textos)
  ui/
    ui_kit.gd          paleta, fontes e componentes               (autoload UI)
    widgets.gd         gráficos desenhados por código
    tab_base.gd        base das abas
    tabs/              uma aba por arquivo
    pixel_canvas.gd    base das cenas em pixel art
    night_scene.gd     troca de turno
    ending_scene.gd    finais
  main.gd              moldura: menu, manual, dashboard, modais
  popup_manager.gd     notícias e decisões                        (autoload PopupManager)
  turn_manager.gd      dispara as cenas                           (autoload TurnManager)
  audio_manager.gd, backdrop.gd, crt_overlay.gd
tests/                 simulação, teste de interface e auditoria de layout
```

Regra para quem for editar a interface: em um `Label`, ligue a quebra de linha ou o corte de texto **antes** de definir o tamanho. Use `UI.paragraph()` para texto corrido e `UI.clip()` para uma linha com reticências. Um Label sem quebra cresce até a largura do texto inteiro, e era isso que fazia o texto sair do popup de notícias.

## Testes

Rodam pela linha de comando, com o executável do Godot 4.7. Nenhum deles altera seu save: o save e a galeria são guardados no início e devolvidos no fim.

```
# Balanceamento: um bot joga a campanha inteira em três estilos (~5 s)
godot --headless --path . res://tests/sim.tscn
#   RUNS=50 muda o número de partidas; STYLES=sensato escolhe o estilo; VERBOSE=1 TRACE=1 detalha

# Interface: cliques e teclas de verdade, uma campanha completa e todos os finais (~3 min)
godot --path . res://tests/play.tscn

# Capturas de todas as telas em tests/out/, com auditoria de texto fora do painel
godot --path . res://tests/shots.tscn
```

Depois de mexer em `balance.gd`, rode `sim.tscn`. A referência atual, com 30 partidas por estilo: o bot "sensato" bate os atos nos dias 20, 34 e 46.

A pasta `tests/` não faz parte do jogo. Exclua-a na exportação (filtro `tests/*` em Recursos).

## Créditos de terceiros

Fontes IBM Plex Sans e IBM Plex Mono, licença SIL Open Font License 1.1 (`assets/fonts/OFL.txt`). Sem os arquivos de fonte, a interface usa a fonte padrão do Godot.
