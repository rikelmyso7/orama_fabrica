# Feat: etiquetas de recipiente (geração, impressão e leitura)

- **Status:** definição. Nada disto foi implementado ainda.
- **Data:** 04/10/2026
- **App:** `orama_fabrica` (Flutter) e `orama_api` (Spring Boot + PostgreSQL)
- **Relacionado:** `../orama_admin/lib/docs/Plano - novo banco de estoque.md`, seções 33 (recipientes), 34 (etiqueta de hoje) e 37 (adaptação do app)

## 1. Problema

Hoje, ao guardar um balde, cuba ou pote, a etiqueta é impressa e o **lote, o dia e o peso são escritos à mão**. O pedido é que o app faça isso: o operador preenche os dados do item, o app gera a etiqueta no formato de impressão, imprime, e depois a etiqueta pode ser **lida** para conferir a procedência e a validade do produto, tudo ligado ao celular.

## 2. Fluxo desejado

1. O operador escolhe o item e preenche **peso, lote, data de fabricação e validade**.
2. Ao confirmar, o app registra a entrada e **gera a etiqueta** no formato de impressão.
3. O app imprime (uma etiqueta por recipiente) na impressora ligada ao aparelho.
4. A etiqueta é colada no recipiente e guardada na câmara ou na geladeira.
5. Mais tarde, um aparelho **lê a etiqueta** e mostra procedência (item, lote, fabricação), validade e peso. Na saída, a leitura identifica qual recipiente está saindo.

## 3. Decisões tomadas

| # | Decisão | Motivo |
|---|---|---|
| D1 | O código da etiqueta é **gerado no aparelho** (opção B), e não pela API | Permite imprimir **sem internet**. O app já trabalha offline; depender da API para o código travaria a produção se a rede cair. |
| D2 | O QR da etiqueta carrega **só o código curto**. Os dados (lote, peso, validade) são buscados na API | Não dá para falsificar a validade na etiqueta. A etiqueta continua legível a olho, com o texto impresso. |
| D3 | Acrescentar o campo **data de fabricação** | Não existe hoje em banco, API nem app (conferido). O movimento só tem `lote` e `validade`. |
| D4 | Leitura por **câmera do celular e por leitor Bluetooth em modo teclado** | A câmera não exige hardware. O modo teclado serve para leitor dedicado, sem SDK de marca. |
| D5 | Impressão por **transferência térmica**, fita de **resina**, etiqueta **sintética (polipropileno)** com adesivo para congelados | Térmica direta desbota; papel solta com condensação. É o requisito: a etiqueta não pode descolar nem desbotar no frio. |
| D6 | Se a impressão falhar, **o recipiente continua registrado** e dá para **reimprimir** | A entrada e a impressão são coisas separadas. |
| D7 | O peso continua **digitado** por enquanto | Integração com balança fica como melhoria. |

D1 foi escolhida pelo usuário ("B"). D2 a D7 são minhas propostas aceitas no fluxo da conversa, e podem ser ajustadas.

## 4. Código da etiqueta gerado no aparelho (D1)

Hoje a API gera `R000001` com uma sequência no banco (`seq_etiqueta_recipiente`, coluna `etiqueta`, índice único). Sequência única só existe no servidor; vários aparelhos offline não podem compartilhá-la. Por isso o desenho abaixo é uma **proposta minha**, a confirmar antes de implementar:

- O app gera um código aleatório curto, por exemplo `R` + 8 caracteres de um alfabeto sem ambiguidade (sem `0/O`, `1/I/L`). É legível à mão se o QR falhar.
- O código é guardado junto com o UUID da entrada na fila local e **enviado junto** na entrada.
- A API aceita o código do app se ele for novo. O índice único já existente continua garantindo que não se repita.
- **Reenvio da mesma entrada** (mesmo UUID e mesmo código): resposta `ja_registrado`, sem duplicar.
- **Colisão** (outro recipiente já usa o código): a linha é `recusada` com um motivo claro, e o app gera outro código e reimprime. Com 8 caracteres de 32 símbolos (cerca de 10^12 combinações), a chance é desprezível, mas a regra precisa existir.
- Itens sem código vindo do app (versões antigas ou outras rotas) continuam recebendo `R000001...` do servidor, para não quebrar o que já existe.

