import 'enums.dart';

/// Perfil temporário, sem login, adicionado por um User a um Racha.
class ConvidadoModel {
  final String id;
  final String rachaId;
  final String convidadoPor; // userId de quem cadastrou
  final String nome;
  final int idadeAproximada;
  final double pesoAproximado;
  final Posicao? posicaoMain;
  final Posicao? posicaoUsual;
  final StatusAprovacao statusAprovacao;
  final TimeRacha? time;

  const ConvidadoModel({
    required this.id,
    required this.rachaId,
    required this.convidadoPor,
    required this.nome,
    required this.idadeAproximada,
    required this.pesoAproximado,
    this.posicaoMain,
    this.posicaoUsual,
    this.statusAprovacao = StatusAprovacao.pendente,
    this.time,
  });

  bool get aprovado => statusAprovacao == StatusAprovacao.aprovado;

  bool get isVersatil =>
      posicaoMain != null && posicaoUsual != null && posicaoMain != posicaoUsual;

  factory ConvidadoModel.fromMap(String id, Map<String, dynamic> map) {
    return ConvidadoModel(
      id: id,
      rachaId: map['rachaId'] as String,
      convidadoPor: map['convidadoPor'] as String,
      nome: map['nome'] as String,
      idadeAproximada: map['idadeAproximada'] as int,
      pesoAproximado: (map['pesoAproximado'] as num).toDouble(),
      posicaoMain: map['posicaoMain'] != null
          ? Posicao.values.byName(map['posicaoMain'] as String)
          : null,
      posicaoUsual: map['posicaoUsual'] != null
          ? Posicao.values.byName(map['posicaoUsual'] as String)
          : null,
      statusAprovacao:
          StatusAprovacao.values.byName(map['statusAprovacao'] as String),
      time: map['time'] != null ? TimeRacha.values.byName(map['time'] as String) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'rachaId': rachaId,
      'convidadoPor': convidadoPor,
      'nome': nome,
      'idadeAproximada': idadeAproximada,
      'pesoAproximado': pesoAproximado,
      'posicaoMain': posicaoMain?.name,
      'posicaoUsual': posicaoUsual?.name,
      'statusAprovacao': statusAprovacao.name,
      'time': time?.name,
    };
  }

  ConvidadoModel copyWith({
    Posicao? posicaoMain,
    Posicao? posicaoUsual,
    StatusAprovacao? statusAprovacao,
    TimeRacha? time,
  }) {
    return ConvidadoModel(
      id: id,
      rachaId: rachaId,
      convidadoPor: convidadoPor,
      nome: nome,
      idadeAproximada: idadeAproximada,
      pesoAproximado: pesoAproximado,
      posicaoMain: posicaoMain ?? this.posicaoMain,
      posicaoUsual: posicaoUsual ?? this.posicaoUsual,
      statusAprovacao: statusAprovacao ?? this.statusAprovacao,
      time: time ?? this.time,
    );
  }
}
