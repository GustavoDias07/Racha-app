import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/firestore_paths.dart';
import '../models/enums.dart';
import '../models/estatistica_model.dart';

class EstatisticaRepository {
  EstatisticaRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _collection(String rachaId) =>
      _firestore
          .collection(FirestorePaths.rachas)
          .doc(rachaId)
          .collection(FirestorePaths.estatisticas);

  Stream<List<EstatisticaModel>> observarPorRacha(String rachaId) {
    return _collection(rachaId).snapshots().map((snap) =>
        snap.docs.map((d) => EstatisticaModel.fromMap(d.id, d.data())).toList());
  }

  /// Um doc por jogador por racha — o id do documento é o próprio
  /// `jogadorId` (userId real do User, ou id do Convidado), então salvar
  /// sempre sobrescreve o registro existente em vez de duplicar.
  Future<void> salvar(EstatisticaModel estatistica) {
    return _collection(estatistica.rachaId)
        .doc(estatistica.jogadorId)
        .set(estatistica.toMap());
  }

  /// Todas as estatísticas que um User já acumulou, em qualquer racha —
  /// fonte de verdade que o `RankingController` usa pra recalcular
  /// `totalGols`/`totalAssistencias` do zero.
  Future<List<EstatisticaModel>> buscarTodasDe(String jogadorId) async {
    final snap = await _firestore
        .collectionGroup(FirestorePaths.estatisticas)
        .where('jogadorId', isEqualTo: jogadorId)
        .get();
    return snap.docs.map((d) => EstatisticaModel.fromMap(d.id, d.data())).toList();
  }

  /// Fluxo 3.1 (docs/estrutura.md): copia pro `userId` oficial as
  /// estatísticas que um Convidado acumulou (em qualquer racha) enquanto
  /// ainda era só um perfil temporário. Copia em vez de mover — o doc
  /// original continua em `estatisticas/{convidadoId}`, que é o que a aba
  /// Estatísticas daquele racha ainda usa pra exibir o convidado; o
  /// `RankingController` é quem passa a enxergar os dois (o antigo, sob o
  /// id do convidado, e o novo, sob o id do User) porque busca por
  /// `jogadorId` (ver `buscarTodasDe`) — sem duplicar total nenhum, já que
  /// os dois docs têm ids diferentes.
  Future<void> copiarParaUser({
    required String convidadoId,
    required String userId,
  }) async {
    final snap = await _firestore
        .collectionGroup(FirestorePaths.estatisticas)
        .where('jogadorId', isEqualTo: convidadoId)
        .get();
    if (snap.docs.isEmpty) return;

    final batch = _firestore.batch();
    for (final doc in snap.docs) {
      final antiga = EstatisticaModel.fromMap(doc.id, doc.data());
      final nova = EstatisticaModel(
        id: userId,
        rachaId: antiga.rachaId,
        jogadorId: userId,
        jogadorTipo: TipoJogador.user,
        gols: antiga.gols,
        assistencias: antiga.assistencias,
        cartoesAmarelos: antiga.cartoesAmarelos,
        cartoesVermelhos: antiga.cartoesVermelhos,
      );
      batch.set(doc.reference.parent.doc(userId), nova.toMap());
    }
    await batch.commit();
  }
}
