import 'enums.dart';

/// Nota que um jogador dá a outro após o racha.
/// Regra: cada jogador avalia os companheiros do próprio time + 1 do time
/// adversário.
class AvaliacaoModel {
  final String id;
  final String rachaId;
  final String avaliadorId; // sempre um User
  final String avaliadoId; // User ou Convidado
  final TipoJogador avaliadoTipo;
  final double nota;

  const AvaliacaoModel({
    required this.id,
    required this.rachaId,
    required this.avaliadorId,
    required this.avaliadoId,
    required this.avaliadoTipo,
    required this.nota,
  });

  factory AvaliacaoModel.fromMap(String id, Map<String, dynamic> map) {
    return AvaliacaoModel(
      id: id,
      rachaId: map['rachaId'] as String,
      avaliadorId: map['avaliadorId'] as String,
      avaliadoId: map['avaliadoId'] as String,
      avaliadoTipo: TipoJogador.values.byName(map['avaliadoTipo'] as String),
      nota: (map['nota'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'rachaId': rachaId,
      'avaliadorId': avaliadorId,
      'avaliadoId': avaliadoId,
      'avaliadoTipo': avaliadoTipo.name,
      'nota': nota,
    };
  }
}
