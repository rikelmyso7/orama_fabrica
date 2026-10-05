# Plano: novo banco de dados para o estoque do Orama

Data: 01/10/2026 · Projeto: `orama_admin` (Flutter + Firebase)

## 1. Objetivo

Hoje todos os dados do app ficam no Firebase, e isso dificulta manipular e analisar os dados. A ideia é criar um **banco de dados próprio**, que o app leia e escreva, e migrar os dados do Firebase para ele.

Antes de criar o banco, a planilha de levantamento de estoque foi reorganizada para **espelhar as tabelas do futuro banco**. Assim, o que é preenchido agora já está no formato final.

## 2. Como o app guarda os dados hoje

São três backends Firebase:

| Backend | O que guarda |
|---|---|
| Firestore primário | `users`, `posts`, dados de login |
| Firestore secundário | estoque: `users/{uid}/relatorio`, `relatorio_especifico`, `reposicao`, `descartaveis`, `comandas`, `fabrica_entradas`; mais `lojas` e `configuracoes_loja/{loja}` |
| Realtime Database | vendas (`stores`, `dailySales`) e despesas (`/score/lancamentos/{unidade}/{YYYY-MM}`) |

Formato de um relatório de estoque (snapshot de contagem por loja):

```
{ ID, Nome do usuario, Data:"dd/MM/yyyy HH:mm", Cidade, Loja,
  Categorias:[ { Categoria, Itens:[ {Item, Quantidade, Peso, Qtd Minima, Tipo, Qtd Anterior} ] } ] }
```

### Problemas que dificultam a manipulação

- Tudo é aninhado em arrays dentro de um documento. Somar um item ao longo do tempo exige baixar todos os relatórios e percorrer os arrays no cliente.
- Quantidades são texto (`"0"`, `"2/4"`, `"3 + 150"`). `Peso` é texto e `Tipo` é livre.
- Datas são strings `dd/MM/yyyy HH:mm`, e o ID do documento é a própria data mais a loja. Não dá para filtrar por período no banco.
- O catálogo de itens existe em três lugares: `lib/others/insumos.dart` (hardcoded, 11 categorias), `configuracoes_loja/{loja}.insumos` e o `Qtd Minima` copiado dentro de cada relatório.
- Há UIDs fixos no código (um para estoque, outro para comandas), então o dado é "de um usuário admin" e não da empresa.
- **Não existe controle de matéria-prima da fábrica** (dextrose, glucose, maltodextrina, sorbitol, estabilizante). O `insumos.dart` cobre só o que a loja repõe.
- O app guarda **snapshots**, não movimentação. Não há entrada, saída nem saldo.

## 3. Como estava a planilha original

Arquivo: `Controle de estoque do mes de Agosto de 2026 (hta).xlsx`, com 9 abas de formatos diferentes:

| Aba | Conteúdo |
|---|---|
| `01` (24/08) | contagem de matéria-prima em seções: aberto, FECHADOS, POTES, POTES MENORES, PASTAS |
| `Planilha2`, `3`, `1` | saídas de 25, 26 e 27/08 (a aba 3 tem entradas no rodapé) |
| `Planilha4` | entrada de 28/08 |
| `Planilha5` | congelados de 28/08, várias tabelas lado a lado |
| `Planilha6` | doces de 900g e um rascunho de receita |
| `Planilha7` | descartáveis, limpeza, bebidas e biscoitos de 17/09 |
| `Planilha8` | congelados de 23/09, cerca de 20 blocos lado a lado |

Problemas de qualidade: valores como texto com unidade embutida (`"14,360 Kg"`, `"3 + 150"`), erros de unidade que mudam o valor (`"4902 Kg"` quase certamente é 4,902 kg), nomes diferentes para o mesmo produto (Glucose/Glicose, Açucar/Açúcar, Uva níagra/Niagra), contagem e movimentação misturadas, e várias tabelas por aba.

## 4. Onde a planilha e o app se encontram

| Domínio | App | Planilha |
|---|---|---|
| Matéria-prima da fábrica | não existe | abas 01, 2, 3, 1 e 4 |
| Polpas, bolos, queijos, sorvetes | por loja | estoque central (abas 5 e 8) |
| Descartáveis e limpeza | `descartaveis` | aba 7 |
| Receitas e consumo | não existe | rascunho na aba 6 |
| Entrada, saída e saldo | não existe | abas de entrada e saída |

A planilha descreve o **estoque central/fábrica**, que o app nunca modelou. É aí que o banco novo agrega mais.

## 5. Modelo de dados proposto (Postgres)

```
locations / categories / items (unidade_base: g | ml | un)
item_aliases        -- nomes antigos apontando para o item certo
item_packagings     -- 1 cx / pct / sc = N unidades base
stock_counts + stock_count_lines   -- contagens (snapshots)
stock_movements     -- entrada | saida | ajuste (ledger)
recipes + recipe_lines
replenishment_requests + lines     -- o `reposicao` atual
min_stock, flavors, sales_daily, expenses
```

Decisões principais:

- Toda quantidade vai como **número na unidade base** (g, ml ou un). O texto original fica guardado para auditoria.
- **Contagem e movimentação são tabelas separadas.** Saldo = última contagem + entradas − saídas depois dela.
- Os aliases resolvem a bagunça de nomes na importação.
- O catálogo passa a existir num único lugar.

## 6. O que já foi feito

### 6.1 Planilha no formato do banco

Arquivo: `Estoque - modelo banco.xlsx`

| Aba | Papel |
|---|---|
| `LEIA-ME` | instruções de preenchimento |
| `locais`, `categorias`, `itens` | cadastros; a coluna `chave` do item é calculada |
| `aliases`, `embalagens` | resolução de nomes e conversão de cx/pct/sc |
| `contagens` | data, local, item, quantidade, unidade, estado, observação, texto_original, revisar, qtd_base |
| `movimentos` | igual, com `tipo` = entrada, saida ou ajuste |
| `receitas` | ingredientes por receita |
| `saldo` | calculado por fórmula |

Listas suspensas para item, unidade, local, estado e tipo. A coluna `qtd_base` converte kg, L, cx e pct sozinha.

### 6.2 Dados migrados da planilha antiga

| Aba nova | Linhas | A revisar |
|---|---|---|
| `itens` | 366 | – |
| `contagens` | 397 | 53 |
| `movimentos` | 31 | 14 |
| `receitas` | 8 | todas |
| `embalagens` | 38 | – |
| `aliases` | 27 | – |

Todos os itens usados em contagens e movimentos existem no cadastro. Cada linha migrada mantém o `texto_original`.

### 6.3 Verificações já feitas

- O JSON de credenciais em `scripts/secrets/` está no `.gitignore` e **não é rastreado** pelo git.
- A planilha original não foi alterada.
- Um primeiro erro de leitura nos descartáveis (números de detalhe virando linhas próprias) foi encontrado e corrigido. O arquivo foi restaurado e a migração refeita.

## 7. Passo atual

**Validação da planilha nova pelo usuário.** O que falta conferir:

1. **Abrir no Excel, LibreOffice ou Google Sheets** e confirmar que as fórmulas calculam (`qtd_base` e `saldo`) e que as listas suspensas aparecem. Não foi possível testar as fórmulas durante a criação. `MAXIFS` exige Excel 2019 ou mais novo, ou Google Sheets.
2. **Revisar as linhas marcadas** na coluna `revisar` de `contagens` e `movimentos`:
   - Unidades corrigidas pela leitura mais provável: "0.740 g" lido como 0,74 kg, "4902 Kg" como 4,902 kg, "1600 Kg" como 1,6 kg. **Ainda não confirmado pelo usuário.**
   - Somas como "3 + 150" ficaram com quantidade vazia, porque o significado não é conhecido (caixas mais unidades? pacotes mais gramas?).
   - Pastas da aba 01 ("21 + 33g"): ficou 21 un e o resto foi para a observação.
   - Linhas em branco no original (ex.: Alho, Goiaba) vieram sem quantidade.
3. **Receita de doces:** o título está como "(perguntar título)". As unidades foram assumidas (g, leite em ml, estabilizante 770 g).
4. **Local:** tudo foi lançado em "Fábrica", porque a planilha antiga não informava o local.

## 8. O que falta fazer

1. **Fechar o formato da planilha**, com os ajustes que o usuário pedir.
2. **Escrever o schema SQL (Postgres)**, espelhando as abas da planilha, com chaves, índices e restrições.
3. **Script de importação** da planilha para o banco.
4. **Exportar o Firebase e adaptar para o banco novo:**
   - exportar `relatorio`, `reposicao`, `descartaveis`, `comandas`, `fabrica_entradas`, `lojas` e `configuracoes_loja` com o Admin SDK;
   - exportar vendas e despesas do Realtime Database;
   - converter datas e quantidades de texto para tipos reais;
   - levar o catálogo de `insumos.dart` e `configuracoes_loja` para `itens`;
   - desfazer os arrays aninhados em linhas de contagem.
5. **Definir a camada de acesso do app ao banco.** O app Flutter vai ler e escrever no banco, então é preciso decidir entre uma API, um serviço gerenciado (por exemplo Supabase) ou outra opção, e como fica a autenticação.
6. **Adaptar o app:** trocar as chamadas Firestore das stores (`stock_store`, `comanda_store`, repositórios de vendas e despesas) pela nova camada, e tratar a fila offline atual (`offline_queue`).
7. **Período de convivência:** decidir se o Firebase fica em paralelo durante a transição, e como evitar divergência entre os dois.
8. **Testes e revisão de segurança** antes de ligar o app ao banco novo.

## 9. Decisões em aberto

| Pergunta | Recomendação |
|---|---|
| Qual banco? | Postgres, pela análise em SQL |
| Gerenciado ou próprio? | Gerenciado (ex.: Supabase) reduz o trabalho de autenticação e API |
| O app escreve direto no banco ou via API? | Via API ou serviço gerenciado, nunca com credenciais do banco dentro do app |
| A leitura das unidades corrigidas está certa? | Confirmar com quem fez a contagem |
| O que significam as somas "a + b"? | Definir uma regra única, por exemplo caixas + unidades avulsas |
| Parte do estoque é de lojas, não da fábrica? | Informar os locais corretos |

## 10. Observações

- Os scripts de migração usados estão na pasta temporária da sessão (scratchpad) e **não foram salvos no projeto**. Se forem úteis, devem ser copiados para o repositório (por exemplo `scripts/`) antes de a sessão acabar.
- Nada foi alterado no código do app nem no Firebase.
- Arquivos desta etapa, em `/home/rikelmyso7/Transferências/`:
  - `Controle de estoque do mes de Agosto de 2026 (hta).xlsx` (original, intacto)
  - `Estoque - modelo banco.xlsx` (novo)
  - `Plano - novo banco de estoque.md` (este documento)

---

# Parte 2 — O app orama_fabrica e o novo banco

Data: 02/10/2026 · Projeto analisado: `/home/rikelmyso7/Documentos/orama/orama_fabrica` (Flutter + Firebase, pacote `orama_fabrica2`)

Esta parte trata de uma questão que a Parte 1 não cobria: como o app da fábrica funciona hoje e se ele está alinhado com o banco proposto.

## 11. Os quatro apps e o papel de cada um

| App | Quem usa | O que faz | Relação com o estoque |
|---|---|---|---|
| `orama_lojas` | equipe das lojas | envia relatório de estoque da loja (o que tem e o que falta) | **contagem** (snapshot) por loja |
| `orama_users` | equipe dos PDVs | envia relatório de estoque do PDV (o que tem e o que falta) | **contagem** (snapshot) por PDV |
| `orama_admin` | gestão | vê todos os relatórios de todas as fontes, cria reposições, vendas, despesas e outras funções | consulta tudo e registra as **saídas** (reposição) |
| `orama_fabrica` | equipe da fábrica | dá entrada no estoque da fábrica | registra as **entradas** |

Fluxo de mercadoria que o banco precisa representar:

```
compra de fornecedor ─┐
                      ├─► ENTRADA (orama_fabrica) ─► estoque da FÁBRICA ─► SAÍDA (reposição no orama_admin) ─► LOJA / PDV
produção na fábrica ──┘                                                                                        │
                                                                          contagem (orama_lojas / orama_users) ◄┘
```

Consequência para o modelo: o estoque da fábrica, o das lojas e o dos PDVs são **locais diferentes** (`locations`). Uma reposição é uma **saída** da fábrica, e a mesma mercadoria passa a existir no local de destino. Hoje o app só guarda contagens soltas de loja e entradas soltas da fábrica, sem ligação entre elas.

