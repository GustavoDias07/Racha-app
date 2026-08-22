import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/alvo_avaliacao.dart';
import '../models/convidado_model.dart';
import '../models/enums.dart';
import '../models/estatistica_model.dart';
import '../models/grupo_model.dart';
import '../models/participante_model.dart';
import '../models/racha_model.dart';
import '../models/ranking_model.dart';
import '../models/user_model.dart';
import '../repositories/avaliacao_repository.dart';
import '../repositories/convidado_repository.dart';
import '../repositories/estatistica_repository.dart';
import '../repositories/grupo_repository.dart';
import '../repositories/participante_repository.dart';
import '../repositories/racha_repository.dart';
import '../repositories/ranking_repository.dart';
import '../repositories/user_repository.dart';
import '../services/auth_service.dart';
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

final firebaseMessagingProvider =
    Provider<FirebaseMessaging>((ref) => FirebaseMessaging.instance);

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService(ref.watch(firebaseMessagingProvider));
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

/// Rachas (grupos recorrentes) do usuário logado, para a lista da Home.
final meusGruposProvider = StreamProvider<List<GrupoModel>>((ref) {
  final uid = ref.watch(authStateChangesProvider).value?.uid;
  if (uid == null) return Stream.value(const []);
  return ref.watch(grupoRepositoryProvider).observarPorAdmin(uid);
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
  return ref.watch(rachaRepositoryProvider).observarAtualPorGrupo(grupoId);
});

/// Grupo por id, em stream — usado pela seção "Membros fixos" da tela de
/// detalhe do grupo, que precisa refletir na hora quando o admin
/// adiciona/remove alguém (o `GrupoModel` recebido por `extra` na
/// navegação é só um snapshot do momento em que a lista foi aberta).
final grupoPorIdProvider = StreamProvider.family<GrupoModel?, String>((ref, grupoId) {
  return ref.watch(grupoRepositoryProvider).observar(grupoId);
});

final participantesDoRachaProvider =
    StreamProvider.family<List<ParticipanteModel>, String>((ref, rachaId) {
  return ref.watch(participanteRepositoryProvider).observarPorRacha(rachaId);
});

final rachaPorIdProvider =
    StreamProvider.family<RachaModel?, String>((ref, rachaId) {
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

final convidadosDoRachaProvider =
    StreamProvider.family<List<ConvidadoModel>, String>((ref, rachaId) {
  return ref.watch(convidadoRepositoryProvider).observarPorRacha(rachaId);
});

final estatisticasDoRachaProvider =
    StreamProvider.family<List<EstatisticaModel>, String>((ref, rachaId) {
  return ref.watch(estatisticaRepositoryProvider).observarPorRacha(rachaId);
});

/// Dados de um User a partir do id — usado pra mostrar o nome nas listas de
/// participante, que só guardam o `userId`.
final userPorIdProvider =
    FutureProvider.family<UserModel?, String>((ref, userId) {
  return ref.watch(userRepositoryProvider).buscarPorId(userId);
});

/// Stream de auth do Firebase (null = deslogado). É a fonte de verdade que
/// o router usa para decidir entre /login e /home.
final authStateChangesProvider = StreamProvider<User?>((ref) {
  return ref.watch(authServiceProvider).authStateChanges;
});

/// Documento do User (Firestore) correspondente ao usuário autenticado.
final currentUserModelProvider = StreamProvider((ref) {
  final authState = ref.watch(authStateChangesProvider).value;
  if (authState == null) return Stream.value(null);
  return ref.watch(userRepositoryProvider).observar(authState.uid);
});

/// Ranking geral, ordenado por média de avaliação — tela de Ranking.
final rankingTopProvider = StreamProvider<List<RankingModel>>((ref) {
  return ref.watch(rankingRepositoryProvider).observarTop();
});

/// Ranking de um User específico — tela de Perfil. Nulo até que ele receba
/// a primeira avaliação/estatística (nenhum racha avaliado ainda).
final rankingPorUserIdProvider =
    FutureProvider.family<RankingModel?, String>((ref, userId) {
  return ref.watch(rankingRepositoryProvider).buscarPorUserId(userId);
});

/// Contexto necessário pra tela de Avaliação Pós-Jogo: quem o usuário
/// logado precisa avaliar (companheiros de time + candidatos a adversário)
/// e se ele já avaliou esse racha. Busca tudo de uma vez (one-shot) — nesse
/// ponto do fluxo os times já foram gerados, não há necessidade de ficar
/// reativo a mudanças.
final contextoAvaliacaoProvider = FutureProvider.family<ContextoAvaliacao,
    ({String rachaId, String uid})>((ref, args) async {
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
