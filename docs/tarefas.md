# Racha App — Lista de tarefas

> Levantada em 22/08/2026 a partir de uma auditoria do código. Cada item tem
> **onde** está o problema, **o que fazer** e **como verificar** que ficou
> resolvido. Marque o checkbox quando concluir.
>
> Ordem sugerida: bloco 1 primeiro (é o que faz o app cumprir a promessa
> principal), depois o bloco 2, e o bloco 3 quando sobrar fôlego.

---

## Bloco 1 — O balanceamento não está funcionando de verdade

Estas duas tarefas são a mesma história: o algoritmo de times existe, roda e
tem teste passando, mas está recebendo dados vazios nas duas pontas. É o
diferencial do projeto, então vem primeiro.

### [x] T1 — Ligar a nota real de cada jogador à geração de times

**Problema:** todo jogador entra no balanceamento com a mesma nota fixa. As
avaliações são coletadas, viram média e alimentam o ranking — mas o
balanceador nunca lê essa média. O Estágio 2 do algoritmo (equilibrar por
nota) hoje não equilibra nada.

**Onde:** `lib/providers/times_controller.dart` — `gerar()`, nas duas
atribuições `nota: notaNeutra` (participantes e convidados).

**O que fazer:**
- Buscar `rankings/{userId}.mediaAvaliacoes` de cada participante (User) e
  passar esse valor em `JogadorElegivel.nota`.
- Manter `notaNeutra` só como fallback: quem ainda não tem ranking (jogador
  novo) e todo Convidado continuam entrando com a nota neutra.
- Evitar uma leitura por jogador em sequência — juntar os ids e buscar de
  uma vez, ou pelo menos disparar em paralelo.
- Atualizar o comentário de `lib/core/constants/balanceamento_constants.dart`,
  que ainda afirma que "o sistema de Avaliação/Ranking ainda não existe".

**Como verificar:** criar um racha com jogadores de médias bem diferentes e
conferir que a soma das notas dos dois times fica próxima.

**Feito em 22/08/2026:** `TimesController.gerar` busca `rankings` e `users` em
paralelo (`buscarVarios` nos dois repositórios) e passa a média real em
`JogadorElegivel.nota`. Nota neutra continua valendo para Convidado, para quem
nunca foi avaliado e para ranking existente com média zero (zero ali quer
dizer "sem histórico"). Comentário de `balanceamento_constants.dart`
atualizado.

---

### [x] T2 — Pedir a posição do jogador na confirmação de presença

**Problema:** definir posição é opcional e fica escondido atrás de um botão
que só aparece depois de confirmar presença. Se ninguém preencher, o Estágio
1 do algoritmo (garantir um goleiro em cada time) roda sem nenhum dado.

**Onde:** `lib/screens/racha/racha_tabs_section.dart` — `_ParticipanteTile`,
botão "Definir posição" e o fluxo de confirmar presença.

**O que fazer:**
- Ao confirmar presença, abrir o diálogo de posição na sequência (ou pedir a
  posição antes de gravar a confirmação).
- Deixar visível na lista quem confirmou mas ainda não escolheu posição.
- Decidir e documentar o comportamento quando não há nenhum goleiro entre os
  confirmados: avisar o admin antes de gerar os times.

**Como verificar:** confirmar presença como um jogador novo e checar que o
app pede a posição sem precisar procurar o botão.

**Feito em 22/08/2026:** confirmar presença abre o diálogo de posição, que
mostra a formação do racha (tipo de campo + jogadores de linha); sem escolher
a principal não dá pra salvar, e cancelar não confirma a presença. Quem já
tem posição não é perguntado de novo, e continua podendo editar. Confirmados
sem posição aparecem marcados na lista, e o admin recebe um aviso na aba
Times quando falta goleiro ou há gente sem posição.

O algoritmo passou a raciocinar por **setor** (`lib/core/balanceamento/setores.dart`):
a posição main manda, a secundária só é usada para reforçar um setor em
falta, e sai primeiro quem tem nota menor. Ver a seção "Geração de times" em
`docs/status_atual.md` para a regra completa.

---

## Bloco 2 — Lacunas de fluxo

### [x] T3 — Remover membro fixo deve tirar da rodada aberta

**Problema:** aprovar uma solicitação adiciona a pessoa à lista de membros
fixos **e** à rodada aberta atual. Remover só tira da lista — ela continua
convidada na rodada em andamento. As duas ações deveriam ser simétricas.

**Onde:** `GrupoController.removerMembroFixo` (`lib/providers/grupo_controller.dart`),
comparar com `SolicitacaoController.aprovar`.

**O que fazer:** ao remover o membro fixo, remover também o participante da
rodada aberta, se ele ainda estiver pendente. Se já confirmou presença, vale
perguntar ao admin antes de tirar.

