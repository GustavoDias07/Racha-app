import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/firestore_paths.dart';
import '../models/enums.dart';
import '../models/solicitacao_model.dart';

class SolicitacaoRepository {
  SolicitacaoRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _collection(String grupoId) =>
      _firestore
          .collection(FirestorePaths.grupos)
          .doc(grupoId)
          .collection(FirestorePaths.solicitacoes);

  Future<void> criar(SolicitacaoModel solicitacao) {
    return _collection(solicitacao.grupoId).add(solicitacao.toMap());
  }

  Stream<List<SolicitacaoModel>> observarPendentes(String grupoId) {
    return _collection(grupoId)
        .where('status', isEqualTo: StatusAprovacao.pendente.name)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => SolicitacaoModel.fromMap(d.id, d.data()))
            .toList());
  }

  /// Consulta base dos pedidos de um jogador num grupo. Existe pra que a
  /// leitura one-shot (dedup na hora de criar um pedido) e o stream (botão da
  /// tela) não repitam filtro nem ordenação — se as duas divergissem, o botão
  /// diria uma coisa e a gravação faria outra.
  Query<Map<String, dynamic>> _meusPedidos(String grupoId, String userId) =>
      _collection(grupoId).where('solicitanteId', isEqualTo: userId);

  /// Último pedido do usuário nesse grupo, qualquer que seja o status —
  /// busca one-shot usada pelo `SolicitacaoController` antes de criar um
  /// pedido novo. Precisa enxergar recusas, não só pendências: recusa vale
  /// até o admin reabrir, senão o jogador recusado pediria de novo em
  /// seguida e o admin viveria recusando a mesma pessoa.
  Future<SolicitacaoModel?> buscarUltimaSolicitacao(
      String grupoId, String userId) async {
    final snap = await _meusPedidos(grupoId, userId).get();
    return _maisRecente(snap.docs);
  }

  /// Pedidos recusados de um grupo — a tela de detalhe mostra pro admin, que
  /// é o único caminho de volta pra quem foi recusado (ver
  /// `SolicitacaoController.reabrir`).
  Stream<List<SolicitacaoModel>> observarRecusadas(String grupoId) {
    return _collection(grupoId)
        .where('status', isEqualTo: StatusAprovacao.recusado.name)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => SolicitacaoModel.fromMap(d.id, d.data()))
            .toList());
  }

  /// O pedido mais recente da lista. A ordenação é feita no cliente porque
  /// são um ou dois documentos por jogador — não vale exigir índice composto
  /// no Firestore por causa disso.
  SolicitacaoModel? _maisRecente(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    if (docs.isEmpty) return null;
    final solicitacoes = docs
        .map((d) => SolicitacaoModel.fromMap(d.id, d.data()))
        .toList()
      ..sort((a, b) => b.criadoEm.compareTo(a.criadoEm));
    return solicitacoes.first;
  }

  /// Último pedido do usuário nesse grupo, em stream — o botão da aba
  /// "Rachas Próximos" precisa reagir na hora ao próprio pedido e depois à
  /// resposta do admin. Sem filtro de status: quem foi recusado precisa ver
  /// "Pedido recusado" em vez de um botão que parece nunca ter sido
  /// apertado, e a ordenação por `criadoEm` no cliente evita exigir índice
  /// composto pra uma lista que tem 1 ou 2 documentos.
  Stream<SolicitacaoModel?> observarMinhaSolicitacao(
      String grupoId, String userId) {
    return _meusPedidos(grupoId, userId)
        .snapshots()
        .map((snap) => _maisRecente(snap.docs));
  }

  /// Todos os pedidos de um grupo, em qualquer status — usado quando o grupo
  /// é apagado e a subcoleção inteira tem que ir junto.
  Future<List<SolicitacaoModel>> buscarTodas(String grupoId) async {
    final snap = await _collection(grupoId).get();
    return snap.docs
        .map((d) => SolicitacaoModel.fromMap(d.id, d.data()))
        .toList();
  }

  void removerEmLote(
    WriteBatch batch, {
    required String grupoId,
    required String solicitacaoId,
  }) {
    batch.delete(_collection(grupoId).doc(solicitacaoId));
  }

  Future<void> atualizarStatus({
    required String grupoId,
    required String solicitacaoId,
    required StatusAprovacao status,
  }) {
    return _collection(grupoId).doc(solicitacaoId).update({'status': status.name});
  }
}
