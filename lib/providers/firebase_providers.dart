import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../core/ranking/agregador_ranking.dart';
import '../core/utils/posicao_utils.dart';
import '../models/avaliacao_model.dart';
import '../models/aviso_model.dart';
import '../models/alvo_avaliacao.dart';
import '../models/convidado_model.dart';
import '../models/enums.dart';
import '../models/estatistica_model.dart';
import '../models/grupo_model.dart';
import '../models/participante_model.dart';
import '../models/racha_model.dart';
import '../models/ranking_model.dart';
import '../models/solicitacao_model.dart';
import '../models/user_model.dart';
import '../repositories/avaliacao_repository.dart';
import '../repositories/aviso_repository.dart';
import '../repositories/convidado_repository.dart';
import '../repositories/estatistica_repository.dart';
import '../repositories/grupo_repository.dart';
import '../repositories/participante_repository.dart';
import '../repositories/racha_repository.dart';
import '../repositories/ranking_repository.dart';
import '../repositories/solicitacao_repository.dart';
import '../repositories/user_repository.dart';
import '../services/auth_service.dart';
import '../services/local_notification_service.dart';
import '../services/geocoding_service.dart';
import '../services/location_service.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';

/// Instâncias cruas dos SDKs do Firebase. Ficam isoladas aqui pra tudo mais
/// depender só de abstrações (services/repositories), nunca do SDK direto.
final firebaseAuthProvider = Provider<FirebaseAuth>((ref) => FirebaseAuth.instance);

final firestoreProvider =
    Provider<FirebaseFirestore>((ref) => FirebaseFirestore.instance);

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(ref.watch(firebaseAuthProvider));
});

final storageServiceProvider = Provider<StorageService>((ref) => StorageService());

final locationServiceProvider = Provider<LocationService>((ref) => LocationService());

/// Busca de endereço/CEP para o seletor de localização. O `http.Client` é
/// criado uma vez e reaproveitado — abrir um por consulta desperdiça conexão.
final geocodingServiceProvider = Provider<GeocodingService>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return GeocodingService(client);
});

final firebaseMessagingProvider =
    Provider<FirebaseMessaging>((ref) => FirebaseMessaging.instance);

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService(ref.watch(firebaseMessagingProvider));
});

final localNotificationServiceProvider = Provider<LocalNotificationService>((ref) {
  return LocalNotificationService(FlutterLocalNotificationsPlugin());
});

final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepository(ref.watch(firestoreProvider));
});

final rachaRepositoryProvider = Provider<RachaRepository>((ref) {
  return RachaRepository(ref.watch(firestoreProvider));
});

final grupoRepositoryProvider = Provider<GrupoRepository>((ref) {
  return GrupoRepository(ref.watch(firestoreProvider));
});

final participanteRepositoryProvider = Provider<ParticipanteRepository>((ref) {
  return ParticipanteRepository(ref.watch(firestoreProvider));
});

final convidadoRepositoryProvider = Provider<ConvidadoRepository>((ref) {
  return ConvidadoRepository(ref.watch(firestoreProvider));
});

final avaliacaoRepositoryProvider = Provider<AvaliacaoRepository>((ref) {
  return AvaliacaoRepository(ref.watch(firestoreProvider));
});

final rankingRepositoryProvider = Provider<RankingRepository>((ref) {
  return RankingRepository(ref.watch(firestoreProvider));
});

final estatisticaRepositoryProvider = Provider<EstatisticaRepository>((ref) {
  return EstatisticaRepository(ref.watch(firestoreProvider));
});

final solicitacaoRepositoryProvider = Provider<SolicitacaoRepository>((ref) {
  return SolicitacaoRepository(ref.watch(firestoreProvider));
});

final avisoRepositoryProvider = Provider<AvisoRepository>((ref) {
  return AvisoRepository(ref.watch(firestoreProvider));
});

/// Recados pendentes do usuário logado (ver `AvisoModel`) — aparecem no sino
/// da Home junto com os convites.
final meusAvisosProvider = StreamProvider<List<AvisoModel>>((ref) {
  final uid = ref.watch(authStateChangesProvider).value?.uid;
  if (uid == null) return Stream.value(const []);
  return ref.watch(avisoRepositoryProvider).observar(uid);
});

/// Rachas (grupos recorrentes) que o usuário logado administra, para a
/// lista da Home.
final meusGruposProvider = StreamProvider<List<GrupoModel>>((ref) {
  final uid = ref.watch(authStateChangesProvider).value?.uid;
  if (uid == null) return Stream.value(const []);
  return ref.watch(grupoRepositoryProvider).observarPorAdmin(uid);
});

