import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/firestore_paths.dart';
import '../models/user_model.dart';

class UserRepository {
  UserRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection(FirestorePaths.users);

  Future<void> criar(UserModel user) {
    return _collection.doc(user.id).set(user.toMap());
  }

  Future<UserModel?> buscarPorId(String id) async {
    final doc = await _collection.doc(id).get();
    if (!doc.exists) return null;
    return UserModel.fromMap(doc.id, doc.data()!);
  }

  /// Vários usuários de uma vez, em paralelo — o `TimesController` precisa
  /// do cadastro de todos os confirmados ao mesmo tempo, e uma leitura por
  /// jogador em série custa caro num racha cheio. Quem não existir mais
  /// (conta apagada) fica de fora do mapa.
  Future<Map<String, UserModel>> buscarVarios(Iterable<String> ids) async {
    final unicos = ids.toSet();
    if (unicos.isEmpty) return {};

    final docs = await Future.wait(unicos.map((id) => _collection.doc(id).get()));
    return {
      for (final doc in docs)
        if (doc.exists) doc.id: UserModel.fromMap(doc.id, doc.data()!),
    };
  }

  Stream<UserModel?> observar(String id) {
    return _collection.doc(id).snapshots().map((doc) {
      if (!doc.exists) return null;
      return UserModel.fromMap(doc.id, doc.data()!);
    });
  }

  Future<void> atualizar(UserModel user) {
    return _collection.doc(user.id).update(user.toMap());
  }

  /// Grava o token do FCM do dispositivo atual - update parcial, separado
  /// de atualizar(), porque roda a cada login/refresh de token, sem
  /// relacao nenhuma com a tela de editar perfil (ver
  /// NotificationService/notificationSyncProvider).
  Future<void> atualizarFcmToken(String userId, String token) {
    return _collection.doc(userId).update({'fcmToken': token});
  }

  /// Busca por email exato OU por prefixo do nome (campo nomeBusca) - as
  /// duas ao mesmo tempo, ja que nao da pra saber de antemao o que a
  /// pessoa digitou. O limite superior do range usa o maior codepoint
  /// Unicode (0xF8FF) - truque padrao do Firestore pra simular um
  /// "startsWith", ja que ele nao tem contains/startsWith nativo. Contas
  /// criadas/editadas antes do campo nomeBusca existir so aparecem pela
  /// busca de email ate serem salvas de novo uma vez (editar perfil ja
  /// resolve isso).
  Future<List<UserModel>> buscarPorNomeOuEmail(String termo) async {
    final termoBusca = termo.trim().toLowerCase();
    if (termoBusca.isEmpty) return [];

    final limiteSuperior = termoBusca + String.fromCharCode(0xF8FF);
    final resultados = await Future.wait([
      _collection.where('email', isEqualTo: termoBusca).limit(10).get(),
      _collection
          .where('nomeBusca', isGreaterThanOrEqualTo: termoBusca)
          .where('nomeBusca', isLessThan: limiteSuperior)
          .limit(10)
          .get(),
    ]);

    final vistos = <String>{};
    final usuarios = <UserModel>[];
    for (final snap in resultados) {
      for (final doc in snap.docs) {
        if (vistos.add(doc.id)) {
          usuarios.add(UserModel.fromMap(doc.id, doc.data()));
        }
      }
    }
    return usuarios;
  }
}
