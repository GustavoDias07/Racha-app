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

  /// Quem pode fazer a chamada nesta rodada, além do admin. Copiado dos
  /// `auxiliares` do Grupo quando a rodada nasce — mesma desnormalização do
  /// `grupoId` em avaliações: a regra do Firestore precisa decidir a
  /// permissão com uma leitura só, e ir buscar o grupo a cada escrita de
  /// presença dobraria o custo de uma chamada inteira.
  final List<String> anotadores;

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
    this.anotadores = const [],
  });

  /// Formação derivada: goleiro fixo + vagas de linha.
  int get totalVagas => qtdJogadoresLinha + 1;

  /// Pode registrar presença nesta rodada.
  bool podeFazerChamada(String? userId) =>
      userId != null && (userId == adminId || anotadores.contains(userId));

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
      anotadores: List<String>.from(map['anotadores'] as List? ?? const []),
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
      'anotadores': anotadores,
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
      mvpUserId: mvpUserId,
      anotadores: anotadores,
    );
  }
}
