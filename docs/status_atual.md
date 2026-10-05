# Racha App — Status Atual do Sistema

> Gerado a partir do código-fonte em 22/08/2026. Este arquivo é um retrato do que **já está implementado e funcionando**, diferente de `docs/estrutura.md` (que é o plano original discutido antes de começar a codar).

---

## 1. Stack técnica

- **Flutter** (testado via Flutter Web/Chrome; roda também Android)
- **Riverpod** (`flutter_riverpod` 2.6.1) — gerenciamento de estado (Provider/AsyncNotifier)
- **go_router** 17.5.0 — navegação/rotas
- **Firebase**: Auth, Cloud Firestore, Storage, Cloud Messaging (`firebase_core`, `firebase_auth`, `cloud_firestore`, `firebase_storage`, `firebase_messaging`)
- **flutter_local_notifications** + **timezone**/**flutter_timezone** — lembretes locais de racha
- **image_picker**, **cached_network_image** — foto de perfil via câmera/galeria
- **geolocator** + **flutter_map**/**latlong2** (tiles do OpenStreetMap) — localização do grupo no mapa e busca de rachas por proximidade
- Projeto Firebase: `racha-app-ghad-108ab`

---

## 2. Modelo de dados (como está implementado)

### `UserModel` — `lib/models/user_model.dart`
`id`, `nome`, `email`, `fotoPerfilBase64`, `idade`, `peso`, `createdAt`, `fcmToken`
*(foto guardada como base64 no Firestore, não em arquivo separado no Storage)*

### `GrupoModel` (racha recorrente) — `lib/models/grupo_model.dart`
`id`, `nome`, `localPadrao`, `tipoCampoPadrao`, `qtdJogadoresLinhaPadrao`, `diaSemana`, `horario`, `adminId`, `membrosFixos` (lista de userId convidados automaticamente toda semana), `localizacao` (GeoPoint, nulo em grupos criados antes da feature de mapa), `abertoParaNovosMembros`

### `SolicitacaoModel` (pedido de entrada num grupo) — `lib/models/solicitacao_model.dart`
`id`, `grupoId`, `solicitanteId`, `status` (pendente/aprovado/recusado), `criadoEm` — subcoleção `grupos/{grupoId}/solicitacoes`. Diferente de `ConvidadoModel`: aqui é um User já cadastrado pedindo entrada num grupo aberto, e a aprovação o torna membro fixo do grupo.

### `RachaModel` (uma rodada, avulsa ou de um Grupo) — `lib/models/racha_model.dart`
`id`, `grupoId?`, `nome`, `local`, `dataHora`, `tipoCampo`, `qtdJogadoresLinha`, `adminId`, `status` (aberto/emAndamento/finalizado), `mvpUserId?`

### `ParticipanteModel` (User dentro de um Racha) — `lib/models/participante_model.dart`
`id`, `rachaId`, `userId`, `posicaoMain?`, `posicaoUsual?`, `time?` (A/B), `statusConfirmacao` (pendente/confirmado/recusado)

### `ConvidadoModel` (perfil temporário, sem login) — `lib/models/convidado_model.dart`
`id`, `rachaId`, `convidadoPor`, `nome`, `idadeAproximada`, `pesoAproximado`, `posicaoMain?`, `posicaoUsual?`, `statusAprovacao` (pendente/aprovado/recusado), `time?`, `oficializadoComoUserId?`

### `AvaliacaoModel` — `lib/models/avaliacao_model.dart`
`id`, `rachaId`, `avaliadorId`, `avaliadoId`, `avaliadoTipo` (user/convidado), `nota`

### `EstatisticaModel` — `lib/models/estatistica_model.dart`
`id`, `rachaId`, `jogadorId`, `jogadorTipo`, `gols`, `assistencias`, `cartoesAmarelos`, `cartoesVermelhos`

### `RankingModel` (calculado) — `lib/models/ranking_model.dart`
`userId`, `mediaAvaliacoes`, `totalMvps`, `totalGols`, `totalAssistencias`, `totalRachas`

### Enums — `lib/models/enums.dart`
- `TipoCampo`: campão (11), futsal (5), society (7 padrão, ajustável), minicampo (8 padrão, ajustável)
- `Posicao`: goleiro, zagueiro, lateral, volante, meia, atacante
- `RachaStatus`, `TimeRacha` (A/B), `StatusConfirmacao`, `StatusAprovacao`, `TipoJogador`, `DiaSemana`