**Feito em 22/08/2026:** `GrupoController.removerMembroFixo` ganhou o
parâmetro `removerDaRodadaAberta` (padrão `true`) e agora tira o participante
da rodada em andamento junto — o inverso exato de
`SolicitacaoController.aprovar`. Quem está pendente ou recusou sai das duas
coisas direto; quem **já confirmou presença** gera um diálogo com três saídas
(Cancelar / "Deixar jogar essa" / "Tirar das duas"), porque tirar alguém que
se comprometeu com o jogo é decisão do admin, não efeito colateral. A tela dá
retorno por SnackBar dizendo o que aconteceu.

---

### [x] T4 — `entrarComCodigo` aceita racha já finalizado

**Problema:** quem tiver o código consegue entrar e se autoconfirmar num
racha encerrado.

**Onde:** `RachaController.entrarComCodigo` (`lib/providers/racha_controller.dart`).

**O que fazer:** recusar a entrada quando `racha.status == finalizado`, com
mensagem clara ("esse racha já foi encerrado").

**Feito em 22/08/2026:** `entrarComCodigo` lança a exceção com essa mensagem
antes de criar qualquer participante. Além do dado sujo, entrar num racha
encerrado colocaria a pessoa na conta de quem pode avaliar a rodada.

---

### [x] T5 — Pedido de entrada recusado pode ser refeito sem limite

**Problema:** o bloqueio de pedido duplicado só considera solicitações
pendentes. Depois de uma recusa, dá para pedir de novo indefinidamente.

**Onde:** `SolicitacaoController.solicitar` (`lib/providers/solicitacao_controller.dart`).

**O que fazer:** definir uma regra — por exemplo, não permitir novo pedido
antes de alguns dias após a recusa, ou exigir que o admin reabra. Refletir a
decisão no botão da aba "Rachas Próximos".

**Decisão:** recusa não expira — só o admin reabre. Um prazo fixo erraria nos
dois sentidos (curto demais pra quem foi recusado porque o racha estava cheio
naquela semana, longo demais pra quando o grupo precisa da pessoa no sábado
seguinte). Deixando na mão do admin, a regra vale tanto pra um dia quanto pra
um ano.

**Feito em 22/08/2026:** `buscarMinhaSolicitacao` virou
`buscarUltimaSolicitacao` (sem filtro de status, ordenando no cliente) e
`solicitar` passou a bloquear tanto pendente quanto recusado — devolvendo
`ResultadoSolicitacao.recusadoAntes`. Na aba "Rachas Próximos" o botão fica
desabilitado como "Pedido recusado". Na tela do grupo o admin ganhou a seção
**Pedidos recusados**, com um botão "Reabrir" que devolve o pedido à fila de
pendentes (`SolicitacaoController.reabrir`).

Um pedido **aprovado** antigo não bloqueia: se o admin remover a pessoa dos
membros fixos depois, ela consegue pedir entrada de novo.

---

### [x] T6 — Apagar grupo deixa as solicitações órfãs

**Problema:** ao apagar o grupo, a subcoleção `solicitacoes` continua
existindo no Firestore, e as regras proíbem apagá-la (`allow delete: if false`).
As rodadas órfãs são intencionais e estão documentadas; essas não.

**Onde:** `GrupoRepository.remover` e a regra de `solicitacoes` em
`firestore.rules`.

**O que fazer:** apagar as solicitações junto com o grupo (liberando delete
para o admin do grupo na regra), ou aceitar conscientemente e registrar isso
como decisão em `docs/status_atual.md`.

**Feito em 22/08/2026:** `GrupoController.remover` passou a montar um batch
único que apaga todos os pedidos, cria os avisos e apaga o grupo. A regra de
`solicitacoes` liberou `delete` para o admin do grupo.

Junto veio o pedido de **avisar quem estava esperando**: sem isso o racha
sumia da busca e a pessoa nunca saberia se foi recusada ou se o grupo acabou.
Como o pedido é apagado, não sobra documento nenhum para contar a história —
então nasceu `AvisoModel` (`users/{userId}/avisos`), um recado curto com
mensagem e data, que aparece no sino da Home junto com os convites e some
quando a pessoa dispensa. Só quem tinha pedido **pendente** é avisado; quem
já havia sido recusado não, porque aquela conversa já tinha terminado.

---

### [ ] T7 — `totalRachas` conta rodadas avaliadas, não jogadas

> **Revisão de 22/08/2026:** a auditoria exagerou o problema. As telas já
> exibem o número como "racha(s) avaliado(s)", que é exatamente o que ele é —
> nenhuma tela mente para o usuário. Quem mente é o **nome do campo**.
>
> **Decisão de 23/08/2026: absorvida pelo Bloco 4.** Com o app indo para a
> Play Store e com a mecânica de "ponta firme" entrando em cena, presença
> deixou de ser um número de exibição e virou regra do jogo. O contador de
> rodadas jogadas nasce como parte da pontuação de presença (T16), e o campo
> atual passa a se chamar `totalRachasAvaliados` junto com essa mudança.
>
> **Cuidado aprendido:** renomear campo citado no `firestore.rules` exige
> subir código e regras juntos. Uma tentativa isolada quebrou as escritas de
> ranking em produção por alguns minutos.

