import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/firestore_paths.dart';
import '../models/enums.dart';
import '../models/grupo_model.dart';

class GrupoRepository {
  GrupoRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection(FirestorePaths.grupos);

  Future<String> criar(GrupoModel grupo) async {
    final docRef = _collection.doc();
    await docRef.set(grupo.toMap());
    return docRef.id;
  }

  Stream<GrupoModel?> observar(String id) {
    return _collection.doc(id).snapshots().map((doc) {
      if (!doc.exists) return null;
      return GrupoModel.fromMap(doc.id, doc.data()!);
    });
  }

  /// Busca one-shot (não stream) — usada pelo `RachaController.finalizar`
  /// pra ler a configuração padrão do Grupo na hora de gerar a próxima
  /// ocorrência (Fluxo 5).
  Future<GrupoModel?> buscarPorId(String id) async {
    final doc = await _collection.doc(id).get();
    if (!doc.exists) return null;
    return GrupoModel.fromMap(doc.id, doc.data()!);
  }

  Stream<List<GrupoModel>> observarPorAdmin(String adminId) {
    return _collection.where('adminId', isEqualTo: adminId).snapshots().map(
        (snap) =>
            snap.docs.map((d) => GrupoModel.fromMap(d.id, d.data())).toList());
  }

  /// Grupos em que o usuário entrou como membro fixo (via solicitação
  /// aprovada ou adicionado pelo admin) — ele não é dono de nenhum deles,
  /// então `observarPorAdmin` nunca os traria, e sem isso o grupo ficava
  /// invisível pra quem só participa: só chegavam os convites avulsos de
  /// cada rodada.
  Stream<List<GrupoModel>> observarPorMembro(String userId) {
    return _collection
        .where('membrosFixos', arrayContains: userId)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => GrupoModel.fromMap(d.id, d.data())).toList());
  }

  /// Grupos abertos pra novos membros — base da aba "Rachas Próximos". Sem
  /// filtro geográfico no servidor (ver `lib/core/utils/geo_utils.dart`): a
  /// tela filtra/ordena por distância no cliente a partir dessa lista.
  Stream<List<GrupoModel>> observarAbertos() {
    return _collection
        .where('abertoParaNovosMembros', isEqualTo: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => GrupoModel.fromMap(d.id, d.data())).toList());
  }

  /// Grava a lista de membros fixos (User) convidados automaticamente toda
  /// vez que uma nova rodada do grupo nasce (Fluxo 5).
  Future<void> atualizarMembrosFixos(String grupoId, List<String> membrosFixos) {
    return _collection.doc(grupoId).update({'membrosFixos': membrosFixos});
  }

  /// Quem pode fazer a chamada nas rodadas do grupo (ver
  /// `GrupoModel.auxiliares`).
  Future<void> atualizarAuxiliares(String grupoId, List<String> auxiliares) {
    return _collection.doc(grupoId).update({'auxiliares': auxiliares});
  }

  /// Edita a configuração padrão do grupo — só vale pras próximas rodadas
  /// que ainda vão nascer (Fluxo 5); a rodada aberta atual não muda
  /// sozinha, tem que editar ela separadamente (`EditarRachaScreen`).
  Future<void> atualizar({
    required String grupoId,
    required String nome,
    required String localPadrao,
    required DiaSemana diaSemana,
    required String horario,
    required TipoCampo tipoCampoPadrao,
    required int qtdJogadoresLinhaPadrao,
    GeoPoint? localizacao,
    bool abertoParaNovosMembros = false,
  }) {
    return _collection.doc(grupoId).update({
      'nome': nome,
      'localPadrao': localPadrao,
      'diaSemana': diaSemana.name,
      'horario': horario,
      'tipoCampoPadrao': tipoCampoPadrao.name,
      'qtdJogadoresLinhaPadrao': qtdJogadoresLinhaPadrao,
      'localizacao': localizacao,
      'abertoParaNovosMembros': abertoParaNovosMembros,
    });
  }

  /// Saída do próprio jogador do grupo (não é o admin removendo alguém —
  /// ver `atualizarMembrosFixos`). Usa `arrayRemove` em vez de reescrever a
  /// lista inteira porque a regra do Firestore só libera essa escrita pra
  /// quem está tirando a si mesmo, e um `set` da lista inteira correria o
  /// risco de sobrescrever entradas que o admin adicionou nesse meio tempo.
  Future<void> sair(String grupoId, String userId) {
    return _collection.doc(grupoId).update({
      'membrosFixos': FieldValue.arrayRemove([userId]),
    });
  }

  /// Apaga o Grupo dentro de um batch — as rodadas (rachas) já geradas a
  /// partir dele não são apagadas junto (não têm delete permitido pelas
  /// regras), só param de aparecer na Home porque o Grupo dono sumiu.
  ///
  /// Em lote porque a remoção nunca é só do grupo: os pedidos de entrada vão
  /// junto e os avisos pros solicitantes nascem no mesmo commit — ver
  /// `GrupoController.remover`.
  void removerEmLote(WriteBatch batch, String id) {
    batch.delete(_collection.doc(id));
  }
}
