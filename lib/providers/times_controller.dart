import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/balanceamento/balanceador_times.dart';
import '../core/balanceamento/jogador_elegivel.dart';
import '../core/constants/balanceamento_constants.dart';
import '../models/enums.dart';
import '../models/racha_model.dart';
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

      final elegiveis = <JogadorElegivel>[];
      for (final p in participantes) {
        final user = await userRepo.buscarPorId(p.userId);
        if (user == null) continue;
        elegiveis.add(JogadorElegivel(
          id: p.id,
          tipo: TipoJogador.user,
          nome: user.nome,
          posicaoMain: p.posicaoMain,
          posicaoUsual: p.posicaoUsual,
          nota: notaNeutra,
          idade: user.idade,
          peso: user.peso,
        ));
      }
      for (final c in convidados) {
        elegiveis.add(JogadorElegivel(
          id: c.id,
          tipo: TipoJogador.convidado,
          nome: c.nome,
          posicaoMain: c.posicaoMain,
          posicaoUsual: c.posicaoUsual,
          nota: notaNeutra,
          idade: c.idadeAproximada,
          peso: c.pesoAproximado,
        ));
      }

      final resultado = const BalanceadorTimes().gerar(elegiveis);

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
      await batch.commit();
    });
  }

  void _salvarTimeEmLote(
    WriteBatch batch,
    String rachaId,
    JogadorElegivel jogador,
    TimeRacha time,
    ParticipanteRepository participanteRepo,
    ConvidadoRepository convidadoRepo,
  ) {
    if (jogador.tipo == TipoJogador.user) {
      participanteRepo.definirTimeEmLote(
        batch,
        rachaId: rachaId,
        participanteId: jogador.id,
        time: time,
      );
      return;
    }
    convidadoRepo.definirTimeEmLote(
      batch,
      rachaId: rachaId,
      convidadoId: jogador.id,
      time: time,
    );
  }
}

final timesControllerProvider =
    AsyncNotifierProvider<TimesController, void>(TimesController.new);