---

## 3. Telas e rotas implementadas

| Rota | Tela | Arquivo |
|---|---|---|
| `/login` | Login | `screens/auth/login_screen.dart` |
| `/cadastro` | Cadastro (com foto via câmera) | `screens/auth/cadastro_screen.dart` |
| `/home` | Home — grupos, rachas avulsos, convites pendentes, sino de notificação | `screens/home/home_screen.dart` |
| `/perfil` | Perfil do jogador | `screens/perfil/perfil_screen.dart` |
| `/proximos` | Rachas próximos — grupos abertos ordenados por distância | `screens/descoberta/rachas_proximos_screen.dart` |
| `/perfil/editar` | Editar perfil | `screens/perfil/editar_perfil_screen.dart` |
| `/grupos/criar` | Criar racha recorrente (Grupo) | `screens/grupo/criar_grupo_screen.dart` |
| `/grupos/:id` | Detalhe do grupo (membros fixos, rodada atual) | `screens/grupo/grupo_detalhe_screen.dart` |
| `/grupos/:id/editar` | Editar grupo | `screens/grupo/editar_grupo_screen.dart` |
| `/grupos/:id/ranking` | Ranking do grupo | `screens/grupo/grupo_ranking_screen.dart` |
| `/grupos/:id/historico` | Histórico de rodadas finalizadas do grupo | `screens/grupo/historico_grupo_screen.dart` |
| `/rachas/criar` | Criar racha avulso | `screens/racha/criar_racha_screen.dart` |
| `/rachas/:id` | Detalhe do racha (abas: Participantes/Convidados/Times/Estatísticas/Próximo racha) | `screens/racha/racha_detalhe_screen.dart` + `racha_tabs_section.dart` |
| `/rachas/:id/editar` | Editar racha | `screens/racha/editar_racha_screen.dart` |
| `/rachas/:id/convidar` | Convidar jogador (buscar cadastrado ou criar convidado) | `screens/racha/convidar_jogador_screen.dart` |
| `/rachas/:id/avaliar` | Avaliação pós-jogo | `screens/racha/avaliacao_screen.dart` |

Redirect automático: usuário deslogado sempre cai em `/login`; logado é bloqueado de acessar `/login`/`/cadastro`.

---

## 4. Funcionalidades por fluxo

### Cadastro / Login
- Cadastro com nome, email, senha, idade, peso e foto de perfil (câmera ou galeria, salva em base64)
- Login/logout via Firebase Auth

### Criar racha
- **Avulso**: nome, local, data/hora, tipo de campo (formação sugerida automaticamente; society/minicampo permitem ajustar nº de jogadores de linha)
- **Recorrente (Grupo)**: mesmos campos + dia da semana fixo, horário e lista de membros fixos — gera rodadas automaticamente
- **Entrar com código**: o próprio id do documento do racha funciona como "código" compartilhável; qualquer um que souber o código entra e já se confirma
- Editar/remover racha e grupo (remoção só permitida pro racha avulso; grupo remove só o Grupo, rodadas já geradas continuam existindo)

### Participantes e convites
- Convidar jogador cadastrado por busca de nome ou email (índice `nomeBusca` prefix-search no Firestore)
- Convidar "sem cadastro" (Convidado): nome, idade aprox., peso aprox., posições — fica pendente até o admin aprovar
- Aba **Participantes** agrupa por status: Confirmados / Pendentes / Recusados
- Cada participante confirma ou recusa presença (botões check/cancel na própria linha); ao confirmar, agenda lembrete local 2h antes do racha
- Admin pode remover participante/convidado do racha
- **Oficialização de convidado**: admin vincula um Convidado a um User cadastrado (busca por email) — migra `Avaliacao`/`Estatistica` do convidado pro user oficial e recalcula ranking

