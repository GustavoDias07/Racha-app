import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/firestore_paths.dart';
import '../models/aviso_model.dart';

class AvisoRepository {
  AvisoRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _collection(String userId) =>
      _firestore
          .collection(FirestorePaths.users)
          .doc(userId)
          .collection(FirestorePaths.avisos);

  Stream<List<AvisoModel>> observar(String userId) {
    return _collection(userId).snapshots().map((snap) {
      final avisos =
          snap.docs.map((d) => AvisoModel.fromMap(d.id, d.data())).toList()
            ..sort((a, b) => b.criadoEm.compareTo(a.criadoEm));
      return avisos;
    });
  }

  /// Deixa o recado dentro de um `WriteBatch` já em andamento. É sempre
  /// assim que um aviso nasce: ele existe justamente porque outra coisa foi
  /// apagada, e as duas escritas precisam acontecer juntas — senão dá pra
  /// apagar o grupo e falhar o aviso, deixando a pessoa sem explicação.
  void criarEmLote(
    WriteBatch batch, {
    required String userId,
    required String mensagem,
  }) {
    final aviso = AvisoModel(
      id: '',
      mensagem: mensagem,
      criadoEm: DateTime.now(),
    );
    batch.set(_collection(userId).doc(), aviso.toMap());
  }

  /// Dispensar é apagar. Um aviso lido não tem mais nenhuma utilidade, e
  /// guardar "lido: true" só criaria lixo pra sempre no documento do usuário.
  Future<void> dispensar({required String userId, required String avisoId}) {
    return _collection(userId).doc(avisoId).delete();
  }
}