**Problema:** o total de rachas de um jogador é derivado das avaliações que
ele recebeu. Quem jogou mas não foi avaliado por ninguém aparece com zero.

**Onde:** `RankingController.recalcularParaAvaliado`
(`lib/providers/ranking_controller.dart`) e o cálculo equivalente dentro de
`rankingDoGrupoProvider` (`lib/providers/firebase_providers.dart`).

**O que fazer:** contar as participações confirmadas em rachas finalizados,
não as avaliações recebidas. Se resolver a T8 antes, esse cálculo passa a
existir num lugar só.

---

## Bloco 3 — Redundâncias e limpeza

### [x] T8 — Dois sistemas de ranking convivendo

**Problema:** existe o `rankings/{userId}`, persistido e atualizado a cada
avaliação/estatística, e existe o `rankingDoGrupoProvider`, que recalcula
tudo do zero a cada abertura da tela e ignora o documento persistido. A mesma
agregação (média, gols, assistências, MVPs) está escrita em dois lugares, com
regras de contagem levemente diferentes. Hoje o documento global só alimenta
a tela de Perfil.

**Onde:** `lib/providers/ranking_controller.dart`,
`lib/repositories/ranking_repository.dart` e `rankingDoGrupoProvider` em
`lib/providers/firebase_providers.dart`.

**O que fazer:** escolher **uma** estratégia e seguir com ela.
- Opção A (mais simples): manter só o cálculo sob demanda e apagar a coleção
  `rankings`. O Perfil passa a somar todos os grupos do jogador.
- Opção B: manter o documento persistido e fazer o ranking do grupo derivar
  dele, em vez de recalcular.

A opção A elimina mais código, inclusive o contorno do `increment(0)` (T9) e
boa parte das regras de `rankings` no `firestore.rules`.

**Correção:** a opção B, como escrita acima, não é possível. O documento
persistido é **global** (todos os rachas do jogador, de qualquer grupo) e o
ranking do grupo é um recorte **por grupo** — de uma média global não se
extrai a média dentro de um grupo. Os dois não são a mesma informação
calculada duas vezes; o que estava duplicado era o **código** da agregação.
A T1, feita depois desta tarefa ser escrita, ainda tornou a opção A cara: o
balanceamento passou a ler `rankings/{userId}` pra montar os times, e sem o
documento isso viraria uma consulta por jogador no clique de "Gerar times".

**Decisão (22/08/2026): unificar só o cálculo.**

**Feito em 22/08/2026:** nasceu `lib/core/ranking/agregador_ranking.dart` —
função pura que recebe avaliações, estatísticas e a lista de MVPs e devolve
um `RankingModel` por jogador. Os dois recortes passam por ela, então nenhum
jogador aparece com número diferente dependendo da tela.

Do lado do ranking global, os três caminhos parciais viraram um só:
`RankingController.recalcularRanking(userId)` refaz tudo do zero a partir da
fonte de verdade (avaliações recebidas, estatísticas e rachas em que a pessoa
foi MVP). Sumiram `recalcularParaAvaliado`, `recalcularEstatisticas` e
`incrementarMvp`. O recálculo completo é idempotente e se autocorrige — nada
é derivado do valor anterior —, o que dispensa o incremento atômico que
existia pro MVP. `RachaRepository.buscarPorMvp` conta os títulos a partir de
`rachas.mvpUserId`.

Seis testes novos em `test/core/ranking/agregador_ranking_test.dart`.

---

### [x] T9 — `incrementarMvp` grava `increment(0)` em quatro campos

**Problema:** contorno para as regras do Firestore exigirem todos os campos
presentes em qualquer escrita. Funciona, mas é sintoma da T8.

**Onde:** `RankingRepository.incrementarMvp` (`lib/repositories/ranking_repository.dart`).

**O que fazer:** resolver junto com a T8. Se a opção A for escolhida, o
método deixa de existir.

**Feito em 22/08/2026:** o método foi removido junto com a T8. O recálculo
completo grava o documento inteiro, então não existe mais o problema de
precisar preencher campos que a escrita não ia tocar.

---

### [x] T10 — Criação de racha duplicada entre grupo e avulso

**Problema:** `GrupoController.criar` e `RachaController.criar` repetem a
mesma sequência: cria o racha e insere o admin como participante já
confirmado.

**Onde:** `lib/providers/grupo_controller.dart` e `lib/providers/racha_controller.dart`.