**Impacto:** muda a regra do trigger de entrada, que hoje **sempre** gera a etiqueta quando o item é controlado por recipiente. Isso exige migração (V5), ajuste da API e testes novos, inclusive de reenvio e colisão.

## 5. Conteúdo da etiqueta

Proposta, a confirmar com o usuário:

- Item (nome e código)
- Lote
- Data de fabricação
- Validade
- Peso (em gramas, convertido para exibição)
- Código da etiqueta (texto) e **QR do código**
- Local de armazenamento, se couber

O tamanho final depende da etiqueta física comprada (balde, cuba e pote podem usar tamanhos diferentes).

## 6. Mudanças previstas

### Banco e API (`orama_api`)
- Migração V5: coluna `data_fabricacao date` em `stock_movements` e aceitar etiqueta enviada pelo app (D1, D3).
- `POST /entradas`: campo opcional `dataFabricacao` e `etiqueta`; validações (fabricação não posterior a hoje, validade não anterior à fabricação).
- Rota de busca de recipiente **por código da etiqueta**. Hoje existe a lista (`GET /recipientes`); a busca por código não foi confirmada.
- Reimpressão: rota que devolve os dados da etiqueta de um recipiente, com registro de quem reimprimiu.
- Testes de integração para: fabricação, código vindo do app, reenvio, colisão, busca por código, reimpressão.

### App (`orama_fabrica`)
- Campo de data de fabricação na folha do item.
- Geração do código no aparelho e gravação na fila offline (`data/fila_entradas`, `entrada_pendente`).
- Módulo de etiqueta: layout, QR e pré-visualização.
- Envio à impressora (ZPL para Zebra, ESC/POS para as demais, a definir pelo modelo comprado).
- Tela de leitura de etiqueta (câmera + modo teclado) com resultado: procedência, lote, fabricação, validade e peso.
- Reimpressão a partir do estoque ou do histórico.

## 7. Hardware (o que precisa ser comprado e testado)

Pesquisa feita nesta conversa; **preços e disponibilidade não foram confirmados**.

| Item | Requisito | Observação |
|---|---|---|
| Impressora de etiquetas | Transferência térmica, com Bluetooth (ou USB/Wi-Fi) | Exemplos citados: Zebra ZD421, Brother TD-4650TNWB. Confirmar o código exato com Bluetooth. |
| Fita | **Resina** | Resistente a umidade, atrito e frio. |
| Etiqueta | Sintética (polipropileno), adesivo para congelados | Testar na câmara por 1 a 2 semanas, com condensação. |
| Leitor | Câmera do celular, ou leitor Bluetooth em **modo teclado** que leia QR (2D) | Leitor só de código de barras linear não serve para QR. |
| PDA Android (opcional) | Roda o app, tem leitor embutido | Ver seção 8. |

**Regra de uso no frio:** imprimir e conferir **fora** da câmara sempre que possível. Celular e leitor têm limite de temperatura e sofrem com condensação ao sair do frio.

## 8. PDA em avaliação: Yokoscan TC60-HC

Ficha oficial do fabricante (PDF, atualizada em 06/03/2025):

| Item | Dado |
|---|---|
| Sistema | Android 14, com Google GMS (Google Play) |
| Hardware | MTK8781 octa-core, 4 GB RAM + 64 GB, tela 5,9" |
| Conexão | Wi-Fi dual-band, 4G, Bluetooth 5.2, NFC |
| Leitor | 2D, lê QR, Data Matrix, Code128 e outros |
| Proteção | IP67, queda de 1,5 m, tela que aceita luva e mão molhada |
| Temperatura | **Operação -20 °C a +50 °C**; armazenamento -40 °C a +70 °C |
| Umidade | 5% a 95% **sem condensação** |
| Desenvolvimento | SDK Java, Android Studio |