### Descoberta de rachas e entrada em grupo
- Ao criar/editar um grupo, o admin marca a **localização no mapa** (`flutter_map` + OpenStreetMap, com botão "usar minha localização atual") e pode ligar o switch **"Aberto para novos jogadores"**. Grupo aberto sem localização é barrado no formulário — ele nunca apareceria na busca por proximidade
- Tela **Rachas Próximos** (`/proximos`, ícone na AppBar da Home): pega a posição atual do usuário (`geolocator`), lista os grupos abertos dentro do raio escolhido (5/10/25/50 km) ordenados por distância. O filtro é feito no cliente por haversine (`lib/core/utils/geo_utils.dart`) — sem geohash/geoquery, o volume de grupos do app não justifica
- Grupos em que o usuário já é dono ou membro fixo não aparecem na descoberta
- **Solicitar entrada**: cria uma `Solicitacao` pendente; o botão reflete o estado em tempo real ("Pedido pendente", "Pedido recusado · solicitar de novo")
- **Aprovação** (só o admin, na tela do grupo): aprovar torna o solicitante membro fixo e, se já existe rodada aberta, também o convida pra ela na hora
- **Membros x admin**: a tela de detalhe do grupo distingue os dois papéis — o admin vê editar/apagar, adicionar/remover membro fixo e a fila de solicitações; quem só participa vê a lista de membros, o ranking, o histórico e a ação **"Sair do grupo"**
- A Home tem duas seções de grupo: os que o usuário administra e **"Rachas que participo"** (onde ele é membro fixo)

### Geração de times
- Botão "Gerar times" só habilita quando o nº de elegíveis (confirmados + convidados aprovados) atinge **o dobro** da formação do tipo de campo — os dois times completos, não só um
- **Posição é obrigatória para confirmar presença**: ao confirmar, o jogador escolhe onde joga, num diálogo que mostra a formação daquele racha (tipo de campo + jogadores de linha). Pode editar depois; quem confirmou por código e ficou sem posição aparece marcado como "Sem posição" na lista
- Antes de gerar, o admin é avisado se ninguém escolheu goleiro ou se há confirmados sem posição
- Algoritmo (`lib/core/balanceamento/balanceador_times.dart` + `setores.dart`), nesta ordem de prioridade:
  1. **Goleiro** — no máximo 1 por time, o melhor avaliado primeiro; do terceiro em diante vira jogador de linha
  2. **Setor** — cada jogador entra pelo setor da posição **main** (defesa: zagueiro/lateral; meio: volante/meia; ataque: atacante), e os dois times ficam com a mesma quantidade em cada setor (diferença máxima de 1)
  3. **Nota** — os dois times terminam com **médias de avaliação próximas**. A distribuição inicial já espalha os melhores, e um ajuste final troca jogadores **do mesmo setor** entre os lados enquanto isso aproximar as médias. Como a troca é sempre dentro do mesmo setor (e goleiro só troca com goleiro), as duas garantias anteriores continuam de pé. Compara médias e não somas, porque os times podem ter um jogador de diferença
- **A posição secundária só entra quando um setor fica em falta.** O alvo por setor vem da formação (10 de linha = 4-4-2, 6 = 2-2-2, 4 = 2-1-1). Se o racha confirmou dez atacantes e nenhum meia, os atacantes que também jogam de meia descem — começando pelos de menor nota, para os melhores continuarem na posição em que são melhores. Quem não declarou posição nenhuma tapa buraco primeiro, antes de mexer em quem já está alocado. Se ninguém cobre o setor em falta, o racha entra desfalcado ali mesmo em vez de escalar alguém fora das duas posições dele
- **A nota usada é a média real de avaliação** do jogador (`rankings/{userId}.mediaAvaliacoes`), buscada na hora de gerar os times. Jogador sem histórico e Convidado entram com nota neutra (3,0)
- Tamanho dos times nunca difere em mais de 1 jogador

> **Revisão de decisão:** `docs/estrutura.md` registrou "vagas de linha livres, sem sub-cota por posição". Na prática isso deixava o racha entrar em campo sem meio-campo nenhum quando a lista vinha cheia de atacantes. A regra atual mantém o espírito (ninguém é obrigado a jogar fora das próprias posições) mas usa a formação como alvo, e só remaneja quem tem a segunda posição no setor que está faltando.

### Avaliação pós-jogo
- Tela `/rachas/:id/avaliar`: cada jogador avalia todos os companheiros do próprio time (1–5 estrelas) + escolhe 1 adversário pra avaliar
- Bloqueia reenvio ("Você já avaliou este racha")
- Ao enviar, recalcula o `RankingModel` de cada User avaliado (convidados não têm ranking)

### MVP e estatísticas
- Botão "Calcular MVP da rodada" (admin): `lib/core/avaliacao/mvp_calculator.dart` — elege quem tem maior média de nota; empate é resolvido por quem recebeu mais avaliações; **só User pode ser MVP** (Convidado nunca vence, mesmo com nota alta)
- Registro de gols/assistências/cartões amarelos/vermelhos por jogador (User ou Convidado) na aba Estatísticas