**O que fazer:** extrair essa sequência para um único lugar (o
`RachaRepository` ou um método compartilhado), para que a regra de como um
racha nasce viva num ponto só.

**Feito em 22/08/2026:** nasceu `lib/providers/criar_racha_com_admin.dart`,
usado pelos dois controllers. As duas escritas agora vão num `WriteBatch` —
antes eram soltas, e uma falha de rede no meio deixava um racha sem nenhum
participante.

**Mudança de regra pedida junto:** o admin **não nasce mais confirmado**. A
suposição de que quem organiza sempre joga estava errada — e tinha dois
efeitos colaterais: inflava a contagem de confirmados que libera a geração de
times, e deixava o organizador como o único jogador garantidamente sem
posição definida, já que ele pulava a tela de confirmação (que é onde a
posição é escolhida, desde a T2). Agora ele é convidado como qualquer um,
inclusive nas rodadas geradas automaticamente pelo Fluxo 5.

---

### [x] T11 — Duas leituras da mesma solicitação

**Problema:** `buscarMinhaSolicitacao` (one-shot, usada no dedup do
controller) e `observarMinhaSolicitacao` (stream, usada no botão da tela)
leem o mesmo dado de formas diferentes.

**Onde:** `lib/repositories/solicitacao_repository.dart`.

**O que fazer:** avaliar se dá para o controller reaproveitar o stream e
manter só um método. Baixa prioridade — a duplicação é pequena e tem
justificativa.

**Feito em 22/08/2026:** os dois métodos continuam existindo, porque os dois
usos são legítimos (leitura única na hora de gravar, stream na tela). O que
saiu foi a duplicação real: filtro e ordenação agora vivem num único
`_meusPedidos`, do qual os dois derivam. Se divergissem, o botão diria uma
coisa e a gravação faria outra.

---

### [ ] T12 — Documentação desatualizada

**Problema:** `docs/status_atual.md` afirma que "o ranking global de usuário
foi removido", mas a coleção `rankings` continua existindo e é exibida na
tela de Perfil. O comentário em `balanceamento_constants.dart` diz que
Avaliação/Ranking ainda não existem.

**O que fazer:** corrigir os dois textos depois que T1 e T8 estiverem
decididas — assim a documentação passa a descrever o estado final, não um
intermediário.

---

### [x] T13 — Ranking do grupo custava 1+2N consultas

**Problema (descoberto durante a T8):** o `rankingDoGrupoProvider` listava as
rodadas do grupo e, para cada uma, buscava as avaliações e as estatísticas.
Um grupo com um ano de racha semanal (50 rodadas) fazia 101 consultas toda
vez que alguém abria a tela de ranking — e crescia para sempre.

A causa é que `avaliacoes` e `estatisticas` só sabiam a qual **racha**
pertenciam, nunca a qual grupo.

**Feito em 22/08/2026:** `AvaliacaoModel` e `EstatisticaModel` ganharam o
campo `grupoId` (nulo em racha avulso), copiado do racha na hora de gravar.
Com isso `buscarPorGrupo` traz tudo numa consulta `collectionGroup`, e o
ranking do grupo passou a fazer **três consultas fixas** (rodadas, avaliações,
estatísticas), independentemente do tamanho do histórico — a lista de rodadas
continua necessária porque os títulos de MVP moram no próprio racha.

Índices `COLLECTION_GROUP` para `avaliacoes.grupoId` e `estatisticas.grupoId`
adicionados em `firestore.indexes.json`. As regras validam que o `grupoId`
gravado bate com o do racha (`grupoDoRacha`), senão daria pra carimbar uma
avaliação com o grupo de outra galera e poluir o ranking alheio — custa uma
leitura por escrita.

**Feito com o banco vazio de propósito:** documentos antigos não têm o campo e
sairiam do ranking. Como o conteúdo do Firestore era descartável, não houve
migração. Se o app já tivesse histórico real, isso exigiria um script de
backfill.

---

## Bloco 4 — Pontualidade e prioridade (o "ponta firme")

Vem de como o racha do Gustavo já funciona hoje, na planilha: quem chega no
horário e dificilmente falta tem prioridade para jogar; quem falta ou atrasa
começa no banco ou entra no segundo tempo.

O app hoje não tem nenhuma dessas informações. Ele sabe quem **disse que ia**
(`statusConfirmacao`, marcado dias antes) e nada além disso. Em particular,
não distingue **recusar com antecedência** — respeitável, o organizador se
reorganiza — de **confirmar e dar cano**, que é o que de fato estraga a
rodada. Ser ponta firme não é jogar muito: é ser previsível.

