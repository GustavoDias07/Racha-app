import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/firestore_paths.dart';
import '../models/avaliacao_model.dart';

class AvaliacaoRepository {
  AvaliacaoRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _collection(String rachaId) =>
      _firestore
          .collection(FirestorePaths.rachas)
          .doc(rachaId)
          .collection(FirestorePaths.avaliacoes);

  Future<void> avaliar(AvaliacaoModel avaliacao) {
    return _collection(avaliacao.rachaId).add(avaliacao.toMap());
  }

  /// Grava várias avaliações de uma vez, atomicamente (tudo ou nada). É o
  /// que a tela de Avaliação Pós-Jogo usa pra enviar companheiros + 1
  /// adversário juntos — sem isso, uma falha de rede no meio do envio
  /// deixaria só parte das avaliações salvas, e `jaAvaliou` já ficaria
  /// `true` (existe pelo menos 1 doc), travando o usuário pra sempre sem
  /// poder completar ou reenviar.
  Future<void> avaliarEmLote(List<AvaliacaoModel> avaliacoes) async {
    if (avaliacoes.isEmpty) return;
    final batch = _firestore.batch();
    for (final avaliacao in avaliacoes) {
      batch.set(_collection(avaliacao.rachaId).doc(), avaliacao.toMap());
    }
    await batch.commit();
  }

  Future<bool> jaAvaliou({required String rachaId, required String avaliadorId}) async {
    final snap = await _collection(rachaId)
        .where('avaliadorId', isEqualTo: avaliadorId)
        .limit(1)
        .get();
    return snap.docs.isNotEmpty;
  }

  Stream<List<AvaliacaoModel>> observarPorRacha(String rachaId) {
    return _collection(rachaId).snapshots().map((snap) =>
        snap.docs.map((d) => AvaliacaoModel.fromMap(d.id, d.data())).toList());
  }

  /// Todas as avaliações que um User já recebeu, em qualquer racha —
  /// consulta entre coleções (collectionGroup). É a fonte de verdade que o
  /// `RankingController` usa pra recalcular a média geral do zero, em vez
  /// de manter um total incremental que poderia dessincronizar.
  Future<List<AvaliacaoModel>> buscarRecebidasPor(String avaliadoId) async {
    final snap = await _firestore
        .collectionGroup(FirestorePaths.avaliacoes)
        .where('avaliadoId', isEqualTo: avaliadoId)
        .get();
    return snap.docs.map((d) => AvaliacaoModel.fromMap(d.id, d.data())).toList();
  }
}