## 12. Decisões já tomadas (02/10/2026)

| # | Pergunta | Resposta do usuário | Efeito no desenho |
|---|---|---|---|
| 1 | Quem registra a saída da fábrica? | O **orama_admin**, na parte de **reposição** | O orama_fabrica **só dá entrada**. A saída nasce da reposição (`replenishment_requests`) e vira `stock_movements` com `tipo='saida'` no local fábrica. O orama_fabrica não precisa de tela de saída. |
| 2 | Produzir um item baixa insumos automaticamente? | Sim, **no futuro**. Precisa cadastrar as fórmulas antes. Não é prioridade agora | Entra como **fase futura**. O schema já prevê `recipes` e `recipe_lines` (planilha: aba `receitas`), mas nesta fase produção e consumo são lançamentos manuais e separados. Ver seção 16. |
| 3 | O que significam PPC, PTC, PPR, PTR, PPS, PTS? | Lista abaixo | Vira o campo `classe` do item. Ver seção 13. |
| 4 | Os itens E2A/E2B (descartáveis, limpeza etc.) ficam no app da fábrica? | **Sim.** São comprados e armazenados na fábrica, e saem de lá para as lojas. O estoque deles é o da fábrica | Descartáveis, limpeza, uniformes, utensílios e papelaria passam a ser itens do estoque central, com entrada no orama_fabrica e saída por reposição. Isso substitui o conceito de `descartaveis` separado do app atual. Ver seção 14. |
| 5 | Há dados reais em `fabrica_entradas` para migrar? | **Não** | Não há migração do orama_fabrica. O banco começa limpo para entradas. Só o catálogo (`insumos.dart`) precisa ser levado para `items`. |

## 13. Significado da nomenclatura (decisão 3)

Resposta do usuário, na ordem em que foi dada:

| Código | Significado |
|---|---|
| `PPC` | Produto **Pronto** Congelado |
| `PTC` | Produto **Terciário** Congelado |
| `PPR` | Produto **Pronto** Refrigerado |
| `PTR` | Produto **Terciário** Refrigerado |
| `PPS` | Produto **Primário** Seco |
| `PTS` | Produto **Terciário** Seco |

Estrutura do código: `P` + (`P` ou `T`) + (`C`, `R` ou `S`).
- 1ª letra: sempre `P` de Produto.
- 2ª letra: `P` = pronto/primário, `T` = terciário.
- 3ª letra: temperatura de armazenamento — `C` congelado, `R` refrigerado, `S` seco.

Observação: o usuário escreveu "Pronto" para congelado e refrigerado e "Primário" para seco, ambos com a letra `P`. Foi registrado exatamente como informado.

**Confirmado pelo usuário em 02/10/2026:** `PP*` = produzido na fábrica e `PT*` = comprado de terceiros (ver seção 21). Antes da confirmação, o texto era: a diferença entre "pronto/primário" e "terciário". Pelo conteúdo do catálogo, parece que `PP*` são itens feitos pela própria fábrica (baldes, cubas, potes, cookies, pão de queijo, massas, ganaches) e `PT*` são itens de terceiros ou comprados (polpas, descartáveis, limpeza, perecíveis, água, utensílios). Isso é uma **leitura do catálogo, não uma informação do usuário**. Se estiver certa, `PP*` seria "produzido" e `PT*` "comprado", o que responde à pergunta de origem da entrada. Há exceções que precisam de confirmação (ver seção 17).

### Mapeamento no banco

Em vez de guardar o código de 3 letras como texto livre, separar em dois campos em `items`:

| Campo | Valores | Origem |
|---|---|---|
| `nivel` | `pronto` (PP), `primario` (PP seco), `terciario` (PT) | 2ª letra, ajustado conforme a confirmação acima |
| `temperatura` | `congelado`, `refrigerado`, `seco` | 3ª letra |
| `codigo_legado` | `PPC`, `PTR` etc. | guardado só para rastrear o app antigo |

A temperatura define o **local de armazenamento padrão**: `congelado` → E1A, `refrigerado` → E1B, `seco` → E1C.

## 14. Estado atual do orama_fabrica (diagnóstico detalhado)

### 14.1 Estrutura do app

Aproximadamente 3.100 linhas em 22 arquivos Dart. Tem apenas Firebase Auth e Firestore, MobX/Provider/GetStorage declarados e quase sem uso, e nenhum teste.

| Arquivo | Papel |
|---|---|
| `lib/main.dart` | inicia Firebase e define rotas |
| `lib/pages/login/` | login e splash |
| `lib/pages/add_estoque_info.dart` | tela "Nova Entrada": mostra o responsável e três caixas de seleção de estoque |
| `lib/pages/formulario_estoque.dart` | formulário com uma aba por categoria e um cartão por item (campos Entrada, Tipo e Qtd Anterior) |
| `lib/pages/view_fabrica_relatorio.dart` | "Relatórios Específico": lista por estoque, com exclusão |
| `lib/pages/view_fabrica2_relatorio.dart` | "Relatórios Completo": mesma busca, agrupada diferente |
| `lib/others/insumos.dart` | catálogo hardcoded, 17 categorias e 273 itens |
| `lib/utils/changeNotifier.dart` | `EstoqueController`, praticamente sem uso |
| `lib/widgets/my_menu.dart` | menu lateral |

### 14.2 O que é gravado

Caminho: Firestore `oramaloja` → `users/{uid}/fabrica_entradas/{reportId}`. Um documento por envio:

```
{
  ID, Responsável, Data: "dd/MM/yyyy HH:mm", Estoques: ["E1A","E1B"],
  Itens: {
    "<Categoria>": { Itens: [ { Nome, Entrada, Qtd_anterior, estoque_id, nomeclatura, tipo } ] }
  }
}
```

Só entram itens com o campo Entrada preenchido. `Entrada` é texto livre e `tipo` é um dropdown fixo com 12 opções: Balde, Cuba, Pote, Un, g, Tubo, Kg, Fardo, Caixa, Sacos, Litro, Rolo.

### 14.3 Inventário do catálogo (`insumos.dart`)

Contagem feita lendo o arquivo:

| Categoria | Itens | `nomeclatura` | `estoque_id` no catálogo |
|---|---|---|---|
| BALDES | 39 | PPC | E1A |
| CUBAS | 40 | PPC | E1A |
| POTES | 39 | PPC | E1A |
| COOKIES | 7 | PPC | E1A |
| PÃO DE QUEIJO | 2 | PPC | E1A |
| TOPPINGS | 14 | PPC 3, PPR 9, PPS 2 | E1A 3, E1B 9, E1C 2 |
| POLPAS | 20 | PTC | E1A |
| INSUMOS | 13 | PPC 5, PTS 4, PTC 2, PTR 1, PPS 1 | E1A 7, E1B 2, E1C 4 |
| PERECÍVEIS | 15 | PTR | `-` em 14, E1B em 1 |
| MESCLAS | 4 | PTS 1, PTR 3 | `-` |
| ÁGUA | 2 | PTS | `-` |
| SECOS | 6 | PPS | **E2A** |
| DESCARTÁVEIS | 23 | PTS | **E2B** |
| LIMPEZA | 16 | PTS | **E2B** |
| UNIFORMES | 4 | PTS | **E2B** |
| UTENSÍLIOS | 24 | PTS | **E2B** |
| PAPELARIA | 5 | PTS | **E2B** |

### 14.4 Problemas encontrados

Cada item abaixo foi confirmado lendo o código. Referências no formato `arquivo:linha`.

**Bloqueadores de alinhamento com o plano**

1. **Itens de E2A/E2B nunca aparecem no formulário.** A tela de seleção (`add_estoque_info.dart:24`) só oferece `E1A`, `E1B` e `E1C`. O formulário filtra as categorias por `estoquesSelecionados.contains(item['estoque_id'])` (`formulario_estoque.dart:223`). Como nenhuma tela seleciona `E2A` ou `E2B`, as categorias **SECOS, DESCARTÁVEIS, LIMPEZA, UNIFORMES, UTENSÍLIOS e PAPELARIA (78 itens) são inalcançáveis**. Pela decisão 4, esses itens precisam ser lançados no app da fábrica.
2. **Itens com `estoque_id: "-"` só aparecem por acaso.** PERECÍVEIS (14), MESCLAS (4) e ÁGUA (2) têm `-`. Uma categoria só aparece se algum item dela casar com o estoque escolhido. PERECÍVEIS aparece apenas por causa do item `QUEIJO MINAS FRESCAL` (E1B), e o formulário mostra todos os itens da categoria quando isso acontece. MESCLAS e ÁGUA nunca aparecem.
3. **Dois sistemas de classificação que não concordam.** O formulário filtra por `estoque_id` (`E1A`, `E1B`, `E1C`, `E2A`, `E2B`). A tela de relatórios ignora `estoque_id` e classifica pela `nomeclatura` (`view_fabrica_relatorio.dart:114-128`): PPC/PTC → E1A, PPR/PTR → E1B, PPS/PTS → E1C. Na tela de relatórios, descartáveis e limpeza (E2B, PTS) são mostrados como "E1C — Secos", o que é inconsistente com o catálogo.
4. **Não existe matéria-prima.** Nenhuma categoria cobre dextrose, glucose, maltodextrina, sorbitol, estabilizante e os demais insumos de produção da planilha. A categoria `INSUMOS` do app tem 13 itens (carne seca, queijo, pernil, margarina, massa de tapioca etc.), de produtos de lanche, não de sorvete.
5. **Só entrada.** Não há saída, ajuste, estorno nem saldo. Isso agora é intencional (decisão 1), mas significa que o app nunca poderá mostrar saldo sozinho. O saldo só existirá no banco, combinando entradas deste app com saídas do orama_admin.
6. **Não distingue produção de compra.** Um balde produzido e uma caixa de copos comprada geram o mesmo registro. Falta `origem` e `fornecedor`.
7. **Quantidade e unidade sem tipo.** `Entrada` é `String` sem validação (`formulario_estoque.dart:127`). A unidade vem de um dropdown solto (linhas 291-304), com o padrão `Un`, e itens com `tipo: '-'` caem em `Un` (linha 308-310). "1 Caixa" ou "2 Fardo" não têm conversão para unidade base.
8. **Catálogo em quarto lugar.** Além de `insumos.dart` do orama_admin, de `configuracoes_loja.insumos` e do `Qtd Minima` nos relatórios (Parte 1, seção 2), o orama_fabrica tem **seu próprio `insumos.dart`**, com estrutura diferente (`nome`, `estoque_id`, `nomeclatura`, `tipo`). Um item novo exige alterar o código e publicar o app.

**Defeitos de comportamento**

9. **"Qtd Anterior" é calculada de forma errada.** `_fetchPreviousQuantities` ordena por `Data` (`formulario_estoque.dart:194`), que é uma string `dd/MM/yyyy HH:mm`. Ordenar texto nesse formato ordena pelo dia do mês primeiro, então o "último" relatório pode não ser o mais recente. Além disso mostra a `Entrada` anterior como se fosse quantidade anterior, e a consulta é filtrada só pelo usuário logado, de modo que a entrada de outro funcionário não aparece.
10. **Excluir apaga o histórico.** `_deleteReport` remove o documento do Firestore (`view_fabrica_relatorio.dart:190`). Num ledger de movimentação, um erro deve ser corrigido por um movimento de estorno, não por exclusão. A exclusão de um relatório inteiro também impede auditar quem lançou o quê.
11. **Dados presos a uma pessoa.** O registro fica em `users/{uid}`, então pertence ao usuário que lançou. O orama_admin precisa de uma consulta `collectionGroup` para ler tudo (`view_fabrica_repo.dart:53`).
12. **Identidade e segurança.** UIDs fixos para traduzir o nome do responsável (`view_fabrica_relatorio.dart:52-58`: Betânia, Leticia, Evelyn) e nomes de lojas no menu (`my_menu.dart`: Paineiras, Itupeva, Retiro) em um app de fábrica, herança do orama_lojas. Alguém sem UID na lista aparece como "Usuário desconhecido".
13. **Sem fila offline.** Se o celular da fábrica estiver sem sinal ao salvar, a entrada se perde (o `catch` só mostra "Erro ao salvar"). O orama_lojas tem `offline_queue`; este app não.
14. **Sem confirmação nem validação.** Ao tocar em salvar, grava direto. Não há resumo antes de enviar, nem aviso para valor negativo, zero ou absurdo.
15. **Código duplicado e morto.** As duas telas de relatório repetem a busca e a classificação. `EstoqueController` é criado no `build` mas os controllers realmente usados são locais. Há 14 `print` de depuração com emoji. O `pubspec` tem pacotes `syncfusion_*` sem versão e um `dependency_overrides` suspeito (`path_provider_android: null`).

