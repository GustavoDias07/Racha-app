import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/firestore_paths.dart';
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
}
