import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/balanceamento/balanceador_times.dart';
import '../core/balanceamento/jogador_elegivel.dart';
import '../core/constants/balanceamento_constants.dart';
import '../core/presenca/pontuacao_presenca.dart';
import '../models/enums.dart';
import '../models/racha_model.dart';
import '../models/ranking_model.dart';
import '../repositories/convidado_repository.dart';
import '../repositories/participante_repository.dart';
import 'firebase_providers.dart';

/// Orquestra a geração de times: junta Participantes confirmados e
/// Convidados aprovados num único "Jogador Elegível" (docs/estrutura.md),
/// roda o `BalanceadorTimes` e grava o time (A/B) de cada um.
class TimesController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> gerar(RachaModel racha) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final participanteRepo = ref.read(participanteRepositoryProvider);
      final convidadoRepo = ref.read(convidadoRepositoryProvider);
      final userRepo = ref.read(userRepositoryProvider);

      final participantes = (await participanteRepo.observarPorRacha(racha.id).first)
          .where((p) => p.confirmado)
          .toList();
      final convidados = (await convidadoRepo.observarPorRacha(racha.id).first)
          .where((c) => c.aprovado)
          .toList();

      if (participantes.length + convidados.length < racha.totalVagas) {
        throw Exception(
          'Confirmados insuficientes: são necessários pelo menos ${racha.totalVagas} '
          'jogadores (formação ${racha.tipoCampo.label}).',
        );
      }

      // Cadastro e ranking de todo mundo de uma vez, em paralelo — antes
      // isso era um `await` por jogador dentro do laço, o que num campão
      // (22 confirmados) enfileirava 22 idas ao servidor.
      final userIds = participantes.map((p) => p.userId).toSet();
      final users = await userRepo.buscarVarios(userIds);
      final rankings = await ref.read(rankingRepositoryProvider).buscarVarios(userIds);

      final elegiveis = <JogadorElegivel>[];
      for (final p in participantes) {
        final user = users[p.userId];
        if (user == null) continue;
        elegiveis.add(JogadorElegivel(
          id: p.id,
          tipo: TipoJogador.user,
          nome: user.nome,
          posicaoMain: p.posicaoMain,
          posicaoUsual: p.posicaoUsual,
          nota: _notaDe(rankings[p.userId]),
          idade: user.idade,
          peso: user.peso,
          golsPorJogo: _golsPorJogoDe(rankings[p.userId]),
        ));
      }
      for (final c in convidados) {
        elegiveis.add(JogadorElegivel(
          id: c.id,
          tipo: TipoJogador.convidado,
          nome: c.nome,
          posicaoMain: c.posicaoMain,
          posicaoUsual: c.posicaoUsual,
          // Convidado não tem histórico de avaliação (não é User, não tem
          // Ranking), então sempre entra com a nota neutra.
          nota: notaNeutra,
          idade: c.idadeAproximada,
          peso: c.pesoAproximado,
        ));
      }

      // Banco (RF22): se confirmou mais gente do que cabe nos dois times,
      // só os primeiros pela pontuação de presença entram no balanceamento.
      // O banco é decidido ANTES de balancear — presença decide quem joga,
      // a nota decide só em que time cada um joga (ver T16: assiduidade
      // nunca pode virar habilidade).
      final presencas = racha.grupoId == null
          ? const <String, List<int>>{}
          : (await ref.read(grupoRepositoryProvider).buscarPorId(racha.grupoId!))
                  ?.presencas ??
              const <String, List<int>>{};
      final userIdDoParticipante = {for (final p in participantes) p.id: p.userId};
      final atrasados = {
        for (final p in participantes)
          if (p.presenca == PresencaFinal.atrasou) p.id,
      };
      final confirmadoEm = {for (final p in participantes) p.id: p.confirmadoEm};

      final elenco = montarElenco(
        [
          for (final j in elegiveis)
            CandidatoVaga(
              id: j.id,
              pontuacao: switch (presencas[userIdDoParticipante[j.id]]) {
                final historico? => PontuacaoPresenca(historico),
                null => null,
              },
              atrasou: atrasados.contains(j.id),
              confirmadoEm: confirmadoEm[j.id],
            ),
        ],
        vagas: 2 * racha.totalVagas,
      );
      final titulares = {for (final c in elenco.titulares) c.id};
      final porId = {for (final j in elegiveis) j.id: j};

      final resultado = const BalanceadorTimes().gerar(
        elegiveis.where((j) => titulares.contains(j.id)).toList(),
        qtdJogadoresLinha: racha.qtdJogadoresLinha,
      );

      // Um único batch (tudo ou nada) — sem isso, uma falha de rede no
      // meio da escrita deixaria o racha com times parcialmente
      // atribuídos (alguns jogadores com `time` definido, outros não).
      final batch = ref.read(firestoreProvider).batch();
      for (final jogador in resultado.timeA) {
        _salvarTimeEmLote(batch, racha.id, jogador, TimeRacha.A, participanteRepo, convidadoRepo);
      }
      for (final jogador in resultado.timeB) {
        _salvarTimeEmLote(batch, racha.id, jogador, TimeRacha.B, participanteRepo, convidadoRepo);
      }
      for (var i = 0; i < elenco.banco.length; i++) {
        _salvarTimeEmLote(batch, racha.id, porId[elenco.banco[i].id]!, null,
            participanteRepo, convidadoRepo,
            ordemBanco: i + 1);
      }
      await batch.commit();
    });
  }

  /// Média real do jogador quando ela existe. Um documento de ranking pode
  /// existir com `mediaAvaliacoes` zerada — é o caso de quem só recebeu MVP
  /// ou estatística e nunca foi avaliado — e zero ali significa "sem
  /// histórico", não "joga mal": nesses casos vale a nota neutra, senão o
  /// jogador seria tratado como o pior do racha.
  double _notaDe(RankingModel? ranking) {
    final media = ranking?.mediaAvaliacoes ?? 0;
    return media > 0 ? media : notaNeutra;
  }

  /// Gols por rodada a partir do ranking, ou `null` quando não dá para
  /// calcular.
  ///
  /// O divisor é `totalRachas`, que hoje conta rodadas em que o jogador foi
  /// **avaliado**, não rodadas jogadas (ver T7 em docs/tarefas.md). É uma
  /// aproximação: quem jogou e não foi avaliado fica com média um pouco
  /// inflada. Sem nenhuma rodada avaliada não há divisor confiável, e o
  /// jogador entra como desconhecido — o balanceador o trata como a média
  /// do grupo.
  double? _golsPorJogoDe(RankingModel? ranking) {
    if (ranking == null || ranking.totalRachas == 0) return null;
    return ranking.totalGols / ranking.totalRachas;
  }

  void _salvarTimeEmLote(
    WriteBatch batch,
    String rachaId,
    JogadorElegivel jogador,
    TimeRacha? time,
    ParticipanteRepository participanteRepo,
    ConvidadoRepository convidadoRepo, {
    int? ordemBanco,
  }) {
    if (jogador.tipo == TipoJogador.user) {
      participanteRepo.definirTimeEmLote(
        batch,
        rachaId: rachaId,
        participanteId: jogador.id,
        time: time,
        ordemBanco: ordemBanco,
      );
      return;
    }
    convidadoRepo.definirTimeEmLote(
      batch,
      rachaId: rachaId,
      convidadoId: jogador.id,
      time: time,
      ordemBanco: ordemBanco,
    );
  }
}

final timesControllerProvider =
    AsyncNotifierProvider<TimesController, void>(TimesController.new);