**Correção de uma conclusão anterior.** A primeira versão desta análise dizia que havia colisão de chaves entre itens de mesmo nome em Baldes e Polpas. Isso está **errado**: `_generateKey` (`formulario_estoque.dart:96`) prefixa a categoria para BALDES, CUBAS e POTES, e uma checagem em todo o catálogo não encontrou nenhuma chave duplicada. Não é problema.

### 14.5 O que já está certo e pode ser aproveitado

- Fluxo de duas telas (escolher onde → preencher itens por aba) é simples para a equipe da fábrica.
- Os três estoques E1A, E1B e E1C e o prefixo E2 já expressam a ideia de **locais** dentro da fábrica.
- Quem lançou e quando já são guardados (`Responsável`, `Data`), só falta o tipo certo.
- A nomenclatura de 3 letras (seção 13) carrega informação útil e pode virar campos do catálogo.
- Telas de histórico com filtro por estoque.

## 15. Como o orama_fabrica deve funcionar com o banco novo

### 15.1 Princípio

O app passa a registrar **movimentos de entrada** em `stock_movements`. Ele não calcula saldo. O saldo é do banco.

### 15.2 Entidades que o app usa

| Tabela | Uso no orama_fabrica |
|---|---|
| `items` | catálogo, lido do banco em vez de `insumos.dart`. Campos novos: `nivel`, `temperatura`, `codigo_legado`, `local_padrao_id` |
| `categories` | abas do formulário |
| `locations` | onde o item entra: E1A, E1B, E1C, E2A, E2B (ou equivalente com nome legível) |
| `item_packagings` | converte Caixa, Fardo, Saco, Balde etc. em unidade base |
| `item_aliases` | resolve nomes antigos |
| `stock_movements` | grava cada entrada |
| `suppliers` (**nova**) | fornecedores, para entradas de compra |
| `profiles` ou equivalente | usuário que lançou, em vez de UID fixo |

### 15.3 Campos de uma entrada em `stock_movements`

| Campo | Tipo | Observação |
|---|---|---|
| `id` | uuid | gerado no app, o que permite reenviar sem duplicar |
| `tipo` | enum | `entrada` neste app. `saida` vem do orama_admin. `ajuste` fica para a gestão |
| `ocorrido_em` | timestamptz | substitui a string `dd/MM/yyyy HH:mm` e o ajuste manual de fuso |
| `item_id` | fk | não mais o nome do item |
| `local_id` | fk | onde o item entra |
| `quantidade` | numeric | número digitado, como foi digitado |
| `unidade` | enum | unidade usada na digitação |
| `qtd_base` | numeric | calculada: g, ml ou un |
| `origem` | enum | `producao`, `compra`, `devolucao`, `ajuste`, `outro` |
| `fornecedor_id` | fk, nulo | só em `compra` |
| `documento` | texto, nulo | número da nota fiscal ou pedido |
| `lote` e `validade` | texto e data, nulos | úteis para perecíveis e congelados; ver seção 17 |
| `usuario_id` | fk | quem lançou |
| `lote_envio_id` | uuid | agrupa os itens salvos na mesma tela, para exibir como "relatório" |
| `estorna_id` | fk, nulo | aponta para o movimento corrigido, em lugar de excluir |
| `texto_original` | texto | o que foi digitado, para auditoria (já existe na planilha) |
| `criado_em` | timestamptz | horário do servidor, diferente de `ocorrido_em` |

`origem` é o campo que separa **produzido na fábrica** de **comprado**, e responde ao pedido original do usuário. Pela leitura da seção 13, o valor padrão pode ser sugerido pelo `nivel` do item (pronto/primário → `producao`, terciário → `compra`), mas o funcionário pode trocar.

### 15.4 Fluxo da nova tela de entrada

1. Escolher o **local** (substitui "Estoques"). Incluir E2A e E2B.
2. Escolher a **origem**: produção ou compra. Se compra, escolher o fornecedor (opcional no início).
3. Preencher os itens por categoria. Cada cartão tem quantidade numérica, unidade vinda das embalagens cadastradas do item e, quando possível, mostra o saldo atual lido do banco.
4. **Resumo antes de salvar**, com a lista do que será lançado.
5. Salvar com **fila offline**: grava local, envia quando houver sinal, usando o `id` do movimento para evitar duplicata.
6. Correção de erro por **estorno** (um novo movimento ligado ao original), nunca exclusão.

### 15.5 Relação com o orama_admin (saída)

- A reposição criada no orama_admin vira `replenishment_requests` e `replenishment_request_lines`.
- Quando a fábrica envia, o orama_admin registra o movimento de **saída** da fábrica para cada linha, ligado à reposição (`replenishment_request_id` em `stock_movements`).
- Quando a loja ou o PDV confirmar o recebimento, entra no estoque de destino. Isso permite comparar o que saiu com o que a loja contou, tema para a Parte 1, seção 8.
- O orama_fabrica só precisa **ler** o saldo para mostrar ao funcionário.

### 15.6 Segurança

- O app **não** usa credenciais do banco. Usa uma API ou serviço gerenciado (Parte 1, seção 9).
- Perfis de acesso: funcionário da fábrica pode inserir entradas e estornar as próprias; gestão pode ajustar; somente leitura para os demais.
- Remover UIDs fixos. Nome do usuário vem do cadastro.

## 16. Fórmulas e baixa automática de insumos (fase futura)

Registrado como pedido do usuário, **fora do escopo desta fase**.

- Cada item produzido (balde, cuba, pote, cookie, massas etc.) terá uma **fórmula**: lista de insumos com quantidade por lote.
- Ao registrar a produção, o sistema gera uma **entrada** do produto pronto e **saídas** dos insumos consumidos, no mesmo lote (`lote_envio_id`), com `origem='producao'`.
- Pré-requisito: cadastrar as fórmulas. O schema já tem `recipes` e `recipe_lines`, e a planilha tem a aba `receitas` com 8 linhas migradas, todas ainda para revisar.
- Perguntas que só serão respondidas quando essa fase começar: rendimento por lote, perdas e sobras, variação por sabor, e se o consumo é abatido na hora ou ao fechar o dia.
- Por enquanto: a fábrica lança a entrada do produto, e o consumo de insumo é lançado à mão como `ajuste` ou nem é lançado.

## 17. Perguntas em aberto sobre o orama_fabrica

1. ~~Confirmar o significado de "terciário"~~ **Respondida (seção 21):** sim.
   Pergunta original: significado de "terciário" (seção 13). Terciário é "comprado de terceiros" e pronto/primário é "feito na fábrica"? Isso decide o `origem` sugerido.
2. ~~Exceções no catálogo.~~ **Adiada pelo usuário:** será corrigido depois, se necessário.
   Texto original: **Exceções no catálogo.** Alguns itens têm código que não combina com a leitura acima, por exemplo `CARNE SECA`, `FRANGO DESFIADO` e `PERNIL` como `PPC` (feitos na fábrica?) e `MASSA DE TAPIOCA` como `PTC` com unidade `Kg`. `AMENDOAS` é `PPS`. Preciso que alguém confira a lista.
3. ~~Itens sem local~~ **Respondida (seção 21):** usar a temperatura.
   Texto original: **O que fazer com os itens sem local** (`estoque_id: "-"`): PERECÍVEIS (14), MESCLAS (4) e ÁGUA (2). A nomenclatura aponta refrigerado ou seco. Usar a temperatura como local padrão?
4. ~~Locais E2A e E2B~~ **Respondida (seção 21):** são 3 locais físicos; E2A e E2B não existem como locais.
   Texto original: **Locais E2A e E2B.** Hoje E2A tem só SECOS (bolachinhas, cones) e E2B tem descartáveis, limpeza, uniformes, utensílios e papelaria. São prateleiras ou salas diferentes de E1C? Ou tudo é "seco"?
5. **Utensílios e equipamentos** (caixa de som JBL, máquina de café, liquidificador, estufa de casquinhas). São bens duráveis, não consumo. Devem entrar no estoque de reposição ou ficar em outro controle (patrimônio)? Hoje estão na mesma lista.
6. **Uniformes e itens de papelaria.** Têm tamanhos ou variações (camiseta P, M, G)? O catálogo atual não tem.
7. **Unidade de entrada de produto pronto.** Um balde conta como 1 un, ou como a quantidade de litros/gramas? A planilha trabalha em g e ml. A conversão precisa do peso padrão de balde, cuba e pote por sabor.
8. **Lote e validade** para congelados e refrigerados. Hoje não existe. Se for necessário (rastreabilidade ou FEFO), deve entrar já no formulário de entrada, porque depois é difícil completar.
9. **Fornecedores.** Há uma lista? Lançar fornecedor em toda compra é obrigatório ou opcional?
10. **Quem pode estornar e ajustar.** Funcionários da fábrica, só gestão, ou ambos?
11. **Itens que a fábrica produz para venda direta** (cookies, pão de queijo, que têm `estoque_id: E1A`): saem para loja pela reposição como os demais?

## 18. Itens a acrescentar ao plano da Parte 1

Alterações propostas para as seções 5, 8 e 9 da Parte 1 (ainda não aplicadas ao schema):

**Schema (seção 5)**
- `items`: adicionar `nivel`, `temperatura`, `codigo_legado`, `local_padrao_id`.
- `stock_movements`: adicionar `origem`, `fornecedor_id`, `documento`, `lote`, `validade`, `usuario_id`, `lote_envio_id`, `estorna_id`, `replenishment_request_id`.
- Nova tabela `suppliers`.
- `locations`: tipo `fabrica`, `loja` e `pdv`, com sublocais E1A, E1B, E1C, E2A, E2B (ou decidir pela pergunta 4).
- `replenishment_requests`: ligar a `stock_movements` de saída.

**Tarefas (seção 8)**
- Item novo: **ajustar a planilha** `Estoque - modelo banco.xlsx` com as colunas `origem`, `nivel`, `temperatura` e a aba `fornecedores`.
- Item novo: levar o `insumos.dart` do orama_fabrica para a aba `itens`, com os códigos separados.
- Item novo: **adaptar o orama_fabrica** (seção 14 e 15) — tela de local e origem, catálogo vindo do banco, quantidade numérica, resumo, fila offline, estorno, e incluir os locais E2A e E2B.
- Item novo: **adaptar a reposição do orama_admin** para gerar a saída.
- Não é necessário migrar `fabrica_entradas` (decisão 5).

**Decisões em aberto (seção 9)**
- Acrescentar as perguntas 1 a 11 da seção 17.

## 19. Ordem sugerida de trabalho

1. Responder as perguntas 1 a 4 da seção 17, que mudam o schema.
2. Atualizar o schema e a planilha (seção 18).
3. Levar o catálogo do orama_fabrica para `itens`, separando `nivel` e `temperatura`.
4. Criar API ou serviço gerenciado e o login (Parte 1, seção 8, item 5).
5. Adaptar o orama_fabrica (entrada) e o orama_admin (saída pela reposição).
6. Depois que o fluxo básico estiver rodando, tratar fórmulas e baixa automática (seção 16).

## 20. Observações

- Nada foi alterado no código de nenhum app nem no Firebase. Esta parte é só análise e registro.
- A análise do orama_fabrica foi feita lendo o código. O app não foi executado e não houve acesso aos dados do Firebase (e o usuário informou que não há dados a migrar).
- Os números do catálogo (seção 14.3) foram contados lendo `insumos.dart`, não vieram de estimativa.

---

## 21. Respostas de 02/10/2026 (rodada 2) e o que mudam

### 21.1 Respostas

| Pergunta (seção 17) | Resposta do usuário | Situação |
|---|---|---|
| 1. "Terciário" = comprado de terceiros e "pronto/primário" = feito na fábrica? | **Sim** | Confirmado |
| 2. Exceções de código no catálogo (Carne Seca, Frango, Pernil etc.) | "Não se preocupe com isso, qualquer coisa corrijo depois" | Adiada. Importar o catálogo como está |
| 3. Itens sem local (`-`): usar a temperatura? | "temperatura?" (escrito com interrogação, lido como confirmação da sugestão) | **Assumido sim.** Se a intenção era outra, avisar |
| 4. E2A e E2B são locais diferentes de E1C? | Há **3 lugares de armazenamento**: câmara frigorífica (congelados), geladeira (refrigerados) e secos em outro lugar | Respondida |