**Conclusões:**
- O app roda no aparelho (Android 14; o app exige Android 7, `minSdk` 24).
- A câmara a -18 °C cabe na faixa, mas **perto do limite**, sem aquecimento de tela, e a ficha **não cobre condensação**. Serve para ler fora da câmara ou com entradas ocasionais. Não é uma boa escolha para entrar e sair da câmara várias vezes por dia.
- **Ponto não resolvido: modo teclado.** A ficha cita só SDK; nada sobre keyboard wedge, broadcast ou app de configuração do leitor. Isso decide se a leitura é simples ou exige integrar o SDK deles.
- Alternativas com versão para frio, citadas na pesquisa (não verificadas em loja): Urovo RT40 Cold/RT40S Pro (até -30 °C, com aquecimento de tela), Honeywell CN80 cold storage (-30 °C a 50 °C).

**Ação:** perguntar ao fabricante (sales@yokoscan.com) se o leitor tem modo teclado com prefixo/sufixo, e se há versão para câmara fria. Se sim, comprar **uma unidade** para teste, com política de devolução.

## 9. Rede e infraestrutura

- O app consulta a API para ler etiqueta, então precisa de **Wi-Fi onde se pesa, imprime e lê**.
- **Dentro da câmara** o sinal costuma falhar (paredes e portas metálicas). Decisão pendente: ler só fora da câmara, ou guardar uma cópia dos recipientes no aparelho.
- **A API ainda não está no ar** (hoje só local). Hospedagem, HTTPS, backups e limite de requisições continuam em aberto.
- Na versão **web** do app, impressão por Bluetooth é limitada e no iPhone praticamente não funciona. O recurso de impressão deve rodar como **app Android**.

## 10. Plano de entrega sugerido

1. Campo de data de fabricação (banco, API, tela) e testes.
2. Código da etiqueta gerado no aparelho (D1), com reenvio e colisão, e testes.
3. Layout da etiqueta e pré-visualização na tela (valida com o usuário sem depender do hardware).
4. Tela de leitura: câmera primeiro; modo teclado quando houver aparelho para testar.
5. Impressão real, quando a impressora estiver escolhida e testada.
6. Reimpressão.
7. Rota de saída por leitura (depende da reposição no `orama_admin`, ainda não feita).

## 11. Perguntas em aberto

1. Qual o **tamanho da etiqueta** para balde, cuba e pote?
2. O que deve aparecer escrito, além do QR (seção 5)?
3. A **balança** tem saída digital (Bluetooth, USB, serial)? Se sim, o peso pode vir direto ao app.
4. Há **Wi-Fi dentro da câmara**?
5. Quantas etiquetas por dia (dimensiona impressora e rolos)?
6. O modelo de impressora a comprar, e se terá Bluetooth, USB ou Wi-Fi.
7. Confirmar o formato do código da seção 4.
8. Qual aparelho de leitura será usado (câmera, leitor Bluetooth ou PDA)?

## 12. Riscos e o que não foi verificado

- Nenhum equipamento foi testado. As indicações de modelos vêm de pesquisa na internet e de fichas de fabricante, sem confirmação de preço, estoque ou compra no Brasil.
- Nenhuma etiqueta foi testada no frio. O desempenho de fita, etiqueta e adesivo precisa de teste na câmara real.
- O build Android do app não foi verificado nesta máquina (SDK do Flutter somente leitura). Isso precisa ser resolvido antes de testar em um aparelho.
- Plugins Flutter de impressão Bluetooth têm qualidade variável. Testar com a impressora real antes de fechar o modelo.

## 13. Atualização do app por versionamento no GitHub

**Decisão (D8):** as atualizações do app serão distribuídas por **versões no GitHub (Releases)**, do mesmo jeito que já é feito no `catuai-app`. Não haverá loja de aplicativos. Isso combina com o uso em PDA ou celular da fábrica, onde o APK é instalado direto.

### 13.1 Como o catuai-app faz (conferido no código)

- **Versão**: fica no `pubspec.yaml` (`version: 2.3.2+1`). O número antes do `+` é a versão publicada.
- **Workflow `.github/workflows/release.yml`**, a cada push na `main`:
  1. lê a versão do `pubspec.yaml` e cria a tag `vX.Y.Z` **se ela ainda não existir** (se já existe, pula o release);
  2. roda `flutter analyze` e os testes;
  3. monta o ambiente de produção a partir de *secrets* do GitHub, restaura o keystore e gera **APK e AAB assinados**;
  4. gera as **notas de versão** agrupando os commits por tipo (`feat`, `fix`, `perf`, `refactor`...) desde a tag anterior;
  5. cria o **GitHub Release** com o APK, o AAB e as notas.