/// Grupos em que o usuário logado é membro fixo sem ser o dono — entrou por
/// solicitação aprovada na aba "Rachas Próximos" ou foi adicionado pelo
/// admin. Ficam numa seção separada da Home porque as ações disponíveis são
/// outras (não dá pra editar/apagar, só acompanhar a rodada e sair).
final gruposQueParticipoProvider = StreamProvider<List<GrupoModel>>((ref) {
  final uid = ref.watch(authStateChangesProvider).value?.uid;
  if (uid == null) return Stream.value(const []);
  return ref
      .watch(grupoRepositoryProvider)
      .observarPorMembro(uid)
      .map((lista) => lista.where((g) => g.adminId != uid).toList());
});

/// Rachas avulsos (sem Grupo) que o usuário logado administra — os
/// vinculados a um Grupo já aparecem em `meusGruposProvider`, então ficam
/// de fora daqui pra não duplicar na Home.
final meusRachasAvulsosProvider = StreamProvider<List<RachaModel>>((ref) {
  final uid = ref.watch(authStateChangesProvider).value?.uid;
  if (uid == null) return Stream.value(const []);
  return ref
      .watch(rachaRepositoryProvider)
      .observarPorAdmin(uid)
      .map((lista) => lista.where((r) => r.grupoId == null).toList());
});

/// Rodada aberta atual de um Grupo — a tela de detalhe do grupo mostra
/// participantes/convidados dessa rodada, não do Grupo em si.
final rachaAtualDoGrupoProvider =
    StreamProvider.family<RachaModel?, String>((ref, grupoId) {
  if (ref.watch(uidLogadoProvider) == null) return Stream.value(null);
  return ref.watch(rachaRepositoryProvider).observarAtualPorGrupo(grupoId);
});

/// Grupos abertos pra novos membros — base da aba "Rachas Próximos"
/// (`GrupoRepository.observarAbertos`); a tela filtra/ordena por distância
/// no cliente a partir daqui.
final rachasAbertosProvider = StreamProvider<List<GrupoModel>>((ref) {
  if (ref.watch(uidLogadoProvider) == null) return Stream.value(const []);
  return ref.watch(grupoRepositoryProvider).observarAbertos();
});

/// Pedidos de entrada pendentes de um grupo — seção de aprovação na tela de
/// detalhe do grupo, visível só pro admin.
final solicitacoesPendentesProvider =
    StreamProvider.family<List<SolicitacaoModel>, String>((ref, grupoId) {
  if (ref.watch(uidLogadoProvider) == null) return Stream.value(const []);
  return ref.watch(solicitacaoRepositoryProvider).observarPendentes(grupoId);
});

/// Pedidos recusados de um grupo — o admin precisa vê-los pra poder
/// reabrir, já que quem foi recusado não consegue pedir de novo sozinho.
final solicitacoesRecusadasProvider =
    StreamProvider.family<List<SolicitacaoModel>, String>((ref, grupoId) {
  if (ref.watch(uidLogadoProvider) == null) return Stream.value(const []);
  return ref.watch(solicitacaoRepositoryProvider).observarRecusadas(grupoId);
});

/// Último pedido de entrada do usuário logado num grupo, se houver — a aba
/// "Rachas Próximos" usa pra trocar "Solicitar entrada" por "Pedido
/// pendente"/"Pedido recusado". É stream (não one-shot) pra o botão mudar
/// no mesmo instante em que o pedido é criado e de novo quando o admin
/// responde, sem depender de sair e voltar na tela.
final minhaSolicitacaoProvider =
    StreamProvider.family<SolicitacaoModel?, String>((ref, grupoId) {
  final uid = ref.watch(authStateChangesProvider).value?.uid;
  if (uid == null) return Stream.value(null);
  return ref
      .watch(solicitacaoRepositoryProvider)
      .observarMinhaSolicitacao(grupoId, uid);
});

/// Grupo por id, em stream — usado pela seção "Membros fixos" da tela de
/// detalhe do grupo, que precisa refletir na hora quando o admin
/// adiciona/remove alguém (o `GrupoModel` recebido por `extra` na
/// navegação é só um snapshot do momento em que a lista foi aberta).
final grupoPorIdProvider = StreamProvider.family<GrupoModel?, String>((ref, grupoId) {
  if (ref.watch(uidLogadoProvider) == null) return Stream.value(null);
  return ref.watch(grupoRepositoryProvider).observar(grupoId);
});