### 21.2 Origem da entrada (efeito da resposta 1)

| Nível | Significado | `origem` sugerida na entrada |
|---|---|---|
| `PP*` (pronto/primário) | produzido pela fábrica | `producao` |
| `PT*` (terciário) | comprado de terceiros | `compra` |

O funcionário continua podendo trocar o valor sugerido (por exemplo, uma devolução). Isso resolve a distinção pedida no início: entrada de "coisas produzidas na fábrica" e de "insumos comprados".

### 21.3 Locais físicos (efeito da resposta 4)

São **três** locais na fábrica, determinados pela temperatura:

| Local | Armazena | Temperatura | Códigos legados |
|---|---|---|---|
| Câmara frigorífica | congelados | `congelado` | `E1A`, códigos `PPC`, `PTC` |
| Geladeira | refrigerados | `refrigerado` | `E1B`, códigos `PPR`, `PTR` |
| Secos (outro lugar) | secos | `seco` | `E1C`, `E2A`, `E2B`, códigos `PPS`, `PTS` |

Consequências:

- `locations` da fábrica tem **3 registros**, não 5. `E2A` e `E2B` deixam de existir como local e ficam só como `codigo_legado` para rastrear o catálogo antigo, todos apontando para o local Secos.
- A **temperatura do item define o local padrão**. Não é mais preciso o funcionário escolher o estoque antes de preencher, embora a tela possa continuar permitindo filtrar por local.
- Isso encerra o problema 3 da seção 14.4 (dois sistemas de classificação): a única fonte de verdade passa a ser `items.temperatura`. A tela de relatórios atual, que já mostra PTS como "E1C - Secos", ficava coerente com isso e era o `estoque_id` do catálogo (`E2A`/`E2B`) que estava fora do padrão.
- Também encerra o problema 1 (78 itens inalcançáveis) sem precisar criar locais novos: os itens de E2A/E2B passam a ser mostrados no local Secos.
- Os itens com `estoque_id: "-"` ficam resolvidos pela nomenclatura:

| Categoria | Itens | Código | Local resultante |
|---|---|---|---|
| PERECÍVEIS | 15 | PTR | Geladeira |
| MESCLAS | 4 | PTS 1, PTR 3 | Secos 1, Geladeira 3 |
| ÁGUA | 2 | PTS | Secos |

Itens como `CARNE SECA`, `FRANGO DESFIADO` e `PERNIL` (código PPC) caem na câmara frigorífica pelo código, mesmo que o nome sugira outra coisa. Fica como está até o usuário corrigir (resposta 2).

### 21.4 Alterações ao que foi proposto na seção 18

| Antes | Agora |
|---|---|
| `locations` da fábrica com E1A, E1B, E1C, E2A, E2B | 3 locais: Câmara frigorífica, Geladeira, Secos |
| `items.local_padrao_id` como campo separado | derivado de `temperatura`; o campo pode ser removido ou mantido só como cache |
| Tela de entrada pergunta o local antes | o local vem do item; escolher local passa a ser filtro opcional |
| `nivel`: `pronto`, `primario`, `terciario` | pode ficar `producao` / `terceiros`, já que o usuário confirmou a leitura. Decidir o nome final ao escrever o schema |

### 21.5 Perguntas que continuam em aberto (seção 17, itens 5 a 11)

5. Utensílios e equipamentos (JBL, máquina de café, liquidificador) são consumo ou patrimônio?
6. Uniformes e papelaria têm tamanhos ou variações?
7. Unidade de entrada de produto pronto (balde, cuba, pote) e peso padrão por sabor.
8. Lote e validade para congelados e refrigerados.
9. Lista de fornecedores e se é obrigatório informar.
10. Quem pode estornar e ajustar.
11. Cookies e pão de queijo saem para a loja pela reposição como os demais?

Nenhuma delas bloqueia o schema. As de número 7 e 8 são as que mais custam se forem decididas depois.

**Atualização:** as perguntas 5 a 11 foram respondidas na seção 22.

---

## 22. Respostas de 02/10/2026 (rodada 3): perguntas 5 a 11

### 22.1 Resumo das respostas

| # | Tema | Resposta do usuário | Decisão registrada |
|---|---|---|---|
| 5 | Utensílios e equipamentos | "Estes itens também ficam em estoque e são direcionados à loja" | Ficam no estoque normal, com entrada na fábrica e saída por reposição. **Não há controle de patrimônio separado.** |
| 6 | Uniformes e papelaria | "Adicione variações de tamanho" | Item passa a ter **variações** (tamanho). Ver 22.3 |
| 7 | Unidade de produto pronto | "Melhor adicionar em g" | Baldes, cubas e potes são lançados em **gramas**. Ver 22.4 |
| 8 | Lote e validade | "Adicione também" | Campos `lote` e `validade` entram no formulário de entrada. Ver 22.5 |
| 9 | Fornecedores | "Pode ser melhoria" | Fica para **fase futura**. Ver 22.6 |
| 10 | Quem estorna e ajusta | "Definir uma senha de adm para isso" | Estorno e ajuste exigem **senha de administrador**. Ver 22.7 |
| 11 | Cookies e pão de queijo | "Saem da mesma forma que balde e cubas" | Saem pela reposição, como os demais. Nenhuma mudança de modelo |

### 22.2 Utensílios e equipamentos (resposta 5)

- O catálogo de UTENSÍLIOS (24 itens, incluindo caixa de som JBL, máquina de café, liquidificador e estufa de casquinhas) segue como item de estoque do local Secos, com `origem='compra'`.
- Sem tabela de patrimônio. A saída para a loja é uma reposição como qualquer outra.
- Consequência: um equipamento enviado à loja **sai** do saldo da fábrica e **entra** no local da loja. O orama_lojas só mostra equipamentos na contagem se o item existir no catálogo da loja. A Parte 1 não cobre isso; fica anotado para a seção de reposição.

### 22.3 Variações de tamanho (resposta 6)

O usuário pediu variações de tamanho. Os tamanhos de cada item não foram informados, então **a lista de itens e rótulos a cadastrar fica em aberto**. A planilha nova deve trazer a aba vazia para preencher.

| Tabela | Campos |
|---|---|
| `item_variants` (nova) | `id`, `item_id`, `rotulo`, `ativo` |
| `stock_movements` | adicionar `variante_id` (nulo) |
| `stock_count_lines` | adicionar `variante_id` (nulo) |
| `replenishment_request_lines` | adicionar `variante_id` (nulo) |

Regras:
- Item sem variações continua como hoje, com `variante_id` nulo.
- Item com variações exige escolher a variação em toda entrada, saída e contagem.
- O saldo é calculado por `(item_id, variante_id, local_id)`.
- Serve para qualquer item, não só uniformes e papelaria. Candidatos no catálogo: `CAMISETA`, `AVENTAL JEANS`, `TOUCA`, `LUVAS`. É uma sugestão minha, não do usuário.
- Na tela do orama_fabrica, o cartão do item mostra um seletor de variação, ou uma linha por variação.

### 22.4 Quantidade em gramas para produto pronto (resposta 7)

Decisão: baldes, cubas e potes são lançados em **g**. Interpretação adotada (**a confirmar**): o funcionário **digita o peso**, e `unidade_base` desses itens é `g`.

Efeitos:
- Resolve a pergunta do peso padrão por sabor, porque o peso real é o que vale.
- `item_packagings` de Balde, Cuba e Pote pode ficar vazio. Se quiserem digitar "2 baldes" no futuro, basta cadastrar o peso padrão da embalagem.
- O dropdown `tipo` do app atual (Balde, Cuba, Pote...) deixa de ser a unidade de lançamento desses itens. g e Kg continuam, e Kg é convertido para g em `qtd_base`.
- A tela deve avisar para valores fora do esperado, para evitar o erro de unidade da planilha antiga ("4902 Kg" lido como 4,902 kg). Os limites precisam ser definidos.
- Em aberto: a mesma regra vale para polpas, toppings e demais itens hoje contados em "Un"? A resposta foi dada sobre produto pronto, e polpas (PTC, 20 itens) ficaram sem definição.

### 22.5 Lote e validade (resposta 8)

Campos `lote` (texto) e `validade` (data) entram em `stock_movements` (já previstos na seção 15.3) e no formulário de entrada.

O usuário ainda não definiu os pontos abaixo. As sugestões são minhas:

| Ponto | Sugestão (não confirmada) |
|---|---|
| Obrigatório ou opcional? | Obrigatório para congelados e refrigerados, opcional para secos |
| Lote gerado como? | Itens `PP*`: automático, `AAAAMMDD` + sequência do dia. Itens `PT*`: digitar o lote da embalagem ou da nota |
| Como o saldo trata o lote? | Saldo por `(item, variação, local, lote)` |
| Como a saída escolhe o lote? | Automático por menor validade primeiro (FEFO), com opção de trocar |

Isso afeta o orama_admin: a saída da reposição precisa informar de qual lote saiu, ou o sistema escolhe por FEFO. Fica como ponto de design ao adaptar a reposição.

Itens sem validade (descartáveis, limpeza, utensílios, uniformes, papelaria) devem poder ficar sem o campo. Por isso a regra é **por item**: `items.controla_validade` (booleano).

Opcional: tabela `stock_lots` (`id`, `item_id`, `variante_id`, `lote`, `validade`) para não repetir o par em cada movimento. Decidir ao escrever o schema.

### 22.6 Fornecedores (resposta 9)

**Melhoria futura.**
- A tabela `suppliers` não é obrigatória na primeira versão.
- `fornecedor_id` e `documento` ficam em `stock_movements` como colunas opcionais e nulas, para não alterar a tabela depois.
- Nenhuma tela de cadastro de fornecedor agora.

### 22.7 Estorno e ajuste com senha de administrador (resposta 10)

Decisão do usuário: exigir **senha de administrador** para estornar e ajustar.

Recomendações de segurança (não foram decididas pelo usuário):

| Risco | Recomendação |
|---|---|
| Senha verificada **dentro do app** pode ser extraída do aplicativo | Verificar **no servidor**: o app envia, o servidor confere e autoriza. Nunca gravar a senha no código ou no `GetStorage` |
| Senha única compartilhada impede saber quem estornou | Preferir um papel de administrador por pessoa. Se for senha única, exigir também o usuário logado e registrar `autorizado_por` |
| Tentativas repetidas | Limitar tentativas e bloquear temporariamente |
| Estorno sem motivo | Campo `motivo` obrigatório |

Fluxo proposto:
1. Funcionário toca em "Corrigir" em uma entrada.
2. O app pede a senha de administrador.
3. O servidor confere e cria um novo movimento com `estorna_id` apontando para o original, `motivo`, `usuario_id` e `autorizado_por`.
4. O movimento original **não é apagado nem alterado**.

Campos novos em `stock_movements`: `motivo` e `autorizado_por`. O botão excluir do orama_fabrica, que hoje apaga o documento sem restrição (`view_fabrica_relatorio.dart:190`), deixa de existir.

### 22.8 Cookies e pão de queijo (resposta 11)

Saem pela reposição, como baldes e cubas. Nenhum campo novo. Como são `PPC`, a entrada vem com `origem='producao'`.

### 22.9 Impacto na planilha e no schema

| Alteração | Onde |
|---|---|
| Aba `variacoes` (item, rótulo, ativo) | planilha e `item_variants` |
| Coluna `variante` em `contagens` e `movimentos` | planilha e `variante_id` |
| Colunas `lote` e `validade` em `movimentos` | planilha e `stock_movements` |
| Coluna `controla_validade` em `itens` | planilha e `items` |
| Colunas `origem`, `nivel` e `temperatura` | planilha, conforme seções 15.3 e 21 |
| `motivo`, `autorizado_por` e `estorna_id` em movimentos | schema |
| `unidade_base = g` para BALDES, CUBAS e POTES | `itens` |
| Aba `fornecedores` fora da primeira versão | decisão 9 |
| Locais da fábrica: Câmara frigorífica, Geladeira, Secos | `locais` (seção 21.3) |

### 22.10 Perguntas que continuam em aberto

1. Quais itens têm variação de tamanho e quais são os rótulos.
2. Confirmar a leitura de 22.4 (digitar o peso em g) e se polpas, toppings e demais itens em "Un" também passam para g.
3. Obrigatoriedade e geração do lote, e se a saída da reposição escolhe lote por FEFO.
4. Senha de administrador: conta por pessoa ou senha única, e verificação no servidor, que depende da camada de acesso ao banco (Parte 1, seção 8, item 5).
5. Limites de aviso de peso por tipo de item.

