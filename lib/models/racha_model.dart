import 'package:cloud_firestore/cloud_firestore.dart';

import 'enums.dart';

/// Uma ocorrência de racha (evento), avulsa ou gerada a partir de um Grupo.
class RachaModel {
  final String id;
  final String? grupoId;
  final String nome;
  final String local;
  final DateTime dataHora;
  final TipoCampo tipoCampo;
  final int qtdJogadoresLinha;
  final String adminId;
  final RachaStatus status;
  // userId do MVP da rodada, calculado a partir das avaliações recebidas
  // (ver RankingController.calcularMvpDaRodada). Nulo até que o admin
  // acione o cálculo pela aba Times.
  final String? mvpUserId;

  const RachaModel({
    required this.id,
    this.grupoId,
    required this.nome,
    required this.local,
    required this.dataHora,
    required this.tipoCampo,
    required this.qtdJogadoresLinha,
    required this.adminId,
    this.status = RachaStatus.aberto,
    this.mvpUserId,
  });

  /// Formação derivada: goleiro fixo + vagas de linha.
  int get totalVagas => qtdJogadoresLinha + 1;

  factory RachaModel.fromMap(String id, Map<String, dynamic> map) {
    return RachaModel(
      id: id,
      grupoId: map['grupoId'] as String?,
      nome: map['nome'] as String,
      local: map['local'] as String,
      dataHora: (map['dataHora'] as Timestamp).toDate(),
      tipoCampo: TipoCampo.values.byName(map['tipoCampo'] as String),
      qtdJogadoresLinha: map['qtdJogadoresLinha'] as int,
      adminId: map['adminId'] as String,
      status: RachaStatus.values.byName(map['status'] as String),
      mvpUserId: map['mvpUserId'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'grupoId': grupoId,
      'nome': nome,
      'local': local,
      'dataHora': Timestamp.fromDate(dataHora),
      'tipoCampo': tipoCampo.name,
      'qtdJogadoresLinha': qtdJogadoresLinha,
      'adminId': adminId,
      'status': status.name,
      'mvpUserId': mvpUserId,
    };
  }

  RachaModel copyWith({
    String? nome,
    String? local,
    DateTime? dataHora,
    TipoCampo? tipoCampo,
    int? qtdJogadoresLinha,
    RachaStatus? status,
  }) {
    return RachaModel(
      id: id,
      grupoId: grupoId,
      nome: nome ?? this.nome,
      local: local ?? this.local,
      dataHora: dataHora ?? this.dataHora,
      tipoCampo: tipoCampo ?? this.tipoCampo,
      qtdJogadoresLinha: qtdJogadoresLinha ?? this.qtdJogadoresLinha,
      adminId: adminId,
      status: status ?? this.status,
    );
  }
}
