import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/firestore_paths.dart';
import '../models/enums.dart';
import '../models/participante_model.dart';

class ParticipanteRepository {
  ParticipanteRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _collection(String rachaId) =>
      _firestore
          .collection(FirestorePaths.rachas)
          .doc(rachaId)
          .collection(FirestorePaths.participantes);

  Stream<List<ParticipanteModel>> observarPorRacha(String rachaId) {
    return _collection(rachaId).snapshots().map((snap) => snap.docs
        .map((d) => ParticipanteModel.fromMap(d.id, d.data()))
        .toList());
  }

  /// Todos os rachas em que o usuário é participante, cruzando a
  /// subcoleção `participantes` de todos os rachas (collection group). Usado
  /// pela Home pra listar convites — inclui rachas em que o usuário também é
  /// admin, então quem consome isso deve filtrar esse caso se necessário.
  Stream<List<ParticipanteModel>> observarMeusConvites(String userId) {
    return _firestore
        .collectionGroup(FirestorePaths.participantes)
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => ParticipanteModel.fromMap(d.id, d.data()))
            .toList());
  }

  Future<ParticipanteModel?> buscarPorUserId(String rachaId, String userId) async {
    final snap =
        await _collection(rachaId).where('userId', isEqualTo: userId).limit(1).get();
    if (snap.docs.isEmpty) return null;
    final doc = snap.docs.first;
    return ParticipanteModel.fromMap(doc.id, doc.data());
  }

  /// Convida um User cadastrado para o racha. Já existente = no-op (evita
  /// convite duplicado).
  Future<void> convidar({
    required String rachaId,
    required String userId,
    StatusConfirmacao status = StatusConfirmacao.pendente,
  }) async {
    final existente = await buscarPorUserId(rachaId, userId);
    if (existente != null) return;

    final participante = ParticipanteModel(
      id: '',
      rachaId: rachaId,
      userId: userId,
      statusConfirmacao: status,
    );
    await _collection(rachaId).add(participante.toMap());
  }

  /// Mesma coisa que `convidar`, mas escrevendo num `WriteBatch`
  /// compartilhado em vez de na hora — usado pelo `RachaController.finalizar`
  /// pra criar a próxima rodada e já convidar os membros fixos do grupo
  /// atomicamente (Fluxo 5). Sem checagem de duplicidade: o racha de
  /// destino acabou de ser criado nesse mesmo batch, não tem como já ter
  /// esse participante.
  void convidarEmLote(
    WriteBatch batch, {
    required String rachaId,
    required String userId,
    StatusConfirmacao status = StatusConfirmacao.pendente,
  }) {
    final participante = ParticipanteModel(
      id: '',
      rachaId: rachaId,
      userId: userId,
      statusConfirmacao: status,
    );
    batch.set(_collection(rachaId).doc(), participante.toMap());
  }

  Future<void> atualizarStatus({
    required String rachaId,
    required String participanteId,
    required StatusConfirmacao status,
  }) {
    return _collection(rachaId)
        .doc(participanteId)
        .update({'statusConfirmacao': status.name});
  }

  Future<void> definirPosicoes({
    required String rachaId,
    required String participanteId,
    required Posicao posicaoMain,
    required Posicao posicaoUsual,
  }) {
    return _collection(rachaId).doc(participanteId).update({
      'posicaoMain': posicaoMain.name,
      'posicaoUsual': posicaoUsual.name,
    });
  }

  /// Grava o time (A ou B) definido pelo algoritmo de balanceamento
  /// (`TimesController`) para este participante.
  Future<void> definirTime({
    required String rachaId,
    required String participanteId,
    required TimeRacha time,
  }) {
    return _collection(rachaId).doc(participanteId).update({'time': time.name});
  }

  /// Mesma coisa que `definirTime`, mas adiciona a um `WriteBatch`
  /// compartilhado em vez de escrever na hora — usado pelo
  /// `TimesController` pra gravar todos os times (Participantes e
  /// Convidados) atomicamente, evitando um racha com times parcialmente
  /// atribuídos se a escrita cair no meio.
  void definirTimeEmLote(
    WriteBatch batch, {
    required String rachaId,
    required String participanteId,
    required TimeRacha time,
  }) {
    batch.update(_collection(rachaId).doc(participanteId), {'time': time.name});
  }
}