Nenhuma delas impede escrever o schema e adaptar a planilha.

---

# Parte 3 — Implementação (início, 02/10/2026)

Pedido do usuário: "por enquanto comece a implementar, depois vou ajustando o que precisar". Foi implementado o que **não depende** das decisões ainda abertas: schema, semente do catálogo e planilha. **Nenhum app foi alterado** e o Firebase não foi tocado, porque a camada de acesso ao banco ainda não foi escolhida (seção 8, item 5).

## 23. O que foi criado

Os arquivos de código estão em `orama_admin/db/` (nada foi commitado). A planilha nova está em `~/Transferências/`.

| Arquivo | Para quê |
|---|---|
| `db/schema.sql` | Schema PostgreSQL completo, com restrições, gatilhos e views |
| `db/tests/schema_test.sql` e `db/tests/run.sh` | Testes do schema em um Postgres descartável (Docker). Rodar com `bash db/tests/run.sh` |
| `db/tools/gen_seed_fabrica.py` | Converte o `insumos.dart` do orama_fabrica para o modelo novo |
| `db/seed/001_locais.sql` | 3 locais da fábrica (gerado) |
| `db/seed/002_catalogo_fabrica.sql` | 17 categorias e 273 itens (gerado) |
| `db/tools/build_planilha_v2.py` | Gera a planilha nova a partir da original |
| `~/Transferências/Estoque - modelo banco v2.xlsx` | Planilha nova. A original ficou **intacta** (conferido por hash) |

## 24. Schema (`db/schema.sql`)

Tabelas: `locations`, `profiles`, `categories`, `items`, `item_aliases`, `item_packagings`, `item_variants`, `suppliers`, `stock_counts`, `stock_count_lines`, `stock_movements`, `replenishment_requests`, `replenishment_request_lines`, `recipes`, `recipe_lines`. Views: `v_saldo` e `v_saldo_lote`.

Regras que o próprio banco garante:

| Regra | Como |
|---|---|
| Quantidade sempre numérica na unidade base | `fn_qtd_base` converte kg→g, L→ml e embalagens cadastradas, e **rejeita** unidade incompatível (por exemplo "L" em item em gramas) em vez de gravar valor errado |
| Ledger imutável | gatilhos bloqueiam alteração, exclusão e limpeza total da tabela `stock_movements` |
| Erro se corrige com estorno | `estorna_id` exige tipo oposto e mesmo item, variação, local e quantidade, mais `motivo` e `autorizado_por`. Um movimento só pode ser estornado uma vez |
| Ajuste exige motivo e autorizador | restrição `CHECK`. Só o ajuste pode ter quantidade negativa |
| Reenvio não duplica | `id` do movimento é gerado pelo app |
| Variações obrigatórias | item com variações ativas exige `variante_id`, e a variação precisa ser do item |
| Local da fábrica por temperatura | `locations.temperatura` só existe para tipo `fabrica` |
| Saldo | `v_saldo` = última contagem + entradas − saídas + ajustes depois dela, por item, variação e local. `v_saldo_lote` calcula por lote só com movimentos |

Nomes finais escolhidos onde o plano deixava em aberto: `nivel` = `producao` / `terceiros`, e `origem` = `producao`, `compra`, `devolucao`, `ajuste`, `reposicao`, `outro`.

**O schema NÃO define** permissões (RLS e GRANTs). Isso depende de provedor de login e camada de acesso, e a senha de administrador (seção 22.7) precisa ser verificada no servidor. Está comentado no cabeçalho do arquivo.

### Testes

Suíte em `db/tests/schema_test.sql`: conversão de unidades, imutabilidade, estorno (6 casos), ajuste, variações, saldo com e sem contagem, lote estornado, reposição e restrições de cadastro. Passa contra Postgres 16 junto com as sementes.

Como a primeira execução passou de primeira, foi feito um **teste de mutação**: removendo o gatilho de imutabilidade de uma cópia, a suíte falhou como esperado ("esperava falha com 'imutável'"). Isso confirma que os testes detectam a regra, e não apenas passam. Só essa regra foi testada por mutação; as demais não.

## 25. Semente do catálogo do orama_fabrica

273 itens em 17 categorias, lidos de `insumos.dart`:

| | |
|---|---|
| Por temperatura | congelado 157, seco 88, refrigerado 28 |
| Por nível | producao 153, terceiros 120 |
| Por unidade base | g 134, un 134, ml 5 |

Regras aplicadas:
- `PP*` → `producao`, `PT*` → `terceiros`. A terceira letra define a temperatura.
- Baldes, cubas e potes (118 itens) em **g**, conforme a decisão 7. Os demais seguem o `tipo` do app: `Un`→un, `g` e `Kg`→g, `Litro`→ml.
- Itens que o app contava em caixa, fardo, saco, rolo ou tubo ficaram em **un**, sem embalagem cadastrada, porque o fator de conversão não existe em lugar nenhum. O arquivo da semente lista quais são, ao final, em comentário. Até cadastrar em `item_packagings`, o banco **recusa** lançamento em caixa desses itens.
- `controla_validade = true` para congelados e refrigerados. **É a sugestão da seção 22.5, não uma decisão do usuário.** É um campo por item e dá para ajustar.
- Itens `-` (sem local) e códigos estranhos (Carne Seca etc.) foram importados como estão, conforme a resposta 2.

## 26. Planilha nova (`Estoque - modelo banco v2.xlsx`)

Colunas novas sempre **no fim** de cada aba, para não deslocar as fórmulas:

| Aba | Acrescentado |
|---|---|
| `locais` | `temperatura`, `codigos_legado`; Câmara frigorífica, Geladeira, Secos. Mantido o local `Fábrica` (legado), porque os dados migrados usam esse nome |
| `categorias` | +13 do orama_fabrica |
| `itens` | `nivel`, `temperatura`, `codigo_legado`, `controla_validade`; +273 itens (total 639) |
| `contagens` | `variante` |
| `movimentos` | `origem`, `variante`, `lote`, `validade` |
| `variacoes` | aba nova, vazia (tamanhos ainda não informados) |
| `LEIA-ME` | instruções das colunas novas |

### Defeitos da planilha antiga encontrados e corrigidos

| Defeito | Efeito | Correção |
|---|---|---|
| Fórmula de `qtd_base` em `contagens` parava na linha 301, mas havia dados até a 398 | **97 contagens estavam fora do saldo** | fórmula preenchida até a linha 2000 |
| Listas suspensas de item, local e unidade cobriam só 300 linhas (itens e movimentos) | itens além do 300º não apareciam na lista | ampliadas para 1000 e 2000 linhas |
| Aba `saldo` tinha 300 linhas para 366 itens | 66 itens ficavam sem saldo | 1000 linhas |
| Aba `locais` vazia | lista suspensa de local sem opções | preenchida |

Verificação de regressão: nas colunas originais de `itens`, `movimentos`, `embalagens`, `aliases` e `receitas` há **0 diferenças** em relação à planilha antiga. Em `contagens` as 97 diferenças são exatamente a fórmula que estava faltando.

**Limitação:** as fórmulas não foram recalculadas, porque não há LibreOffice nesta máquina. Falta abrir a planilha no Excel (2019 ou mais novo), LibreOffice ou Google Sheets e conferir `qtd_base` e `saldo`.

Limitação do `saldo` da planilha: soma todos os locais e variações de um item. O banco (`v_saldo`) calcula por local e variação.

## 27. Problemas que o trabalho revelou (decisões do usuário)

1. **Catálogos duplicados dentro do próprio estoque.** Dos 273 itens do orama_fabrica, **87 têm nome igual a item da planilha antiga**, em categorias diferentes. A planilha antiga já tem `Sorvete balde`, `Sorvete cuba`, `Sorvete pote`, `Picolé`, `Polpas`, `Polpas 100g`, `Polpas Orama 1,5kg`, `Doces 900g`, `Bolos`, `Massa de bolo`; o orama_fabrica tem `Baldes`, `Cubas`, `Potes`, `Polpas`, `Toppings`. Parecem ser os mesmos produtos reais com dois cadastros. Por enquanto a planilha v2 e a semente **mantêm os dois**, para não decidir sozinho. Se a contagem de um sabor for lançada em um cadastro e a entrada no outro, o saldo não bate. Precisa decidir qual categoria sobrevive para cada produto e usar `item_aliases` para apontar o outro. Parte da sobreposição é falso positivo (por exemplo "Limão" polpa e "Limão" sorvete são produtos diferentes), então a conferência é manual.
2. **Unidade em conflito para o mesmo produto.** Os itens da planilha antiga estão em `un` ou `g` conforme a categoria, e os do orama_fabrica (baldes, cubas, potes) em `g`. A fusão vai exigir escolher uma unidade base por produto.
3. **Locais legados.** Os registros migrados da planilha antiga (397 contagens e 31 movimentos) estão no local `Fábrica` genérico, sem temperatura. Redistribuir entre Câmara, Geladeira e Secos exige a temperatura de cada item antigo, que a planilha antiga não tem.

## 28. O que ainda não foi feito

| Item | Motivo |
|---|---|
| Importar a planilha para o banco | Depende de resolver a seção 27, itens 1 e 3, e de revisar as linhas marcadas em `revisar` |
| Tabelas de vendas, despesas, estoque mínimo e sabores (do plano original, seção 5) | Fora do escopo de estoque; precisam do formato real no Realtime Database |
| Reposição: detalhar `replenishment_*` | Está mínima. Falta ler a reposição atual do orama_admin para casar os campos |
| Camada de acesso, login e permissões | Decisão aberta (seção 8, item 5) |
| Adaptar orama_fabrica e orama_admin | Depende da linha anterior |
| Exportar o Firebase (lojas, usuários, comandas, reposição) | Não iniciado |
| Conferir fórmulas da planilha v2 num programa de planilhas | Sem LibreOffice aqui |
| Cadastrar `item_packagings` dos itens em caixa, fardo, saco, rolo e tubo | Fatores desconhecidos |
| Variações de tamanho (aba `variacoes`) | Itens e rótulos ainda não informados |

## 29. Próximo passo sugerido

Resolver a seção 27, item 1, decidindo como unificar os catálogos, porque é o que mais afeta a importação e todo o saldo. Depois, escolher a camada de acesso (seção 8, item 5), que destrava a adaptação dos apps.

---

## 30. Correções do usuário (02/10/2026, rodada 4)

### 30.1 Os secos ficam na Oficina, não na fábrica

Resposta do usuário: os secos ficam em outro local que não é a fábrica, a "oficina". **Substitui** a tabela da seção 21.3, em que Secos era um dos três locais da fábrica.

| Local | Tipo | Armazena | Códigos legados |
|---|---|---|---|
| Câmara frigorífica | `fabrica` | congelados | `E1A` |
| Geladeira | `fabrica` | refrigerados | `E1B` |
| Oficina | `oficina` | secos | `E1C`, `E2A`, `E2B` |

Consequências:
- `locations.tipo` ganhou o valor `oficina`, e a temperatura passa a valer para `fabrica` e `oficina`.
- O orama_fabrica continua sendo o app que dá entrada nos secos, mas o local de destino desses itens é a **Oficina**. A reposição de itens secos sai da Oficina, não da fábrica.
- Fica uma pergunta em aberto: a gestão da Oficina é feita pela mesma equipe do orama_fabrica? Isso decide se o app precisa de um perfil por local.
- Onde as seções 11, 14, 15 e 21 dizem "secos na fábrica" ou "Secos", leia "Oficina".

### 30.2 Polpas: produzidas na fábrica, com dois destinos

Resposta do usuário: as polpas são produzidas na fábrica. Algumas viram sorvete e algumas vão para a loja para fazer suco, então é preciso representar essa diferença.

Duas correções:
1. **`nivel` das polpas é `producao`**, não `terceiros`. O catálogo antigo as marcava como `PTC` (terciário), o que contradiz a informação. A semente passou a forçar `producao` para a categoria POLPAS (20 itens). Efeito nos totais: nível `producao` 173 e `terceiros` 100 (antes 153 e 120). O `codigo_legado` continua `PTC`.
2. **Novo campo `items.destino`**, com os valores:

| Valor | Significado |
|---|---|
| `producao` | consumida na fábrica (a polpa que vira sorvete) |
| `loja` | enviada à loja (a polpa para suco) |
| `ambos` | serve aos dois destinos |
| vazio | ainda não classificado |

Uso previsto: a lista de reposição mostra só itens `loja` ou `ambos`; o consumo de produção (fase de fórmulas, seção 16) considera `producao` ou `ambos`.

