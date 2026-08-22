import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/data_utils.dart';
import '../models/enums.dart';
import '../models/racha_model.dart';
import 'firebase_providers.dart';

class RachaController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  /// Cria um racha avulso (sem Grupo) — o admin já entra como participante
  /// confirmado, mesma regra usada pelo `GrupoController.criar`.
  Future<void> criar({
    required String nome,
    required String local,
    required DateTime dataHora,
    required TipoCampo tipoCampo,
    required int qtdJogadoresLinha,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final adminId = ref.read(firebaseAuthProvider).currentUser!.uid;
      final racha = RachaModel(
        id: '',
        nome: nome,
        local: local,
        dataHora: dataHora,
        tipoCampo: tipoCampo,
        qtdJogadoresLinha: qtdJogadoresLinha,
        adminId: adminId,
      );
      final rachaId = await ref.read(rachaRepositoryProvider).criar(racha);
      await ref.read(participanteRepositoryProvider).convidar(
            rachaId: rachaId,
            userId: adminId,
            status: StatusConfirmacao.confirmado,
          );
    });
  }

  /// Marca o racha como finalizado e, se ele vier de um Grupo recorrente,
  /// já cria a próxima ocorrência com os membros fixos convidados
  /// automaticamente (Fluxo 5, docs/estrutura.md). Rachas avulsos só
  /// encerram, sem gerar sequência. Tudo num único batch (o encerramento e
  /// a criação da próxima rodada), pra nunca deixar o grupo sem nenhuma
  /// rodada aberta se a escrita cair no meio.
  Future<void> finalizar(RachaModel racha) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final rachaRepo = ref.read(rachaRepositoryProvider);
      final participanteRepo = ref.read(participanteRepositoryProvider);
      final batch = ref.read(firestoreProvider).batch();

      rachaRepo.atualizarStatusEmLote(batch, rachaId: racha.id, status: RachaStatus.finalizado);

      final grupoId = racha.grupoId;
      if (grupoId != null) {
        final grupo = await ref.read(grupoRepositoryProvider).buscarPorId(grupoId);
        if (grupo != null) {
          final proximaRef = rachaRepo.novoDocRef();
          final proxima = RachaModel(
            id: proximaRef.id,
            grupoId: grupo.id,
            nome: grupo.nome,
            local: grupo.localPadrao,
            dataHora: proximaOcorrencia(grupo.diaSemana, grupo.horario),
            tipoCampo: grupo.tipoCampoPadrao,
            qtdJogadoresLinha: grupo.qtdJogadoresLinhaPadrao,
            adminId: grupo.adminId,
          );
          rachaRepo.criarEmLote(batch, proximaRef, proxima);
          participanteRepo.convidarEmLote(
            batch,
            rachaId: proximaRef.id,
            userId: grupo.adminId,
            status: StatusConfirmacao.confirmado,
          );
          for (final membroId in grupo.membrosFixos) {
            if (membroId == grupo.adminId) continue;
            participanteRepo.convidarEmLote(batch, rachaId: proximaRef.id, userId: membroId);
          }
        }
      }

      await batch.commit();
    });
  }

  /// Edita um racha já criado — avulso ou rodada de um Grupo (Fluxo 2:
  /// "o admin ainda pode ajustar a ocorrência gerada automaticamente").
  Future<void> atualizar({
    required String rachaId,
    required String nome,
    required String local,
    required DateTime dataHora,
    required TipoCampo tipoCampo,
    required int qtdJogadoresLinha,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() {
      return ref.read(rachaRepositoryProvider).atualizar(
            rachaId: rachaId,
            nome: nome,
            local: local,
            dataHora: dataHora,
            tipoCampo: tipoCampo,
            qtdJogadoresLinha: qtdJogadoresLinha,
          );
    });
  }

  /// Apaga um racha avulso (sem Grupo) — rodada de Grupo não tem esse
  /// caminho, ver `RachaRepository.remover`.
  Future<void> remover(String rachaId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() {
      return ref.read(rachaRepositoryProvider).remover(rachaId);
    });
  }
}

final rachaControllerProvider =
    AsyncNotifierProvider<RachaController, void>(RachaController.new);
