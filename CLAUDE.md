# Racha App — contexto para o Claude Code

Este arquivo é lido automaticamente pelo Claude Code ao abrir o projeto. Ele
resume meses de conversa entre o Gustavo (dono do repositório) e o Claude:
o que o app é, como o código está organizado, o que já foi decidido e o que
falta. **Leia inteiro antes de mexer em qualquer coisa.**

O registro completo, item por item, está em `docs/tarefas.md` (T1–T33). Este
arquivo é o mapa; aquele é o diário.

---

## 1. O que é o projeto

App Flutter para organizar **rachas** (peladas de futebol): cadastro de
jogadores, grupos recorrentes, convites, confirmação de presença, chamada do
dia, geração automática de times balanceados, avaliação pós-jogo, MVP,
estatísticas e ranking.

É **trabalho de faculdade** de um grupo, e o Gustavo passou o projeto para os
outros integrantes em outubro de 2026. Existe também a intenção de publicar
na Play Store um dia (ver Bloco 5 em `docs/tarefas.md`).

### Como o professor avalia — importante

O grupo abre o código na frente do professor, que **sorteia um integrante**
e pergunta o que uma parte do código faz. Consequências práticas:

- Código que ninguém do grupo sabe explicar pesa **contra** o grupo. Prefira
  soluções simples e comente o **porquê** de cada decisão não óbvia.
- Quando pedirem **material de apresentação** (arquivo para mostrar em aula),
  o critério é o que o professor **já ensinou até aquele momento**, não
  fidelidade ao app real. Na primeira entrega ele só tinha ensinado front-end
  (widgets, layout) e navegação com `Navigator.push`/`pop` — por isso
  `lib/apresentacao_auth.dart` é Flutter puro, sem Firebase nem Riverpod.
  **Pergunte o que já foi ensinado antes de gerar material assim.**
- Material de estudo: `docs/racha-app-codigo-explicado.html` / `.pdf`
  explica o app inteiro, arquivo por arquivo.

---

## 2. Stack e comandos

- **Flutter 3.47.0 stable / Dart 3.13.0**
- **Riverpod 2.6** (`AsyncNotifier`, `StreamProvider.family`, `FutureProvider.family`)
- **go_router 17** (rotas em `lib/core/router/app_router.dart`)
- **Firebase**: Auth (e-mail/senha), Cloud Firestore. Projeto
  **`racha-app-ghad-108ab`**. `firebase_storage` e `firebase_messaging` estão
  no pubspec mas o Storage não é usado (ver T23) e o push não dispara (sem
  Cloud Functions).
- `geolocator` + `flutter_map` (OpenStreetMap) + `http` (busca de endereço),
  `image_picker`, `flutter_local_notifications`.

```bash
flutter pub get
flutter run -d chrome            # jeito mais rápido de ver rodando
flutter analyze                  # tem que ficar "No issues found!"
flutter test                     # 62 testes, todos de lógica pura
flutter build apk --release      # build/app/outputs/flutter-apk/app-release.apk
firebase deploy --only firestore:rules            # .firebaserc já aponta o projeto
firebase deploy --only firestore:indexes
```

O projeto **não tem suporte a Windows desktop** configurado — rodar sem `-d
chrome` num PC sem celular conectado dá "No Windows desktop project
configured". Use Chrome ou um Android.

---

## 3. Arquitetura

```
lib/
  core/          lógica pura e coisas compartilhadas (sem Firebase)
    balanceamento/  algoritmo de times (balanceador_times.dart, setores.dart)
    ranking/        agregador_ranking.dart — a ÚNICA conta de ranking
    avaliacao/      mvp_calculator.dart
    constants/      pesos do balanceamento, caminhos do Firestore
    router/ theme/ utils/ widgets/
  models/        entidades + fromMap/toMap
  services/      mundo externo: Auth, GPS, geocoding, notificação, foto
  repositories/  leitura/escrita no Firestore (uma classe por coleção)
  providers/     Riverpod: providers de dados + controllers (ações)
  screens/       telas, por área (auth, home, grupo, racha, perfil, descoberta)
  widgets/       widgets maiores reaproveitados (seletores de foto)
test/            só lógica pura (core/ e models/)
```

**Regra de ouro:** só `services/` e `repositories/` leem e gravam no
Firebase. Modelos, `core/` e telas no máximo usam tipos dele (`Timestamp`,
`GeoPoint`) — é isso que permite testar o balanceamento, o ranking e o MVP
sem emulador.