**Limite do campo:** com `ambos`, o saldo é um só. Se for preciso controlar separadamente o estoque de uma mesma polpa para sorvete e para suco, devem ser **dois itens** (ou duas embalagens), não um campo. Isso precisa de decisão.

**A classificação ficou vazia de propósito.** A planilha antiga tem três categorias de polpa (`Polpas` com 30 itens, `Polpas 100g` com 15 e `Polpas Orama 1,5kg` com 11), mais as 20 do orama_fabrica, e nada indica qual vai para sorvete e qual vai para loja. Não foi feita suposição.

### 30.3 Efeito sobre a duplicidade da seção 27, item 1

O usuário respondeu à pergunta sobre os catálogos duplicados dizendo que a diferença entre polpas importa. Isso explica **parte** da duplicidade: provavelmente `Polpas 100g` e `Polpas Orama 1,5kg` são formas de apresentação diferentes da mesma polpa, e a categoria `Polpas` do orama_fabrica é outra visão. A unificação **ainda não foi feita**, porque falta saber:
1. Quais polpas (por sabor e por embalagem) vão para sorvete, quais vão para loja, quais para os dois.
2. Se "Polpas 100g" e "Polpas Orama 1,5kg" são embalagens do mesmo item (uma polpa, duas embalagens em `item_packagings`) ou itens diferentes.
3. Para os demais produtos (Sorvete balde/cuba/pote contra Baldes/Cubas/Potes), a resposta ainda não veio.

### 30.4 O que foi alterado no repositório

- `db/schema.sql`: `locations.tipo` com `oficina`; `items.destino`.
- `db/tests/schema_test.sql`: testes de local `oficina`, de tipo inválido e de `destino`. Passam.
- `db/tools/gen_seed_fabrica.py`: local Oficina, polpas como `producao`.
- `db/tools/build_planilha_v2.py`: Oficina, coluna `destino` em `itens`, texto do LEIA-ME.
- Sementes regeneradas e `Estoque - modelo banco v2.xlsx` regerada. A planilha original continua intacta.

### 30.5 Planilha no Google Sheets

O usuário pediu para ajustar direto no Google Sheets. A automação não enxerga a aba que o usuário já tinha aberta, então foi preciso o link. No primeiro acesso o arquivo (`Estoque - modelo banco v2.xlsx`, aberto no Google Planilhas) estava só para leitura; depois que o usuário liberou a edição, as correções foram aplicadas **diretamente nesse arquivo**:

| Aba | Alteração |
|---|---|
| `locais` | linha "Secos" virou `Oficina`, tipo `oficina`; a lista suspensa de tipo ganhou `oficina` |
| `itens` | `nivel` = `producao` nas 20 polpas do orama_fabrica (linhas 530 a 549, conferidas pelo nome); coluna `destino` criada em L, com lista `producao`, `loja`, `ambos`, vazia |
| `LEIA-ME` | texto de `locais` corrigido e linha nova sobre `destino` |

Observações:
- O arquivo no Drive continua `.xlsx`, e as alterações foram salvas nele.
- Nada mais foi alterado nele. As demais diferenças entre o Drive e o arquivo local não foram comparadas célula a célula.
- A linha 550 (`Insumos | CARNE SECA`) já estava como `producao` na origem; não foi tocada.

---

## 31. Respostas do usuário (02/10/2026, rodada 5): polpas, Oficina e catálogos

### 31.1 Respostas

| # | Pergunta | Resposta | Decisão registrada |
|---|---|---|---|
| 1 | Quais polpas vão para sorvete e quais para a loja? | "Polpas de 100g são para a loja" | A categoria `Polpas 100g` (15 itens) tem `destino = loja`. **Só isso foi informado.** As demais polpas continuam sem classificação |
| 2 | `Polpas 100g` e `Polpas Orama 1,5kg` são a mesma polpa? | "Diferentes" | São itens diferentes. Nada a unificar entre elas |
| 3 | A mesma polpa precisa de estoque separado para sorvete e suco? | "Sim" | Quando for o caso, são **dois itens**, cada um com saldo próprio. O valor `ambos` de `destino` foi **removido** |
| 4 | A equipe do orama_fabrica também cuida da Oficina? | "Sim" | O app da fábrica cobre os 3 locais (Câmara frigorífica, Geladeira e Oficina). Não é preciso perfil de acesso por local. Resolve a pergunta final da seção 30.1 |
| 5 | Sorvete balde/cuba/pote são os mesmos produtos que Baldes/Cubas/Potes? | "Sim" | Os dois cadastros descrevem o mesmo produto e precisam ser unificados. Ver 31.3 |

### 31.2 O que foi alterado

- `db/schema.sql`: `items.destino` aceita só `producao` ou `loja`. Os testes passam.
- `db/tools/build_planilha_v2.py`: `Polpas 100g` recebe `destino = loja`; lista de `destino` sem `ambos`; texto do `LEIA-ME`. Planilha local regerada.
- **Google Planilhas** (`Estoque - modelo banco v2.xlsx`): `destino = loja` nas linhas 56 a 70 (as 15 polpas de 100g, conferidas pelo nome); `ambos` retirado da lista suspensa de `destino`; texto do `LEIA-ME` corrigido.
- Novo script `db/tools/mapa_catalogos.py` e arquivo `~/Transferências/Mapa de itens - revisar.xlsx` (ver 31.3).

Esta seção substitui a parte da seção 30.2 que previa o valor `ambos`.

### 31.3 Mapa para unificar os catálogos

Como a resposta 5 foi "sim", o próximo passo é decidir, item a item, qual item antigo corresponde a qual item do orama_fabrica. Isso **não pode ser feito só por nome**: o catálogo da fábrica usa nomes diferentes (por exemplo "Cacau com Laranja" e "CACAU BAHIA COM LARANJA"). Foi gerado um arquivo de revisão com a coluna `aceitar` para o usuário preencher (`sim`, `nao` ou `outro`). Nada foi fundido.

| Par de categorias | Itens antigos | Itens da fábrica | Exato | Sugerido (conferir) | Sem par |
|---|---|---|---|---|---|
| Sorvete balde x Baldes | 24 | 39 | 12 | 8 | 23 |
| Sorvete cuba x Cubas | 22 | 40 | 12 | 7 | 24 |
| Sorvete pote x Potes | 30 | 39 | 11 | 10 | 27 |
| Polpas x Polpas | 30 | 20 | 15 | 3 | 14 |

"Sem par" soma os itens que só existem de um lado, tanto no catálogo antigo quanto no da fábrica.

**As sugestões não são confiáveis sem conferência.** Algumas estão claramente erradas: "Chocolate meio amargo" foi sugerido como "CHOCOLATE VEGANO ZERO", e "Baunilha com Whey" como "BANANA COM WHEY ZERO". Outras são plausíveis mas incertas, como "Mousse da Maracujá com Creme de Coco (cabra)" para "MOUSSE DE MARACUJÁ COM BOLO". A coluna `aceitar` existe por isso.

A categoria `Polpas` da fábrica só foi comparada com a `Polpas` antiga. As polpas de 100g e de 1,5 kg ficaram de fora do mapa, porque são itens diferentes.

### 31.4 Problema novo: unidade das contagens antigas

As contagens antigas de sorvete estão em **unidades** (24 linhas de balde, 22 de cuba e 30 de pote, todas em `un`). O orama_fabrica passou a lançar baldes, cubas e potes em **gramas** (seção 22.4). Uma contagem de "3 baldes" não vira gramas sem saber o peso de um balde. As opções são:
1. Cadastrar o peso padrão de balde, cuba e pote (por sabor, se variar) em `item_packagings` e converter.
2. Importar a contagem antiga com a quantidade em unidades marcada para revisão, sem `qtd_base`, e recontar na primeira contagem nova.

### 31.5 Pendências

1. Revisar o arquivo `Mapa de itens - revisar.xlsx` (coluna `aceitar`).
2. **Decidir a seção 31.4**: qual o peso padrão de balde, cuba e pote, ou aceitar a opção 2.
3. Classificar as demais polpas: `Polpas Orama 1,5kg` (11 itens), `Polpas` antiga (30 itens) e `Polpas` da fábrica (20 itens). Só as de 100g têm destino informado. Provavelmente as demais vão para sorvete, mas isso é uma leitura minha e **não foi aplicado**.
4. Para cada polpa que serve a sorvete e a suco, criar o segundo item (seção 31.1, resposta 3).
5. Itens contados em caixa, fardo, saco, rolo e tubo ainda precisam de fator em `item_packagings`.

---

## 32. Sem peso padrão: cada recipiente tem o seu peso (02/10/2026, rodada 6)

### 32.1 Resposta do usuário

Não existe peso padrão para balde, cuba e pote. Assim que o sorvete é produzido, cada recipiente é **pesado na hora**, antes de ir para a câmara fria, e todo sorvete tem um peso diferente.

### 32.2 O que isso decide

- A opção 1 da seção 31.4 (cadastrar o peso padrão em `item_packagings`) **está descartada**. Para esses itens, `item_packagings` não terá balde, cuba nem pote.
- Vale a opção 2: as contagens antigas em unidades são importadas **sem converter para gramas**, marcadas para revisão. O peso real só passa a existir a partir das entradas novas, em que cada recipiente é pesado.
- A decisão 7 (lançar em gramas) fica **mais forte**: o peso digitado é o peso pesado na produção, e não uma estimativa.

### 32.3 O que foi implementado

Campo novo `unidades` (número inteiro de recipientes), ao lado do peso:

| Tabela | Campo | Uso |
|---|---|---|
| `stock_movements` | `unidades` (maior que zero, opcional) | quantos recipientes tem o movimento. Cada balde pesado vira **uma linha** com `unidades = 1` e o peso real em `quantidade` |
| `stock_count_lines` | `unidades` (zero ou mais, opcional) | contagem em recipientes, **com ou sem peso**. Permite importar a contagem antiga ("5 baldes") sem inventar gramas |
| `v_saldo` | `contado_unidades`, `entradas_unidades`, `saidas_unidades`, `saldo_unidades` | saldo em recipientes, ao lado do saldo em gramas |

Teste novo (passa): contagem antiga de 5 baldes em unidades, 2 entradas pesadas (4,1 kg e 3,85 kg) e 1 saída de 4.100 g. Resultado: `saldo_unidades = 6` e `saldo_base = 3.850 g`.

**Limites conhecidos desta etapa:**
- Uma contagem só em unidades não dá ponto de partida em gramas. Para esses itens, `saldo_unidades` é confiável e `saldo_base` só soma os movimentos depois da contagem, ou seja, **subestima**.
- Ajuste de estoque não mexe em `unidades`, que é sempre positivo.
- Regra de importação para a planilha: contagem com unidade `un` em item cuja unidade base é `g` vira linha com `unidades` preenchido, `quantidade` vazia e `revisar = contado em unidades`. O banco recusa `un` como unidade de peso, então sem essa regra a importação falharia.

### 32.4 Decisão em aberto: como sai um recipiente

Para a **entrada** está claro: um recipiente, um peso. A dúvida é a **saída** pela reposição. Quando um balde vai para a loja, qual peso sai do saldo?

| Opção | Como funciona | Consequência |
|---|---|---|
| A. Controlar cada recipiente | A saída aponta para a entrada exata do balde que saiu (por etiqueta, código ou escolha na lista), e o peso que sai é o peso real daquele balde | Saldo em gramas exato. Exige identificar cada recipiente e mais trabalho na hora de separar o pedido |
| B. Sair só em unidades | A reposição pede "2 baldes de baunilha" e a saída desconta 2 unidades; o peso é estimado (média dos recipientes em estoque) | Mais simples no dia a dia. O saldo em gramas vira aproximação e se desvia com o tempo |

Hoje o schema **exige peso em toda saída** (`quantidade` maior que zero). A opção B pediria permitir saída só com `unidades`, e a A pediria uma ligação entre a saída e a entrada do recipiente. Nenhuma das duas foi implementada, porque depende de como a loja pede e de como a fábrica separa.

### 32.5 Pendências novas

1. Escolher entre A e B (32.4). É a pergunta que mais afeta o saldo em gramas.
2. As demais pendências da seção 31.5 continuam: revisar o mapa de itens, classificar as demais polpas e cadastrar os fatores de caixa, fardo, saco, rolo e tubo.

---

## 33. Opção A: cada recipiente é controlado individualmente (02/10/2026, rodada 7)

### 33.1 Decisão

