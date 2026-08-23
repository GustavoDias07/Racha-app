import 'enums.dart';

/// Um User dentro de um Racha específico.
class ParticipanteModel {
  final String id;
  final String rachaId;
  final String userId;
  final Posicao? posicaoMain;
  final Posicao? posicaoUsual;
  final TimeRacha? time;
  final StatusConfirmacao statusConfirmacao;

  /// O que aconteceu no dia, registrado na chamada por quem tem permissão
  /// (admin ou anotador). Nulo enquanto a chamada não é feita — e nulo numa
  /// rodada já finalizada significa que ninguém fez a chamada, não que a
  /// pessoa faltou.
  final PresencaFinal? presenca;

  const ParticipanteModel({
    required this.id,
    required this.rachaId,
    required this.userId,
    this.posicaoMain,
    this.posicaoUsual,
    this.time,
    this.statusConfirmacao = StatusConfirmacao.pendente,
    this.presenca,
  });

  /// Único critério usado pelo algoritmo de balanceamento para elegibilidade.
  bool get confirmado => statusConfirmacao == StatusConfirmacao.confirmado;

  /// Versátil = main e usual divergem. Usado no Estágio 1 do algoritmo para
  /// alocar primeiro quem tem uma única opção de posição.
  bool get isVersatil =>
      posicaoMain != null && posicaoUsual != null && posicaoMain != posicaoUsual;

  factory ParticipanteModel.fromMap(String id, Map<String, dynamic> map) {
    return ParticipanteModel(
      id: id,
      rachaId: map['rachaId'] as String,
      userId: map['userId'] as String,
      posicaoMain: map['posicaoMain'] != null
          ? Posicao.values.byName(map['posicaoMain'] as String)
          : null,
      posicaoUsual: map['posicaoUsual'] != null
          ? Posicao.values.byName(map['posicaoUsual'] as String)
          : null,
      time: map['time'] != null ? TimeRacha.values.byName(map['time'] as String) : null,
      statusConfirmacao:
          StatusConfirmacao.values.byName(map['statusConfirmacao'] as String),
      presenca: map['presenca'] != null
          ? PresencaFinal.values.byName(map['presenca'] as String)
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'rachaId': rachaId,
      'userId': userId,
      'posicaoMain': posicaoMain?.name,
      'posicaoUsual': posicaoUsual?.name,
      'time': time?.name,
      'statusConfirmacao': statusConfirmacao.name,
      'presenca': presenca?.name,
    };
  }

  ParticipanteModel copyWith({
    Posicao? posicaoMain,
    Posicao? posicaoUsual,
    TimeRacha? time,
    StatusConfirmacao? statusConfirmacao,
  }) {
    return ParticipanteModel(
      id: id,
      rachaId: rachaId,
      userId: userId,
      posicaoMain: posicaoMain ?? this.posicaoMain,
      posicaoUsual: posicaoUsual ?? this.posicaoUsual,
      time: time ?? this.time,
      statusConfirmacao: statusConfirmacao ?? this.statusConfirmacao,
    );
  }
}