**Decisões já tomadas (23/08/2026):**
- A pontuação de presença é um **eixo separado** da nota de habilidade. A
  média de avaliação responde "joga bem?" e equilibra os times; a pontuação
  de presença responde "posso contar com você?" e decide quem joga. Misturar
  faria um jogador fraco e assíduo parecer craque para o algoritmo, o que
  desfaria o balanceamento da T1.
- A chamada é feita pelo organizador, que **pode delegar** a dois ou três
  jogadores de confiança (os que hoje cuidam da planilha).
- Sobrando gente, o app escala por prioridade e monta um **banco ordenado**,
  que é a ordem de entrada.
- A pontuação usa **janela móvel das últimas 10 rodadas** do grupo, não saldo
  acumulado. Só o comportamento recente conta: quem sumiu e voltou firme
  recupera a prioridade, quem era firme e começou a furar perde rápido, e
  jogador novo não fica eternamente atrás de quem joga há dois anos.
- **Atraso custa a vaga do dia, mas os pontos continuam mandando.** A
  prioridade da rodada é a pontuação da janela, com um desconto para quem
  chegou atrasado — um atrasado bem pontuado ainda passa na frente de um
  pontual de pontuação baixa.

**Escala de pontos (ponto de partida, fácil de calibrar depois):**

| situação | pontos |
|---|---|
| Compareceu no horário | +3 |
| Compareceu atrasado | +1 |
| Recusou com antecedência | 0 |
| Confirmou e não apareceu | −5 |
| Nem respondeu ao convite | −1 |

Duas intenções por trás dos números, que importam mais que os valores: o cano
pesa mais do que a presença premia, porque o organizador contou com a pessoa e
deixou de chamar outra; e recusar com antecedência é **neutro, não negativo** —
punir quem avisa ensina o jogador a ficar calado, que é o pior resultado
possível para quem organiza.

### [x] T14 — Registrar a presença real no dia

**O que falta:** um estado por participante além da confirmação prévia —
`compareceu`, `atrasou`, `faltou`. É isso que separa o cano da recusa
antecipada, hoje indistinguíveis.

**Onde:** `ParticipanteModel` ganha o campo; a aba Participantes ganha uma
lista de chamada, que só faz sentido aparecer a partir do horário do racha.

**A decidir:** o app deve cobrar a chamada de quem esqueceu? Uma rodada
finalizada sem chamada não gera pontuação nenhuma.

**Feito em 23/08/2026:** enum `PresencaFinal` (compareceu/atrasou/faltou) e o
campo `presenca` em `ParticipanteModel` — nulo enquanto a chamada não é feita,
e nulo numa rodada finalizada significa "ninguém fez a chamada", não "faltou".
A aba Participantes ganhou o botão **Fazer chamada**, que só aparece a partir
do horário do racha e só pra quem tem permissão. A folha lista apenas quem
**confirmou presença** — quem recusou com antecedência não está sendo cobrado
de nada — e mostra quantos ainda faltam registrar. O estado aparece como chip
colorido na lista de participantes.

A regra do Firestore impede o jogador de registrar a própria presença; se
pudesse, o sistema de pontualidade não valeria nada.

### [x] T15 — Anotadores: delegar a chamada

**O que falta:** hoje só o `adminId` escreve. Precisa de um papel adicional
com permissão para registrar presença — e só isso, não para editar o racha.

**Encaminhamento sugerido:** guardar a lista no Grupo (`auxiliares`) e copiar
para o racha na criação, mesmo padrão do `grupoId` da T13 — assim a regra do
Firestore resolve com uma leitura em vez de duas. Racha avulso pode ter
anotador próprio pelo mesmo campo.

**Feito em 23/08/2026:** foi por esse caminho. `GrupoModel.auxiliares` e
`RachaModel.anotadores`, com a lista copiada quando a rodada nasce. O admin
liga e desliga a permissão pelo ícone de prancheta ao lado de cada membro
fixo, e a mudança **também é gravada na rodada aberta** — senão delegar a
chamada só passaria a valer na semana seguinte, inútil no dia em que o admin
percebe que não vai dar conta da lista sozinho.

A permissão é estreita de propósito: a regra exige que a escrita do anotador
toque **apenas** o campo `presenca`. Ele não edita o racha, não aprova
entrada, não mexe em time nem em posição de ninguém.

### [ ] T16 — Pontuação de presença

**Depende de:** T14 (sem chamada não há o que pontuar).

**A definir com o Gustavo:** a escala de pontos e se a conta é acumulada ou
por janela móvel das últimas rodadas.

Absorve a T7: o contador de rodadas jogadas nasce aqui, e o campo antigo
`totalRachas` passa a se chamar `totalRachasAvaliados`.

### [ ] T17 — Banco ordenado por prioridade

**O que falta:** hoje **nada limita o elenco**. O `qtdJogadoresLinha` só
alimenta o alvo por setor — se 18 pessoas confirmarem num society de 7v7, o
balanceador monta dois times de 9 e ninguém fica de fora. O conceito de não
jogar nunca foi modelado.