O usuário escolheu a opção A da seção 32.4: controlar cada recipiente. A saída pela reposição aponta para o recipiente exato que saiu, e o peso que sai do saldo é o peso real dele. O saldo em gramas fica exato.

### 33.2 Regras implementadas no banco

Valem para itens com `items.controla_recipiente = true` (baldes, cubas e potes: 118 itens na semente):

| Regra | Como funciona |
|---|---|
| Entrada = uma linha por recipiente | `unidades` precisa ser 1 e o peso real vai em `quantidade`. Dois baldes viram duas linhas |
| Etiqueta automática | o banco gera `etiqueta` (formato `R000001`, única) para cada recipiente que entra. É o código que identifica o balde na hora de separar o pedido |
| Saída informa o recipiente | a saída leva só `recipiente_id` (a entrada do recipiente). O banco **copia sozinho** o peso real, o lote e a validade do recipiente. O app não digita peso na saída |
| Um recipiente sai uma vez | uma segunda saída do mesmo recipiente é recusada. Se a saída for estornada, ele volta à lista e pode sair de novo |
| Local e item conferem | o recipiente tem que ser do mesmo item e estar no mesmo local da saída |
| Estorno | estornar a entrada de um recipiente que já saiu é recusado. Estorno sem peso informado repete a quantidade do original |
| Duas saídas simultâneas | a entrada do recipiente é travada durante a inserção, então a corrida entre dois usuários não duplica a saída |
| Lista para escolher | a view `v_recipientes_disponiveis` mostra os recipientes em estoque, com etiqueta, peso, lote e validade, em ordem de menor validade primeiro, e depois o mais antigo |
| Pedido em recipientes | `replenishment_request_lines` aceita só `unidades` (por exemplo "2 baldes"), sem peso |

### 33.3 Testes

Os testes cobrem: entrada sem `unidades = 1` recusada, etiquetas únicas, ordem por validade, saída sem recipiente recusada, saída que leva peso, lote e validade, saldo em gramas e em recipientes (8.250 g e 2 recipientes), saída duplicada recusada, recipiente de outro local ou item recusado, `recipiente_id` em entrada recusado, estorno devolvendo o recipiente à lista, saída repetida depois do estorno, estorno de entrada com recipiente já enviado recusado e pedido só em unidades. Todos passam.

Teste de mutação: removida a regra "um recipiente sai uma vez" de uma cópia, a suíte falhou como esperado. Já foram testadas por mutação a imutabilidade do histórico (seção 24) e esta. As demais regras não foram.

### 33.4 Catálogo e planilha

- `items.controla_recipiente` entra na semente: `true` em Baldes, Cubas e Potes (118 itens), `false` nos demais.
- **Planilha local** (`Estoque - modelo banco v2.xlsx`): coluna `controla_recipiente` na aba `itens`, com `sim` nos 118 e `nao` nos outros itens do orama_fabrica.
- **Google Planilhas**: coluna `controla_recipiente` criada em `itens`, com `sim` nas linhas 368 a 485 (conferido por contagem: 118 células com o texto exato). **As demais linhas ficaram em branco**, o que equivale a `nao`. A lista suspensa `sim`/`nao` **não** foi criada nessa coluna no Drive.
- Os 76 itens antigos `Sorvete balde`, `Sorvete cuba` e `Sorvete pote` **não** foram marcados: a ideia é que desapareçam na unificação com Baldes, Cubas e Potes (seção 31.3).

Intercorrência na edição do Google Planilhas: a primeira tentativa de preencher a coluna deixou o conteúdo errado nas 118 células (5 caracteres em vez de `sim`), porque o atalho de preenchimento em bloco inseriu uma quebra de linha. Foi detectado por uma fórmula de conferência temporária, as células foram limpas e reescritas, e a fórmula de teste e a coluna auxiliar foram apagadas. Uma segunda contagem deu 118 de 118.

### 33.5 Legendas das nomenclaturas no `LEIA-ME`

Pedido do usuário. Foi acrescentado, no Google Planilhas e no gerador local, um bloco com: o formato do código (P + P ou T + C, R ou S), as seis legendas (PPC, PTC, PPR, PTR, PPS, PTS, com as palavras exatas informadas), a regra que liga PP* a `producao` e PT* a `terceiros`, a exceção das polpas e onde cada código fica (Câmara frigorífica, Geladeira e Oficina, com os códigos antigos E1A a E2B). Também entrou no Drive a linha do `controla_recipiente`, que faltava.

### 33.6 O que ficou em aberto

1. **A etiqueta física é minha proposta.** O usuário escolheu controlar cada recipiente, mas não disse como identificar o balde na prática. O banco gera o código; falta definir se será impresso e colado, QR code ou outra forma, e quem faz isso na pesagem.
2. **Chegada à loja.** A saída da fábrica está resolvida. Ainda não está modelado como o balde passa a existir no estoque da loja ou do PDV quando a reposição é recebida (entrada no local de destino com o mesmo recipiente e peso, ou só contagem em unidades pela loja).
3. **Itens que mudam de local dentro da fábrica** (por exemplo, do congelador para outro) não têm movimento de transferência.
4. **Lista suspensa da coluna `controla_recipiente` no Drive** e os `nao` das demais linhas, se quiser a planilha igual à local.
5. As pendências da seção 31.5 continuam: mapa de itens, demais polpas e fatores de caixa, fardo, saco, rolo e tubo.

---

## 34. Foco no orama_fabrica e a etiqueta de hoje (02/10/2026, rodada 8)

### 34.1 Decisão de escopo

O usuário pediu: por enquanto, focar **apenas no app da fábrica**. Ficam em segundo plano, sem prioridade agora: orama_admin (reposição e saídas), orama_lojas, orama_users, o recebimento na loja (seção 33.6, item 2) e a importação do histórico das lojas.

Efeito sobre as pendências anteriores (leitura minha, a confirmar):
- O **mapa de itens** (seção 31.3) passa a servir só para importar o histórico antigo de sorvete. O catálogo do orama_fabrica é o catálogo vigente, então o app da fábrica **não depende** dessa revisão para começar.
- A **saída** (seção 33.2) continua modelada no banco, mas a tela que escolhe o recipiente é do orama_admin. Ela fica para depois.

### 34.2 Como a etiqueta funciona hoje

Resposta do usuário: a etiqueta é impressa, e o **lote, o dia e o peso são escritos à mão**.

Consequências para o desenho:
- O que identifica o recipiente na prática é **lote + dia + peso**, que já estão escritos no balde. Por isso o app mostra esses três campos na lista de recipientes em estoque, e o funcionário reconhece o balde pelo que está escrito nele.
- A `etiqueta` gerada pelo banco (`R000001`) **não precisa estar escrita no recipiente agora**. Ela existe no registro e fica disponível para a etiqueta impressa futura (34.4).
- **Mudança no banco:** o `lote` passou a ser **obrigatório** na entrada de balde, cuba e pote, porque é um dos três dados que identificam o recipiente. Teste incluído, e a suíte passa.
- O funcionário passa a digitar no app o que antes só escrevia na etiqueta. Para não dobrar o trabalho, a tela de entrada deve pedir **lote e dia uma vez** e depois uma **lista de pesos**, um por recipiente. Cada peso vira uma linha de entrada com o mesmo lote e o mesmo dia.
- Atenção: o `dia` é a data de produção (`ocorrido_em`). A validade é outro campo, e a regra de preencher ou não ainda é a da seção 22.5.

### 34.3 O que o app da fábrica precisa fazer (primeira versão)

| Tela ou função | Comportamento |
|---|---|
| Login | usuário próprio. Remove os UIDs fixos do código (seção 14.4, item 12) |
| Nova entrada | escolhe a **origem** (produção ou compra, sugerida pelo `nivel` do item) e os itens por categoria, com busca. O local vem da temperatura do item (Câmara frigorífica, Geladeira ou Oficina) |
| Item comum | quantidade numérica e unidade vinda das embalagens cadastradas do item. Lote e validade se o item controlar validade |
| Balde, cuba e pote | lote, dia e validade uma vez, depois a lista de pesos em gramas, um por recipiente |
| Resumo | mostra tudo que será lançado antes de salvar |
| Salvar | grava com fila offline. O `id` do movimento é gerado no aparelho, então reenviar não duplica |
| Histórico | por dia, com o responsável. **Não há exclusão**: corrigir é estornar, com motivo e senha de administrador (seção 22.7) |
| Estoque atual | saldo por local e a lista de recipientes em estoque (peso, lote, dia), só leitura |
| Catálogo | vem do banco, com cache local. Sai o `insumos.dart` do app |

Correções que o app atual precisa (seção 14.4): incluir a Oficina, remover a exclusão de relatório, validar quantidade numérica, remover os `print` e os UIDs fixos, e tirar o código duplicado entre as duas telas de relatório.

### 34.4 Melhoria futura: gerar a etiqueta no app e imprimir

Pedido do usuário, **registrado como melhoria, fora do escopo agora**: o app gerar a etiqueta e o usuário integrar com alguma máquina física de impressão.

Requisitos preliminares, para não perder a ideia (nenhum foi decidido):
- Conteúdo provável: nome do item, lote, dia de produção, validade, peso e o código da etiqueta (`R000001`), idealmente também como QR code ou código de barras. Com isso, na saída bastaria ler a etiqueta para identificar o recipiente.
- A impressora **ainda não foi escolhida**, e o jeito de conectar (Bluetooth, rede ou USB) e a linguagem de impressão dependem do modelo. Esse é o primeiro dado a levantar.
- O banco já está pronto para isso: cada recipiente tem `etiqueta` única, peso, lote e dia.
- Ao implementar, o app deve gerar a etiqueta **depois** de salvar a entrada, para que o código impresso seja o gravado.

### 34.5 Bloqueio para começar a implementar o app

O app precisa falar com o banco novo, e a **camada de acesso** (Parte 1, seção 8, item 5) ainda não foi escolhida. Sem isso, o app não consegue gravar no Postgres com segurança: o app não pode ter a senha do banco, e a senha de administrador do estorno tem que ser verificada no servidor.

---

## 35. Decisão: Supabase (02/10/2026, rodada 9)

### 35.1 Decisão

O usuário escolheu o **Supabase** como camada de acesso, por dar menos trabalho. Houve uma resposta anterior pela "API própria" na mesma conversa, que o usuário interrompeu e corrigiu em seguida; vale a escolha final, **Supabase**. Isso resolve a decisão aberta da Parte 1 (seção 8, item 5, e seção 9).

### 35.2 O que foi preparado

| Arquivo | Para quê |
|---|---|
| `db/supabase/001_seguranca.sql` | permissões, RLS e as funções de correção. Aplicar no editor SQL do Supabase **depois** de `db/schema.sql` e das sementes |
| `db/tests/supabase_stub.sql` | simula `anon`, `authenticated` e `auth.uid()` num Postgres comum, só para teste |
| `db/tests/security_test.sql` | testes da segurança. `bash db/tests/run.sh` roda tudo |

### 35.3 Quem pode o quê

O app usa a chave pública (`anon`) mais o login do usuário. O que cada pessoa pode fazer vem de `profiles.papel`:

| Papel | Catálogo | Movimentos | Entrada | Saída | Estorno e ajuste |
|---|---|---|---|---|---|
| `admin` | lê e escreve | lê | sim | sim | sim, com senha |
| `fabrica` | lê | lê | sim | **não** | sim, com senha de administrador |
| `leitura` | lê | lê | não | não | não |
| `loja`, `pdv` | lê | **não vê** | não | não | não |
| sem login | nada | nada | não | não | não |

Regras reforçadas pelo banco, além da tabela:
- A entrada só vale **em nome de quem está logado** (`usuario_id` é forçado). Ninguém lança em nome de outra pessoa.
- O histórico é imutável também para o app: não existe permissão de alterar nem apagar movimentos.
- Estorno e ajuste **não** são inserções diretas. Passam por `rpc_estornar_movimento` e `rpc_ajustar_estoque`.
- As views de saldo respeitam a permissão de quem consulta (uma loja não vê o saldo da fábrica).
- A etiqueta do recipiente é gerada pelo banco mesmo sem o app ter acesso à sequência.

### 35.4 Senha de administrador (decisão 10 da seção 22.7)

