import 'package:cloud_firestore/cloud_firestore.dart';

import 'enums.dart';

/// Pedido de entrada de um User cadastrado num Grupo aberto pra novos
/// membros (achado via aba "Rachas Próximos"). Diferente de `ConvidadoModel`
/// (perfil temporário adicionado por outro jogador): aqui é o próprio User
/// já cadastrado que solicita, e a aprovação vira `membrosFixos` do grupo em
/// vez de um Convidado dentro de um racha específico.
class SolicitacaoModel {
  final String id;
  final String grupoId;
  final String solicitanteId; // userId de quem pediu entrada
  final StatusAprovacao status;
  final DateTime criadoEm;

  const SolicitacaoModel({
    required this.id,
    required this.grupoId,
    required this.solicitanteId,
    this.status = StatusAprovacao.pendente,
    required this.criadoEm,
  });

  factory SolicitacaoModel.fromMap(String id, Map<String, dynamic> map) {
    return SolicitacaoModel(
      id: id,
      grupoId: map['grupoId'] as String,
      solicitanteId: map['solicitanteId'] as String,
      status: StatusAprovacao.values.byName(map['status'] as String),
      criadoEm: (map['criadoEm'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'grupoId': grupoId,
      'solicitanteId': solicitanteId,
      'status': status.name,
      'criadoEm': Timestamp.fromDate(criadoEm),
    };
  }
}