Fluxo típico de uma ação: **tela → controller (providers/) → repository →
Firestore**. A tela lê dados com `ref.watch(algumProvider)` e dispara ações
com `ref.read(algumController.notifier).metodo(...)`.

### Convenções que já existem — siga

- **Nomes em português** (classes, métodos, variáveis, comentários).
- **Comentários explicam o porquê**, não o quê. Comentário de decisão
  costuma citar a tarefa (`ver T7 em docs/tarefas.md`).
- **Todo provider de dados do Firestore observa `uidLogadoProvider`**. Sem
  isso, trocar de conta mantinha os dados da conta anterior em cache. Ao
  criar provider novo, copie o padrão de `lib/providers/firebase_providers.dart`.
- **Fotos são base64 dentro do documento** (perfil em `users`, foto do racha
  em `grupos`), porque o projeto está no plano gratuito (Spark), sem Storage.
  Decodifique com `bytesDaFoto()` (`core/utils/imagem_base64.dart`), que tem
  cache — decodificar a cada build fazia a imagem piscar.
- **Nada de `dart:io` / `File`** no app: quebra no navegador. Use
  `XFile.readAsBytes()` e `Uint8List`.
- **Ranking**: qualquer mudança passa por `agregarRanking()` em
  `core/ranking/agregador_ranking.dart`, usada tanto pelo ranking global
  (`rankings/{userId}`) quanto pelo do grupo. Não duplique a conta.
- **Regras do Firestore andam junto com o código.** Se mudou um campo que
  `firestore.rules` valida, publique as regras na mesma hora — já aconteceu
  de código e regra saírem de sincronia e as escritas quebrarem.
- Ao terminar uma mudança: `flutter analyze` limpo, `flutter test` passando,
  e registrar em `docs/tarefas.md` (próximo número: **T34**).

---

## 4. Modelo de dados (Firestore)

| Coleção | O que é |
|---|---|
| `users/{uid}` | jogador: nome, email, idade, peso, `fotoPerfilBase64`, `nomeBusca` |
| `users/{uid}/avisos` | recados internos (sino da Home) |
| `grupos/{id}` | racha recorrente: dia/horário, local + `localizacao`, `membrosFixos`, `auxiliares` (anotadores), `abertoParaNovosMembros`, `fotoBase64` |
| `grupos/{id}/solicitacoes` | pedidos de entrada vindos de "Rachas Próximos" |
| `rachas/{id}` | uma rodada (avulsa ou de grupo): status, `anotadores`, `mvpUserId` |
| `rachas/{id}/participantes` | user no racha: confirmação, posições, `time`, `presenca` |
| `rachas/{id}/convidados` | perfil temporário sem login, aprovado pelo admin |
| `rachas/{id}/avaliacoes` | notas 1–5 pós-jogo |
| `rachas/{id}/estatisticas/{jogadorId}` | gols, assistências, cartões, `confirmada`, `conferidaPor` |
| `rankings/{uid}` | acumulado global, recalculado do zero pelo cliente |

`avaliacoes` e `estatisticas` guardam `grupoId` copiado da rodada, para o
ranking do grupo sair numa consulta só.

---

## 5. Regras de negócio decididas (não desfazer sem conversar)

- **Balanceamento** (`core/balanceamento/`), em ordem: (1) no máximo um
  goleiro por time; (2) mesma quantidade por setor (defesa/meio/ataque) a
  partir da posição **main** — a secundária só cobre setor em falta; (3)
  ajuste final troca jogadores **do mesmo setor** até os times ficarem
  parecidos em **nota (peso 1,0), gols por rodada (0,6), idade (0,4) e peso
  corporal (0,15)**. Os pesos ficam em `core/constants/balanceamento_constants.dart`;
  zero desliga o critério. Jogador sem histórico entra com nota 3,0 e gols =
  média do grupo.
- **Posição é obrigatória para confirmar presença.**
- **O admin não nasce confirmado** — quem organiza nem sempre joga.
- **Chamada** (compareceu/atrasou/faltou): feita pelo admin ou por
  **anotadores** (ícone de prancheta ao lado do membro fixo). O jogador nunca
  marca a própria presença. O anotador só mexe em presença e conferência.
- **Estatísticas passam por conferência** (T33): o jogador lança as próprias
  e elas ficam pendentes; admin/anotador confirma; o anotador não confere as
  próprias; editar depois volta a pendente; só conferida entra no ranking; o
  racha só finaliza com tudo conferido. Documentos antigos sem o campo contam
  como conferidos.