Implementada **no servidor**, como recomendado:
- Cada administrador tem a sua senha, guardada só como hash (bcrypt) numa tabela que o app não consegue ler nem escrever.
- Quem digita a senha (funcionário da fábrica ou administrador) é conferido contra as senhas dos administradores. O movimento registra **qual administrador autorizou** (`autorizado_por`) e **quem digitou** (`usuario_id`). Isso responde à pergunta da seção 22.10, item 4: funciona com uma conta de administrador por pessoa, e também com um só administrador.
- 5 erros seguidos bloqueiam quem digitou por 15 minutos, **mesmo que a senha certa venha depois**. A contagem de erros é gravada e não é desfeita pela recusa (testado).
- Motivo é obrigatório. As funções devolvem `{ok, erro}` em vez de lançar exceção; erros previstos: `senha_invalida`, `bloqueado`, `sem_permissao`, `motivo_obrigatorio`, `movimento_inexistente`, `ja_estornado_ou_duplicado` e `regra` (por exemplo, recipiente que já saiu).
- Definir ou trocar a senha é feito **só pelo painel do Supabase** (`rpc_definir_senha_admin`), nunca pelo app. Mínimo de 8 caracteres.

### 35.5 Testes

Passam no Postgres 16: loja e usuário sem login sem acesso, funcionário lança entrada mas não saída, ajuste nem estorno direto, histórico imutável, segredos ilegíveis, saída de recipiente levando o peso real, estorno com senha (autorizador, lote, peso e validade repetidos), estorno duplicado recusado, bloqueio por 5 erros. Dois testes de mutação (remover o `usuario_id` forçado e remover o bloqueio) foram detectados pela suíte.

### 35.6 Limites importantes

- **Não foi testado num Supabase de verdade.** Os testes simulam `auth.uid()` e os papéis num Postgres comum. A primeira execução no seu projeto pode revelar diferenças, por exemplo no schema das extensões. O arquivo foi escrito para o ambiente do Supabase (`search_path` com `extensions`, `security_invoker`), mas só a execução confirma.
- Usuários do Supabase Auth e a linha correspondente em `profiles` (`auth_user_id`) precisam ser **criados à mão** no painel. Não há tela de cadastro.
- **Nunca** colocar a chave `service_role` no app.
- Fábrica **não** registra saída (decisão 1). Se quem separa o pedido for da fábrica, a política de saída precisa incluir esse papel. Está como pergunta no fim desta seção.
- Backups, região e plano do projeto não foram avaliados.

### 35.7 Próximos passos

1. **Você:** criar o projeto no Supabase (precisa da sua conta).
2. No editor SQL do projeto, aplicar nesta ordem: `db/schema.sql`, `db/seed/001_locais.sql`, `db/seed/002_catalogo_fabrica.sql`, `db/supabase/001_seguranca.sql`.
3. Criar os usuários da fábrica e o administrador no painel, inserir os perfis em `profiles` e definir a senha do administrador com `rpc_definir_senha_admin`.
4. Adaptar o **orama_fabrica** com o pacote `supabase_flutter`: login, catálogo com cache, tela de entrada (lote e dia uma vez, depois a lista de pesos), fila offline, histórico com estorno e consulta de saldo (seção 34.3). A URL e a chave pública do projeto entram por configuração, não no código.
5. Importar o histórico (planilha) depois.

### 35.8 Pergunta que surgiu

Quem **separa o pedido** de reposição na fábrica, a pessoa do orama_admin (administrador) ou o funcionário da fábrica? Hoje só o administrador registra saída. Se for o funcionário, basta liberar a saída para o papel `fabrica`, uma linha na política.

---

## 36. Decisão final: Postgres + API Spring Boot, sem Supabase (04/10/2026, rodada 10)

### 36.1 Decisão

O usuário desistiu do Supabase: **Postgres comum + API Spring Boot**. **Substitui a seção 35.** A segurança que estava prevista como regras do banco (RLS, funções com senha) passou a ser da **API**, e o banco ficou com o mínimo (permissões do papel da aplicação e imutabilidade do histórico).

### 36.2 Onde está o código

O projeto novo é **`/home/rikelmyso7/Documentos/orama/orama_api`**. O `db/` saiu do orama_admin e foi para lá, por ser o dono do banco. Equivalências para as seções 23 a 35:

| Antes | Agora |
|---|---|
| `orama_admin/db/schema.sql` | `orama_api/db/migration/V1__schema.sql` |
| `db/seed/001_locais.sql` e `002_catalogo_fabrica.sql` | `db/migration/V2__locais.sql` e `V3__catalogo_fabrica.sql` (migrações do Flyway, geradas por `db/tools/gen_seed_fabrica.py`) |
| `db/supabase/001_seguranca.sql`, `db/tests/supabase_stub.sql`, `db/tests/security_test.sql` | **apagados**. Substituídos por `V4__papel_aplicacao.sql` e `db/tests/app_role_test.sql` |
| `db/tests/`, `db/tools/` | mesmos nomes, em `orama_api/db/` |

Nada foi commitado. O `orama_api` não é um repositório git ainda.

### 36.3 Mudanças no banco

- `profiles` passou a ter `login` (único, minúsculo), `senha_hash` (bcrypt) e `senha_autorizacao_hash` (só administrador). Saíram `auth_user_id` e a extensão `pgcrypto`.
- Nova tabela `tentativas_senha` (falhas e bloqueio, por usuário e por tipo: login ou autorização).
- **V4:** cria o papel `orama_app` com o mínimo: ler o catálogo, **inserir** movimentos e contagens, criar usuários e trocar senhas. **Não pode alterar nem apagar movimentos**, mexer no catálogo, apagar usuários nem mudar o schema. A API conecta com um usuário membro desse papel, e o dono do banco só roda as migrações.
- O gatilho de movimentos passou a rodar com os direitos do dono (`SECURITY DEFINER`), porque trava a linha do recipiente (`SELECT ... FOR UPDATE`) e gera a etiqueta, o que o papel limitado não poderia fazer.

### 36.4 A API (`orama_api`)

Spring Boot 4.1.1, Java 21, JdbcClient (SQL direto), Flyway, Spring Security com JWT (HS256), validação e ProblemDetail nos erros.

| Rota | Quem | Função |
|---|---|---|
| `POST /auth/login`, `POST /auth/senha` | todos / logado | login (bloqueio após 5 erros por 15 min) e troca da própria senha |
| `GET /catalogo` | logado | locais, categorias e itens (com embalagens, variações, local padrão pela temperatura) |
| `POST /entradas` | admin, fábrica | entrada em lote, **resultado por item** (`criado`, `ja_registrado`, `recusado`), reenvio seguro pelo `id` gerado no aparelho |
| `GET /movimentos` | admin, fábrica, leitura | histórico com filtros e nomes |
| `GET /saldo`, `GET /recipientes` | admin, fábrica, leitura | saldo por local e lista de baldes, cubas e potes com peso, lote e validade (menor validade primeiro) |
| `POST /movimentos/{id}/estorno`, `POST /ajustes` | admin, fábrica | correção com motivo e senha de administrador |
| `GET/POST /usuarios`, `PUT /usuarios/{id}/senha-autorizacao` | admin | gestão de usuários |

Não existe rota para editar nem apagar movimentos.

Decisões de implementação que o usuário não pediu explicitamente:
- O papel do usuário é **lido do banco a cada chamada**, não do token. Desativar um usuário ou mudar o papel vale na hora.
- O login responde igual para login inexistente e senha errada, e gasta o mesmo tempo.
- A senha de administrador é **uma por administrador**, separada da senha de entrada (a API recusa que sejam iguais). Quem digita é conferido contra as senhas dos administradores ativos, e cada estorno e ajuste registra **quem autorizou** (`autorizado_por`) e **quem digitou** (`usuario_id`). Isso mantém a resposta da seção 35.4.
- Datas de entrada: aceita data passada de até 30 dias (lançamento feito offline) e recusa o futuro (tolerância de 5 minutos).
- Fuso dos filtros do histórico: America/Sao_Paulo.
- O primeiro administrador nasce por variáveis de ambiente (`ORAMA_BOOTSTRAP_ADMIN_*`), só quando não há nenhum usuário.

### 36.5 Verificação

- **44 testes de integração** com Postgres real (Docker) passam, com **92% de cobertura de linhas** (regra do build: mínimo de 80%). Eles rodam **como o usuário limitado de produção**, e um teste confere isso (`current_user` é `orama_api`, e alterar ou apagar movimentos é negado).
- `bash db/tests/run.sh` (testes SQL do banco, incluindo o papel da aplicação) passa.
- **Teste de ponta a ponta** com `docker compose` (Postgres + imagem da API construída pelo `Dockerfile`), feito e depois desfeito: migrações pelo dono, API conectada como `orama_api`, administrador inicial criado, login, 401 sem token, criação de usuário, entrada de 2 baldes com etiquetas `R000001` e `R000002`, reenvio sem duplicar, saldo de 7.950 g e 2 recipientes, estorno com senha errada recusado (403), estorno com senha certa, saldo depois (3.850 g e 1).
- Os testes de mutação das regras do banco (imutabilidade, recipiente que já saiu, lote) foram feitos nas rodadas anteriores. **Não** foi feito teste de mutação nas regras novas da API.

### 36.6 Limites e o que falta

- **A API ainda não está no ar.** Falta decidir onde hospedar, o Postgres (próprio, gerenciado ou na mesma máquina), HTTPS, backups e monitoramento. Não há limite de requisições por IP: precisa de um proxy na frente.
- **O app orama_fabrica ainda não foi adaptado.** É o próximo passo (seção 34.3): login, catálogo em cache, tela de entrada (lote e dia uma vez e depois a lista de pesos), fila offline com o `id` do movimento, histórico com estorno e consulta de saldo.
- **Saída (reposição)** não tem rota. O banco aceita, mas a rota e a tela são do orama_admin e ficam para depois.
- **Importação do histórico** (planilha v2 e Firebase) não foi feita.
- O `orama_api` tem testes de integração, mas **nenhum teste unitário** isolado. A cobertura vem toda dos de integração.
- O `Dockerfile` e o `docker-compose.yml` foram testados no meu computador, em ambiente de desenvolvimento. Não foi testado em servidor.
- Perguntas que continuam abertas: quem separa o pedido na fábrica (seção 35.8), e as pendências da seção 31.5 (mapa de itens, demais polpas, fatores de caixa e fardo).

---

## 37. Adaptação do app orama_fabrica à API (04/10/2026, rodada 11)

O app da fábrica foi reescrito para falar com a `orama_api`. Firebase, MobX, Syncfusion e google_fonts saíram.

### 37.1 O que mudou

- **Arquitetura**: `provider`, `http`, `flutter_secure_storage`, `get_storage`, `intl`. Camadas em `lib/`: `config`, `api`, `auth`, `data`, `pages`, `storage`, `util`.
- **Telas**: login, início, nova entrada (com folha por item e resumo), estoque (saldo e recipientes), histórico e estorno com senha de administrador.
- **Offline**: cada entrada ganha um UUID no aparelho. A fila é gravada localmente e enviada em lotes de 100. A API responde por item `criado`, `ja_registrado` ou `recusado`; reenviar não duplica. Linhas recusadas não são reenviadas sozinhas.
- **Configuração**: `API_URL` por `--dart-define`; em release exige `https://`. HTTP simples só no manifesto de debug do Android.
- **API**: acrescentado CORS (`ORAMA_CORS_ORIGINS`, lista de sites; vazio = nenhum) para a versão web. Token por cabeçalho, sem cookie.

### 37.2 Resultados

| Verificação | Resultado |
|---|---|
| Testes do app | 108 passam, `flutter analyze` limpo, cobertura de linhas 94,0% |
| Teste de contrato contra a API real (descartável) | 8 de 8 |
| Testes da API (`mvn verify`) | 48 passam, cobertura mínima de 80% atendida |
| `flutter build web --release` | compila |

### 37.3 Limites e pontos não verificados

- **Build Android não verificado**: falha aqui porque o SDK do Flutter em `/usr/lib/flutter` é somente leitura. É problema do ambiente, mas não foi confirmado em outra máquina. iOS e desktop também não foram checados.
- Na **web** o token fica no `localStorage` (exposto a XSS). No celular usa armazenamento seguro.
- **Validade** é opcional na entrada: a regra de quando é obrigatória ainda não foi confirmada.
- Os limites de sanidade de peso (100 g a 20 kg) são sugestão minha, não regra do negócio.
- **A API não está no ar**: hospedagem, HTTPS, backups e limite de requisições no proxy continuam em aberto. Nada foi publicado.

### 37.4 Continua em aberto

Planilha `Mapa de itens - revisar.xlsx` (coluna `aceitar`), demais polpas, fatores de caixa/fardo/saco/rolo/tubo, quem separa o pedido de reposição, rota de saída no orama_admin, importação do histórico e impressão de etiquetas.