**Onde:** `ResultadoBalanceamento` ganha um terceiro campo (`banco`), e
`BalanceadorTimes.gerar` passa a receber o limite de vagas. Quem tem
pontuação de presença menor fica fora, na ordem em que entraria.

---

## Bloco 5 — Pré-requisitos para publicar na Play Store

Levantado em 23/08/2026, quando o projeto deixou de ser só trabalho de
faculdade; ampliado em 24/08/2026 com T23–T27.

Os itens não têm todos a mesma urgência, e o critério não é "o app estar
evoluído" — são duas linhas de corte distintas. **O primeiro upload no Play
Console** congela T18 e T19 para sempre. **O primeiro usuário real** transforma
T23 (e qualquer mudança de modelo de dados) em migração. T20 e T21 encarecem a
cada feature nova, porque cada uma escreve mais dados calculados no cliente e
em mais lugares. O resto — T22, T24, T25, T26, T27 — tem custo fixo e depende
do conjunto de features estar fechado, então é trabalho de reta final.

### [x] T18 — Trocar o `applicationId`

Hoje é `com.example.racha_app`. O Google **rejeita** qualquer pacote que
comece com `com.example`. E o applicationId é a identidade permanente do app
na loja: depois de publicado, mudar significa publicar um app novo, do zero,
perdendo instalações, avaliações e histórico. **É o único item verdadeiramente
irreversível da lista.**

**Feito em 24/08/2026.** Novo pacote: `com.gustavodias.rachaapp`. Mudou em
quatro lugares — `namespace` e `applicationId` em `android/app/build.gradle.kts`,
o caminho e o `package` de `MainActivity.kt` (agora em
`android/app/src/main/kotlin/com/gustavodias/rachaapp/`) e o
`userAgentPackageName` do `TileLayer` em `localizacao_picker_screen.dart`.
Junto foi o `android:label`, que era literalmente `racha_app` e aparecia assim
na gaveta do celular — agora é `Racha App`.

**Falta o passo do Firebase:** o `google-services.json` e o
`lib/firebase_options.dart` ainda apontam para o pacote antigo, e o plugin do
Google Services falha o build quando o pacote não bate. Rodar
`flutterfire configure --project racha-app-ghad-108ab` para registrar o app
Android novo e regerar os dois arquivos.

### [ ] T19 — Chave de assinatura de upload

O release ainda é assinado com a chave de debug. A Play exige chave própria —
e perder essa chave depois significa perder a capacidade de atualizar o app.

**Lado do Gradle já feito (24/08/2026).** O `build.gradle.kts` lê
`android/key.properties` e monta um `signingConfigs` de release a partir dele.
Tudo é condicional ao arquivo existir: sem ele o build **não quebra**, cai na
assinatura de debug e emite um aviso no log dizendo que a Play vai recusar o
upload. Isso é o que permite `flutter run --release` numa máquina que não tem
a chave — e evita que alguém descubra o problema só no Play Console.

O `.gitignore` da raiz ganhou `*.jks` e `*.keystore` (o `key.properties` já
estava coberto por `android/.gitignore`).

**Falta o que só pode ser feito à mão**, porque envolve a senha do keystore —
passá-la como argumento de linha de comando a deixaria no histórico do shell:

1. `keytool -genkeypair -v -keystore "$env:USERPROFILE\upload-keystore.jks"
   -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 -alias upload`
   (fora do repositório; `-validity 10000` porque a Play exige validade até
   pelo menos outubro de 2033)
2. Criar `android/key.properties` com `storePassword`, `keyPassword`,
   `keyAlias=upload` e `storeFile` — **com barras normais** no caminho, mesmo
   no Windows; barra invertida quebra o parser do Gradle.

Depois disso, `flutter build appbundle --release` já sai assinado sozinho — o
Gradle lê a senha do arquivo, ela não precisa passar por mais ninguém.

Para conferir com qual chave um artefato saiu:
`apksigner verify --print-certs <arquivo>`. Hoje devolve `CN=Android Debug`;
com a chave criada, passa a devolver os seus dados.

### [ ] T20 — Mover o cálculo de ranking para o servidor

A regra de `rankings` valida o formato, mas não quem escreve: **qualquer
usuário logado pode sobrescrever o ranking de qualquer outro.** Num trabalho
de faculdade é uma limitação documentada; num app público é uma
vulnerabilidade — dá para inflar o próprio ranking com uma requisição. A
correção é Cloud Functions, que também resolveria o push de verdade (hoje só
o token é registrado) e o mesmo problema em `avisos`.

### [ ] T21 — Exclusão de conta dentro do app

Exigência do Google desde 2023 para qualquer app com login: precisa existir
um caminho dentro do app **e** uma URL pública para pedir a exclusão. Hoje
não existe nenhum dos dois.