- **Convidados não entram no ranking** (o id deles não sobrevive entre
  rodadas). Notas dadas a convidados somem do ranking — isso confundiu nos
  testes (T31).
- **MVP**: maior média; empate → mais avaliações; convidado nunca é MVP.
- **Finalizar rodada de grupo cria a próxima** automaticamente e convida os
  membros fixos, num batch só.
- **Recusa de pedido de entrada só o admin reabre**, sem prazo automático.
- **Presença é eixo separado de habilidade** (T16, ainda não feito): ser
  assíduo nunca pode fazer o algoritmo achar que a pessoa joga melhor.
  Recusar com antecedência é neutro, não negativo.

---

## 6. Estado atual (05/10/2026)

**Funcionando:** tudo dos Blocos 1–4 exceto T7/T16/T17, mais o Bloco 6
(fotos em todas as telas, foto do racha, balanceamento multicritério,
conferência de estatísticas). Tema escuro verde (estilo Spotify) em
`core/theme/app_theme.dart`. Release **v1.0.0** publicada no GitHub com APK.

**Pendente** (detalhes em `docs/tarefas.md`):
- **T16** pontuação de presença — pergunta aberta: a janela de 10 rodadas
  conta rodadas do grupo ou rodadas em que a pessoa foi convidada? Sugestão
  registrada: as convidadas, com mínimo de ~3 rodadas antes de valer.
- **T17** banco ordenado (hoje nada limita o elenco: 18 confirmados num 7×7
  viram dois times de 9).
- **T7** `totalRachas` conta rodadas avaliadas, não jogadas (vai junto da
  T16, renomeando o campo — mexe em `firestore.rules`).
- **T31** avisar que nota de convidado não conta no ranking.
- **T32** decidir se o mínimo para gerar times é um time ou dois
  (`RachaModel.totalVagas` = tamanho de **um** time).
- **T12** `docs/status_atual.md` e `docs/pendencias.md` estão
  **desatualizados** (agosto). Confie em `docs/tarefas.md` e neste arquivo.
- **Play Store** (Bloco 5): T19 chave de upload (o Gradle já está pronto,
  falta criar o keystore — `android/key.properties` não existe), T20 ranking
  no servidor, T21 exclusão de conta, T22 política de privacidade, T23–T27.
  O `applicationId` já é `com.gustavodias.rachaapp` (T18 feito).

---

## 7. Segurança — nunca fazer

- **Nunca commitar** `android/key.properties`, `*.jks`, `*.keystore` (já no
  `.gitignore`). Senha de keystore nunca deve passar por comando do Claude.
- Não ler nem usar as credenciais OAuth guardadas pelo Firebase CLI.
- `firebase_options.dart` e `google-services.json` **são** versionados de
  propósito — são chaves públicas; a segurança está em `firestore.rules`.
- Ações destrutivas no Firebase (apagar app, dados, mudar plano) são feitas
  pelo dono no console, não pelo Claude.
- Limitação conhecida: sem Cloud Functions, o ranking é gravado pelo
  cliente e a regra só valida o formato (T20). Não "resolva" isso fingindo
  com regra; está documentado no topo de `firestore.rules`.

---

## 8. Como o Gustavo gostava de trabalhar

- Respostas **em português**, diretas, explicando o motivo das decisões.
- **Commit e push só quando pedirem.** Release no GitHub com `gh release`.
- Testa no **celular pelo APK** e manda prints. Depois de mudar código,
  gerar o APK de novo e dizer o caminho.
- Prefere que o Claude implemente e verifique (analyze + test + build) e
  depois explique o que mudou, em vez de só sugerir.
- Quando um bug relatado na verdade não é bug (ex.: ranking parecendo só
  ter notas do adversário porque os companheiros eram convidados), explicar
  a causa com os dados da tela dele em vez de mudar código à toa.

---

## 9. Armadilhas conhecidas

- O Chrome sem aceleração de vídeo não desenha o Flutter Web — o Claude não
  consegue "ver" as telas; quem testa é o grupo.
- No Windows, heredoc com acentos no Bash do Claude Code costuma quebrar;
  para edições grandes, use a ferramenta de edição de arquivo.
- Dados do Firestore foram tratados como descartáveis até aqui (campos novos
  não foram migrados em documentos antigos). Com usuários reais, mudança de
  modelo passa a exigir script de migração ou fallback no `fromMap`.
- Consultas compostas precisam dos índices de `firestore.indexes.json`
  publicados, senão falham com erro pedindo o índice.