- **No app** (`UpdateService`): consulta `releases/latest` do repositório, compara a tag com a versão instalada (`package_info_plus`), e, se for maior, oferece a atualização com as notas. O APK é baixado do Release e instalado pelo instalador do Android (`app_installer`).

### 13.2 O que isso exige no orama_fabrica

Hoje o `orama_fabrica` **não tem** nada disso: não há pasta `.github`, nem workflow, e a versão está em `1.0.0+1`. Para adotar o mesmo modelo:

1. **Workflow de release** equivalente ao do catuai-app, adaptado ao `orama_fabrica` (Flutter 3.38.1, análise, os 108 testes, build assinado).
2. **Assinatura do Android**: criar um keystore **próprio** do `orama_fabrica` e guardar em *secrets* (keystore em base64, senhas e alias). **Guardar o keystore com backup**: sem ele, não dá para publicar atualizações do mesmo app. **Nunca** versioná-lo no repositório.
3. **Configuração de produção** (`API_URL` com `https://`) vinda de *secret* ou arquivo de ambiente no build, não gravada no repositório.
4. **Regra de versão**: cada mudança entregue sobe a versão no `pubspec.yaml`. Sem subir, o workflow pula o release (como no catuai-app).
5. **Mensagens de commit no padrão convencional** (`feat:`, `fix:`...), que é o que alimenta as notas de versão. Já é o padrão pedido nas regras do projeto.
6. **Verificação do build Android**: precisa funcionar numa máquina ou no CI antes do primeiro release (nesta máquina o SDK do Flutter é somente leitura e o build Android falhou).
7. **Atualização dentro do app**: consulta ao GitHub, comparação de versão, download e instalação do APK, como no `UpdateService`.
8. **Permissão no Android** para instalar APK fora da loja (o usuário precisa autorizar uma vez nas configurações do aparelho).

### 13.3 Cuidado: o token do GitHub no app

O `UpdateService` do catuai-app envia um `githubToken` vindo da configuração (`Env.githubToken`) quando ele existe, o que sugere um repositório privado. **Um token dentro do app pode ser extraído do APK por qualquer pessoa que tenha o aplicativo**. Para o `orama_fabrica`, recomendo:

- **Preferir** repositório (ou pelo menos os Releases) **público**, o que dispensa token. Isso só é aceitável se o código não tiver segredos, o que o projeto já exige.
- Se o repositório precisar ser privado: **não** embutir um token no app. Servir o APK por um endereço próprio (por exemplo, uma rota da `orama_api` que repassa o Release), com autenticação do usuário do app.

Isso é uma decisão a tomar antes do primeiro release. Não verifiquei se o repositório `orama_fabrica` no GitHub é público ou privado.

### 13.4 Impacto na entrega desta feat

- O release assinado e a atualização dentro do app entram **antes** de distribuir o app para os aparelhos da fábrica. Sem isso, cada correção exigiria instalar o APK à mão.
- A atualização exige que o aparelho consiga chegar ao GitHub (ou à API, se esta servir o APK). Dentro da câmara não há garantia de sinal (seção 9); atualizar pelo Wi-Fi da fábrica.
- Após o primeiro APK, a fila offline e o rascunho de entrada guardados no aparelho devem **sobreviver à atualização**, já que são dados locais do app. É preciso um teste para confirmar isso.
- A migração de banco (V5) e a versão do app precisam andar juntas: a API deve continuar aceitando entradas de versões antigas do app durante a troca (seção 4, itens sem código do app).

### 13.5 Perguntas em aberto

1. O repositório `orama_fabrica` no GitHub é público ou privado? Se for privado, como servir o APK sem embutir token?
2. Quem guarda o keystore e o backup dele?
3. A atualização deve ser **obrigatória** (bloqueia o uso até atualizar) ou **opcional** (aviso)? O catuai-app oferece a atualização com as notas; não conferi se é obrigatória.