final participantesDoRachaProvider =
    StreamProvider.family<List<ParticipanteModel>, String>((ref, rachaId) {
  if (ref.watch(uidLogadoProvider) == null) return Stream.value(const []);
  return ref.watch(participanteRepositoryProvider).observarPorRacha(rachaId);
});

final rachaPorIdProvider =
    StreamProvider.family<RachaModel?, String>((ref, rachaId) {
  if (ref.watch(uidLogadoProvider) == null) return Stream.value(null);
  return ref.watch(rachaRepositoryProvider).observar(rachaId);
});

/// Rachas em que o usuário logado é participante (convidado por outro
/// admin) — usado pela seção "Convites" da Home, separada de "Meus rachas"
/// (que são os grupos que ele próprio administra).
final meusConvitesProvider = StreamProvider<List<ParticipanteModel>>((ref) {
  final uid = ref.watch(authStateChangesProvider).value?.uid;
  if (uid == null) return Stream.value(const []);
  return ref.watch(participanteRepositoryProvider).observarMeusConvites(uid);
});

/// Uma rodada para a qual o jogador foi convidado, junto da participação
/// dele nela.
typedef RodadaConvidada = ({ParticipanteModel participacao, RachaModel racha});

/// Rodadas **futuras** em que o jogador foi convidado por outra pessoa.
///
/// A seção "Convites" da tela inicial mostrava toda participação já
/// registrada, sem filtro nenhum: rodadas de meses atrás continuavam ali
/// para sempre, e as já respondidas ficavam misturadas com as que ainda
/// esperavam resposta. Este provider resolve as três coisas que faltavam:
///
///  - descarta rodada que já passou ou foi finalizada;
///  - descarta rodada que o próprio jogador organiza (essa aparece em "Meus
///    rachas", e convidar a si mesmo não faz sentido);
///  - ordena da mais próxima para a mais distante, que é a ordem em que a
///    pessoa precisa decidir.
final proximasRodadasProvider =
    FutureProvider<List<RodadaConvidada>>((ref) async {
  final uid = ref.watch(uidLogadoProvider);
  if (uid == null) return const [];

  final participacoes = await ref.watch(meusConvitesProvider.future);
  if (participacoes.isEmpty) return const [];

  final repo = ref.watch(rachaRepositoryProvider);
  final rachas = await Future.wait(
    participacoes.map((p) => repo.buscarPorId(p.rachaId)),
  );

  // Uma hora de tolerância: a rodada que começou agora ainda interessa a
  // quem está a caminho, e sumir da lista no minuto do apito seria pior do
  // que deixar passar um pouco.
  final limite = DateTime.now().subtract(const Duration(hours: 1));

  final proximas = <RodadaConvidada>[];
  for (var i = 0; i < participacoes.length; i++) {
    final racha = rachas[i];
    if (racha == null) continue;
    if (racha.adminId == uid) continue;
    if (racha.status == RachaStatus.finalizado) continue;
    if (racha.dataHora.isBefore(limite)) continue;
    proximas.add((participacao: participacoes[i], racha: racha));
  }

  proximas.sort((a, b) => a.racha.dataHora.compareTo(b.racha.dataHora));
  return proximas;
});

final convidadosDoRachaProvider =
    StreamProvider.family<List<ConvidadoModel>, String>((ref, rachaId) {
  if (ref.watch(uidLogadoProvider) == null) return Stream.value(const []);
  return ref.watch(convidadoRepositoryProvider).observarPorRacha(rachaId);
});

final estatisticasDoRachaProvider =
    StreamProvider.family<List<EstatisticaModel>, String>((ref, rachaId) {
  if (ref.watch(uidLogadoProvider) == null) return Stream.value(const []);
  return ref.watch(estatisticaRepositoryProvider).observarPorRacha(rachaId);
});

/// Dados de um User a partir do id — usado pra mostrar o nome nas listas de
/// participante, que só guardam o `userId`.
final userPorIdProvider =
    FutureProvider.family<UserModel?, String>((ref, userId) {
  if (ref.watch(uidLogadoProvider) == null) return Future.value(null);
  return ref.watch(userRepositoryProvider).buscarPorId(userId);
});

/// Stream de auth do Firebase (null = deslogado). É a fonte de verdade que
/// o router usa para decidir entre /login e /home.
final authStateChangesProvider = StreamProvider<User?>((ref) {
  return ref.watch(authServiceProvider).authStateChanges;
});