### [ ] T22 — Política de privacidade e formulário de segurança de dados

O app coleta email, foto, localização e usa câmera. Sem a política publicada
e o formulário preenchido, a Play não aceita a submissão.

Deixar para a reta final de propósito: o formulário descreve exatamente quais
dados o app coleta, e T16/T17 ainda vão mudar isso. Preencher agora é
preencher duas vezes.

### [ ] T23 — Foto de perfil no Storage, não em base64 no Firestore

`StorageService` codifica a imagem em base64 e grava no próprio doc do User.
Uma JPEG de 1024px a 80% dá 200–400 KB e o base64 infla isso em 33%, perto
demais do **limite de 1 MB por documento** — e esse doc é lido em toda lista
de participantes, time e ranking. O `firebase_storage` já está no
`pubspec.yaml` sem uso, esperando este item, e o `StorageService` já foi
escrito isolado para que trocar a implementação não mexa em quem chama.

Custo deste item cresce com o número de usuários reais: hoje é editar um
arquivo, depois da publicação vira script de migração. Depende do plano Blaze.

### [ ] T24 — Denúncia e bloqueio de conteúdo de usuário

Fotos de perfil, nomes de grupo e os `avisos` (mensagem livre que qualquer
logado grava no doc de outro, sem autor confiável — ver `firestore.rules`)
são conteúdo gerado por usuário. A política da Play exige denúncia dentro do
app, bloqueio de usuário e moderação. O canal de `avisos` do jeito que está é
um vetor de spam pronto.

### [ ] T25 — Divulgação prévia da permissão de localização

`LocationService` chama `Geolocator.requestPermission()` direto. A Play exige
uma tela do app **antes** do diálogo do sistema, explicando por que precisa da
localização e o que é feito com ela. Vale avaliar junto trocar
`ACCESS_FINE_LOCATION` por só `ACCESS_COARSE_LOCATION`: "Rachas Próximos"
trabalha em escala de quilômetros e a permissão grossa reduz o atrito na
revisão.

### [ ] T26 — Ícone do app

Os `ic_launcher.png` ainda são o ícone padrão do Flutter. Além de a Play pedir
um ícone de 512×512 para a ficha da loja, pacote de template + ícone padrão é
a combinação que faz o revisor marcar o app como "funcionalidade mínima".

### [ ] T27 — Crashlytics, R8 e App Check

Três itens de reta final, agrupados porque todos dependem do app Android já
registrado no Firebase com o pacote novo (T18):
- **Crashlytics** — publicar sem relatório de crash é publicar às cegas.
- **R8** — `buildTypes.release` não tem `isMinifyEnabled`/`isShrinkResources`.
- **App Check** — sem ele, a API key do `google-services.json` (que é pública
  por natureza) permite bater direto no Firestore/Auth fora do app. Deixar
  para o fim porque atrapalha o desenvolvimento: exige token de debug em cada
  máquina.

---

## Bloco 6 — Fotos e balanceamento por mais de um critério

Levantado em 05/10/2026, a partir de testes com o app no celular.

### [x] T28 — Fotos de perfil não apareciam nas telas do racha

Só as telas de perfil desenhavam a foto. Participantes, times, chamada,
estatísticas, ranking, membros fixos, solicitações e avaliação mostravam um
ícone genérico — **mesmo com a foto já carregada**: essas telas buscam o
documento do usuário (`userPorIdProvider`) para pegar o nome, e a foto vem
junto. Ela só não era desenhada.

Criado o `AvatarJogador` (`lib/core/widgets/avatar_jogador.dart`), usado em
todas essas telas. Sem foto, mostra as iniciais em vez do ícone, para dar
para distinguir as pessoas numa lista. Convidado aparece com outro tom.

A decodificação do base64 passou a ter cache (`imagem_base64.dart`): sem ele,
cada redesenho de tela decodificava todas as fotos de novo, e como cada
decodificação gera bytes novos, o Flutter tratava como imagem diferente e a
foto piscava.

**Achado junto:** a foto de perfil não funcionava no navegador. A cadeia
inteira (seletor → telas → controllers → `StorageService`) passava um
`File` de `dart:io`, que não existe na web — tirar a foto funcionava, ler o
arquivo quebrava. Trocado por `Uint8List` de ponta a ponta. Nenhum arquivo do
app importa mais `dart:io`.

### [x] T29 — Foto do racha

O admin pode pôr uma foto do grupo (o campo, a quadra, a turma), por câmera
ou galeria — diferente do perfil, que é só câmera por ser o requisito de
hardware da disciplina. Aparece como capa na tela do grupo, miniatura nos
cards da tela inicial e grande na aba Rachas Próximos, onde quem decide se
pede para entrar quer ver o campo antes.

