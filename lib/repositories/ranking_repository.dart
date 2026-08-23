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

  /// Rankings de vários jogadores de uma vez — usado pelo
  /// `TimesController` na hora de montar os times, que precisa da média de
  /// avaliação de todo mundo confirmado. Dispara as leituras em paralelo em
  /// vez de uma por vez: num racha de campão são 22 jogadores, e em série
  /// isso vira 22 idas ao servidor enfileiradas.
  ///
  /// Quem ainda não tem documento de ranking simplesmente não aparece no
  /// mapa devolvido — cabe a quem chamou decidir o que fazer (o
  /// `TimesController` usa a nota neutra nesse caso).
  Future<Map<String, RankingModel>> buscarVarios(Iterable<String> userIds) async {
    final ids = userIds.toSet();
    if (ids.isEmpty) return {};

    final docs = await Future.wait(ids.map((id) => _collection.doc(id).get()));
    return {
      for (final doc in docs)
        if (doc.exists) doc.id: RankingModel.fromMap(doc.id, doc.data()!),
    };
  }

  Future<void> salvar(RankingModel ranking) {
    return _collection.doc(ranking.userId).set(ranking.toMap());
  }
}