/// uid do usuário logado, ou nulo se ninguém está logado.
///
/// **Todo provider que lê o Firestore precisa observar este** — não pelo
/// valor em si, mas porque é isso que faz o provider ser recriado quando a
/// conta muda.
///
/// Sem essa dependência acontece o seguinte: o listener aberto pela conta
/// anterior continua vivo durante o `signOut()`, o Firestore devolve
/// `permission-denied` (as regras exigem `request.auth != null`) e o
/// `AsyncValue` guarda esse erro. Como nada recria o provider quando a conta
/// nova entra, a tela fica travada no erro para sempre — foi exatamente o
/// "Erro ao carregar rodada: permission-denied" que aparecia ao trocar de
/// conta.
final uidLogadoProvider = Provider<String?>((ref) {
  return ref.watch(authStateChangesProvider).value?.uid;
});

/// Documento do User (Firestore) correspondente ao usuário autenticado.
final currentUserModelProvider = StreamProvider((ref) {
  final authState = ref.watch(authStateChangesProvider).value;
  if (authState == null) return Stream.value(null);
  return ref.watch(userRepositoryProvider).observar(authState.uid);
});

/// Resumo de um jogador para o admin decidir sobre um pedido de entrada:
/// como ele costuma ser avaliado e onde costuma jogar.
///
/// Existe porque aprovar alguém às cegas, só pelo nome, não dá base nenhuma
/// para a decisão — e a posição não está no cadastro do jogador, só nas
/// participações dele em cada racha.
class FichaJogador {
  const FichaJogador({
    this.media,
    this.totalRachas = 0,
    this.totalMvps = 0,
    this.posicao,
  });

  /// Nulo quando o jogador ainda não recebeu avaliação nenhuma.
  final double? media;
  final int totalRachas;
  final int totalMvps;
  final ({Posicao posicao, int vezes})? posicao;

  /// Jogador novo: sem avaliação e sem histórico de posição.
  bool get semHistorico => media == null && posicao == null;
}

final fichaDoJogadorProvider =
    FutureProvider.family<FichaJogador, String>((ref, userId) async {
  if (ref.watch(uidLogadoProvider) == null) return const FichaJogador();

  // As duas consultas saem juntas: uma não depende da outra, e esta ficha
  // aparece numa lista onde cada linha faz a sua.
  final rankingFuture =
      ref.watch(rankingRepositoryProvider).buscarPorUserId(userId);
  final participacoesFuture =
      ref.watch(participanteRepositoryProvider).buscarPorUser(userId);

  final ranking = await rankingFuture;
  final participacoes = await participacoesFuture;

  return FichaJogador(
    media: (ranking?.mediaAvaliacoes ?? 0) > 0 ? ranking!.mediaAvaliacoes : null,
    totalRachas: ranking?.totalRachas ?? 0,
    totalMvps: ranking?.totalMvps ?? 0,
    posicao: posicaoMaisFrequente(participacoes),
  );
});

/// Ranking de um User específico — tela de Perfil. Nulo até que ele receba
/// a primeira avaliação/estatística (nenhum racha avaliado ainda).
final rankingPorUserIdProvider =
    FutureProvider.family<RankingModel?, String>((ref, userId) {
  if (ref.watch(uidLogadoProvider) == null) return Future.value(null);
  return ref.watch(rankingRepositoryProvider).buscarPorUserId(userId);
});

/// Rodadas já finalizadas de um Grupo, mais recente primeiro — a tela de
/// detalhe do grupo só mostra a rodada aberta atual (`rachaAtualDoGrupoProvider`),
/// então sem isso as rodadas passadas ficavam inacessíveis assim que o
/// Fluxo 5 (finalizar → próxima rodada) tirava elas de cena.
final historicoDoGrupoProvider =
    FutureProvider.family<List<RachaModel>, String>((ref, grupoId) async {
  if (ref.watch(uidLogadoProvider) == null) return const [];
  final todos = await ref.watch(rachaRepositoryProvider).buscarTodosPorGrupo(grupoId);
  final finalizados = todos.where((r) => r.status == RachaStatus.finalizado).toList()
    ..sort((a, b) => b.dataHora.compareTo(a.dataHora));
  return finalizados;
});