Mesma estratégia provisória da foto de perfil: base64 no próprio documento
(`GrupoModel.fotoBase64`), porque o Storage exige o plano pago. Comprimida
bem mais (800 px / 70%) e com teto de 350 KB, já que o documento do grupo é
lido em toda lista — cada KB a mais pesa N vezes. Não exigiu mudança nas
regras: o admin já podia gravar qualquer campo do grupo.

**Achado junto:** o cabeçalho da tela do grupo era fixo, e as abas ficavam
só com a altura que sobrava. Com vários membros fixos e solicitações, o
cabeçalho passava da altura da tela e as abas sumiam com overflow. Agora ele
rola junto e sai de cena, com as abas presas no topo (`NestedScrollView`, via
o parâmetro `cabecalho` do `RachaTabsSection`).

### [x] T30 — Balanceamento passou a considerar idade e gols

O `docs/estrutura.md` pedia nota como critério principal e "talvez
idade/peso como critério secundário", e dizia que as estatísticas alimentam
"os próximos algoritmos de balanceamento". O código usava só a nota: a idade
chegava ao algoritmo e **nunca era lida**, o peso servia só de desempate na
ordenação, e os gols nem chegavam.

O ajuste final (trocar jogadores de mesma posição entre os times) passou a
minimizar uma soma ponderada das diferenças de quatro médias:

| Critério | Peso | Escala |
| --- | --- | --- |
| Nota | 1,0 | 1 ponto |
| Gols por rodada | 0,6 | 1 gol |
| Idade | 0,4 | 10 anos |
| Peso corporal | 0,15 | 15 kg |

Cada diferença é dividida pela escala antes de entrar na conta, senão o
critério medido no maior número (kg) dominaria só por isso. **Os pesos estão
em `balanceamento_constants.dart`** — mexer neles muda a prioridade, e zerar
um desliga o critério.

Quem não tem histórico de gols (convidado, jogador novo) entra com a média do
grupo, não com zero: zero o trataria como quem nunca marca, e o algoritmo
empurraria todos os novos contra o artilheiro.

Gols por rodada usa `totalRachas` como divisor, que hoje conta rodadas
**avaliadas** e não jogadas (T7) — é uma aproximação.

Testes novos provam que idade e gols de fato contam: com os dois pesos
zerados, exatamente os dois testes correspondentes quebram.

### [ ] T31 — Avaliação de convidado não entra no ranking

Não é bug, mas confunde. Notas dadas a convidados são descartadas do ranking
por definição (o id de um convidado não sobrevive entre rodadas). Num racha
com poucos jogadores cadastrados e o resto convidado, quase todas as
avaliações de companheiro de time vão para convidados — e o ranking parece
mostrar só as notas que vieram do time adversário.

Caminhos possíveis: avisar na tela de avaliação que a nota de convidado não
conta para o ranking, ou incentivar a oficialização do convidado (que já
reatribui as notas dele para a conta nova).

### [ ] T32 — Mínimo de jogadores para gerar times

`RachaModel.totalVagas` é `qtdJogadoresLinha + 1` — o tamanho de **um** time.
O `TimesController` usa esse número como mínimo total para gerar os times,
então um futsal 5×5 libera a geração com só 5 confirmados. Decidir se isso é
intencional (deixar jogar desfalcado) e, se for, renomear para não parecer
bug.

### [x] T33 — Conferência das estatísticas antes de valerem

Cada jogador lançava os próprios gols e assistências, e eles iam direto para
o ranking e para o balanceamento, sem ninguém checar. Agora funciona como a
chamada:

- o jogador lança os próprios números → ficam **aguardando conferência**;
- o admin ou um anotador (a mesma prancheta da chamada) confirma, linha a
  linha ou com "Confirmar todas"; o que eles mesmos lançam já nasce
  conferido;
- o anotador não confere os próprios números;
- editar depois de conferido volta para pendente;
- só estatística conferida entra no ranking (`agregarRanking`);
- o racha só finaliza com tudo conferido; depois disso, só o admin edita.

A regra do Firestore (`estatisticas`) garante o mesmo do lado do servidor —
sem ela, bastava chamar a API direto com `confirmada: true`. Documentos de
antes desta mudança (sem o campo) contam como conferidos, para não apagar o
histórico de rodadas que já foram finalizadas.

**Precisa publicar as regras** (`firebase deploy --only firestore:rules`).

---

## Fora do escopo por enquanto

- **Push notification de verdade** (FCM): o token do dispositivo é registrado
  e nada dispara notificação, porque não há Cloud Functions no projeto. Já
  está documentado como limitação conhecida; só vale mexer se o escopo do
  trabalho crescer.
- **Cálculo de ranking no servidor**: hoje é o cliente que recalcula e grava.
  A limitação está explicada no topo de `firestore.rules` e depende do mesmo
  backend que falta para o item acima.