### Ranking
- Existem **dois recortes**, e eles não são a mesma coisa: `rankings/{userId}` é o acumulado **global** do jogador (todos os rachas dele, de qualquer grupo) — usado no Perfil e pelo balanceamento; `/grupos/:id/ranking` é o recorte **por grupo**, calculado sob demanda
- Os dois passam pela mesma função (`lib/core/ranking/agregador_ranking.dart`), então nenhum jogador aparece com número diferente dependendo da tela
- O ranking global é refeito **inteiro** a cada avaliação/estatística/MVP (`RankingController.recalcularRanking`), sempre a partir da fonte de verdade — é idempotente e se autocorrige, já que nada deriva do valor anterior
- `AvaliacaoModel` e `EstatisticaModel` guardam o `grupoId` da rodada, o que deixa o ranking do grupo em três consultas fixas em vez de crescer junto com o histórico
- Histórico de rodadas finalizadas por grupo (`/grupos/:id/historico`)

### Recorrência automática
- Ao finalizar um racha vinculado a um Grupo, o sistema cria automaticamente a próxima rodada (mesmo local/horário/tipo de campo) e já convida todos os membros fixos

### Notificações
- **Locais** (`flutter_local_notifications`): lembrete 2h antes do racha pra quem confirmou presença, cancelado se recusar
- **Push (FCM)**: registro de token do dispositivo implementado (client-side); não há backend/Cloud Functions disparando push de fato ainda — é só a base pronta

---

## 5. Segurança (Firestore Security Rules)

Arquivo `firestore.rules` (fora do git agora, só local — ver `.gitignore`). Pontos-chave:
- Toda leitura exige usuário autenticado (`isSignedIn()`)
- Escrita de racha/grupo só pelo `adminId`; campos como `adminId`/`grupoId` são imutáveis após criação
- Participante pode se autoconfirmar (entrar por código) mas não pode mexer no próprio `time` (só o admin, via algoritmo)
- Convidado só é aprovado/recusado/removido pelo admin do racha
- Reatribuição de avaliação (oficialização) só altera `avaliadoId`/`avaliadoTipo`, nunca a nota
- `grupos`: além do admin, o próprio jogador pode se remover de `membrosFixos` ("Sair do grupo") — a regra exige que a escrita toque só esse campo, remova exatamente um item e que o item removido seja o uid de quem escreveu, então ninguém expulsa ninguém por essa porta
- `grupos/{id}/solicitacoes`: só o próprio solicitante cria (pra si mesmo, sempre pendente); só o admin do grupo aprova/recusa, sem poder trocar quem pediu nem o grupo
- Regras extras com `{path=**}` pra permitir queries `collectionGroup` em `participantes`, `avaliacoes` e `estatisticas` (necessário pro sino de convites e pro recálculo de ranking entre rachas)
- Índices `collectionGroup` publicados para `participantes.userId`, `avaliacoes.avaliadoId`, `estatisticas.jogadorId`

---

## 6. Testes automatizados

`flutter test` — **34/34 passando**:
- `test/core/balanceamento/balanceador_times_test.dart` (5 testes): distribuição de goleiro, nenhum jogador perdido/duplicado, tamanho dos times, balanceamento por nota
- `test/core/avaliacao/mvp_calculator_test.dart` (3 testes): maior média vence, empate por nº de avaliações, convidado nunca é MVP
- `test/core/ranking/agregador_ranking_test.dart` (6 testes): média, soma de gols/assistências, contagem de MVPs, convidado fora do ranking, ordenação
- `test/core/balanceamento/setores_test.dart`: distribuição ideal por formação, reforço pelo setor em falta, prioridade do jogador sem posição, e o caso em que ninguém cobre o setor
- `test/core/utils/geo_utils_test.dart`: distância haversine entre pontos conhecidos
- `test/widget_test.dart` (1 teste): `AppTheme.light` monta um `ThemeData` válido

---

## 7. O que ainda não existe

- Push notification de verdade disparado por servidor (só o registro de token está pronto, sem Cloud Functions)
- Foto de perfil em Storage separado (hoje é base64 direto no Firestore)
- Cálculo de ranking/estatística no servidor (hoje todo cálculo é feito no cliente que disparou a ação — ver limitação documentada no topo de `firestore.rules`)