/// Contexto necessário pra tela de Avaliação Pós-Jogo: quem o usuário
/// logado precisa avaliar (companheiros de time + candidatos a adversário)
/// e se ele já avaliou esse racha. Busca tudo de uma vez (one-shot) — nesse
/// ponto do fluxo os times já foram gerados, não há necessidade de ficar
/// reativo a mudanças.
final contextoAvaliacaoProvider = FutureProvider.family<ContextoAvaliacao,
    ({String rachaId, String uid})>((ref, args) async {
  if (ref.watch(uidLogadoProvider) == null) {
    return const ContextoAvaliacao(
      jaAvaliou: false,
      meuTime: null,
      companheiros: [],
      adversarios: [],
    );
  }
  final participanteRepo = ref.watch(participanteRepositoryProvider);
  final convidadoRepo = ref.watch(convidadoRepositoryProvider);
  final avaliacaoRepo = ref.watch(avaliacaoRepositoryProvider);

  final jaAvaliou =
      await avaliacaoRepo.jaAvaliou(rachaId: args.rachaId, avaliadorId: args.uid);
  final participantes = await participanteRepo.observarPorRacha(args.rachaId).first;
  final convidados = await convidadoRepo.observarPorRacha(args.rachaId).first;

  ParticipanteModel? meuParticipante;
  for (final p in participantes) {
    if (p.userId == args.uid) {
      meuParticipante = p;
      break;
    }
  }
  // Só conta se o participante continua confirmado — quem desiste depois
  // que os times já foram gerados fica com um `time` órfão no documento
  // (nada limpa esse campo), então sem esse filtro ele continuaria
  // aparecendo pra ser avaliado mesmo tendo saído do racha.
  final meuTime =
      (meuParticipante != null && meuParticipante.confirmado) ? meuParticipante.time : null;
  if (meuTime == null) {
    return ContextoAvaliacao(
      jaAvaliou: jaAvaliou,
      meuTime: null,
      companheiros: const [],
      adversarios: const [],
    );
  }

  final companheiros = <AlvoAvaliacao>[
    for (final p in participantes)
      if (p.confirmado && p.time == meuTime && p.userId != args.uid)
        AlvoAvaliacao(id: p.userId, tipo: TipoJogador.user),
    for (final c in convidados)
      if (c.aprovado && c.time == meuTime)
        AlvoAvaliacao(id: c.id, tipo: TipoJogador.convidado, nome: c.nome),
  ];
  final adversarios = <AlvoAvaliacao>[
    for (final p in participantes)
      if (p.confirmado && p.time != null && p.time != meuTime)
        AlvoAvaliacao(id: p.userId, tipo: TipoJogador.user),
    for (final c in convidados)
      if (c.aprovado && c.time != null && c.time != meuTime)
        AlvoAvaliacao(id: c.id, tipo: TipoJogador.convidado, nome: c.nome),
  ];

  return ContextoAvaliacao(
    jaAvaliou: jaAvaliou,
    meuTime: meuTime,
    companheiros: companheiros,
    adversarios: adversarios,
  );
});

/// Ranking de um Grupo: o desempenho de cada jogador considerando só as
/// rodadas daquele grupo. É um recorte diferente do `rankings/{userId}`
/// global (usado no Perfil e no balanceamento), e por isso não dá pra
/// derivar um do outro — de uma média global não se extrai a média dentro
/// de um grupo. O que os dois compartilham é a conta em si, feita por
/// `agregarRanking`, pra nenhum jogador aparecer com número diferente
/// dependendo da tela.
///
/// Calculado sob demanda, sem documento persistido: o recorte muda conforme
/// o grupo que está sendo olhado, e é uma tela consultada de vez em quando.
final rankingDoGrupoProvider =
    FutureProvider.family<List<RankingModel>, String>((ref, grupoId) async {
  if (ref.watch(uidLogadoProvider) == null) return const [];
  // Três consultas, sempre — não importa se o grupo tem duas rodadas ou
  // duzentas. As avaliações e estatísticas vêm direto pelo `grupoId` gravado
  // em cada documento; a lista de rodadas ainda é necessária pra contar os
  // títulos de MVP, que moram no próprio racha.
  final resultados = await Future.wait([
    ref.watch(rachaRepositoryProvider).buscarTodosPorGrupo(grupoId),
    ref.watch(avaliacaoRepositoryProvider).buscarPorGrupo(grupoId),
    ref.watch(estatisticaRepositoryProvider).buscarPorGrupo(grupoId),
  ]);

  final rachas = resultados[0] as List<RachaModel>;
  final avaliacoes = resultados[1] as List<AvaliacaoModel>;
  final estatisticas = resultados[2] as List<EstatisticaModel>;
  if (rachas.isEmpty) return const [];

  final ranking = agregarRanking(
    avaliacoes: avaliacoes,
    estatisticas: estatisticas,
    mvpUserIds: [
      for (final racha in rachas)
        if (racha.mvpUserId != null) racha.mvpUserId!,
    ],
  );

  return ordenarRanking(ranking.values);
});
