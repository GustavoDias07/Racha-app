import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/firestore_paths.dart';
import '../models/ranking_model.dart';

class RankingRepository {
  RankingRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection(FirestorePaths.rankings);

  Future<RankingModel?> buscarPorUserId(String userId) async {
    final doc = await _collection.doc(userId).get();
    if (!doc.exists) return null;
    return RankingModel.fromMap(doc.id, doc.data()!);
  }

  Future<void> salvar(RankingModel ranking) {
    return _collection.doc(ranking.userId).set(ranking.toMap());
  }

  /// Ajusta `totalMvps` atomicamente (+1/-1), sem precisar ler o doc antes
  /// — evita perder incrementos quando dois clientes mexem no MVP da mesma
  /// rodada ao mesmo tempo (ver RankingController.calcularMvpDaRodada).
  /// Os demais campos entram com `increment(0)` só pra garantir que
  /// existam no documento (as regras do Firestore exigem todos os campos
  /// presentes em toda escrita — ver firestore.rules).
  Future<void> incrementarMvp(String userId, int delta) {
    return _collection.doc(userId).set({
      'mediaAvaliacoes': FieldValue.increment(0),
      'totalMvps': FieldValue.increment(delta),
      'totalGols': FieldValue.increment(0),
      'totalAssistencias': FieldValue.increment(0),
      'totalRachas': FieldValue.increment(0),
    }, SetOptions(merge: true));
  }

  /// Ranking geral ordenado por média de avaliação — tela de Ranking.
  Stream<List<RankingModel>> observarTop({int limit = 50}) {
    return _collection
        .orderBy('mediaAvaliacoes', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => RankingModel.fromMap(d.id, d.data())).toList());
  }
}
