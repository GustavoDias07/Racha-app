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

  /// Grupo a que a rodada pertence, copiado do racha na hora de gravar
  /// (nulo em racha avulso). Guardar aqui é o que permite o ranking do
  /// grupo puxar todas as avaliações numa consulta só, em vez de percorrer
  /// rodada por rodada — ver `rankingDoGrupoProvider`.
  final String? grupoId;

  const AvaliacaoModel({
    required this.id,
    required this.rachaId,
    required this.avaliadorId,
    required this.avaliadoId,
    required this.avaliadoTipo,
    required this.nota,
    this.grupoId,
  });

  factory AvaliacaoModel.fromMap(String id, Map<String, dynamic> map) {
    return AvaliacaoModel(
      id: id,
      rachaId: map['rachaId'] as String,
      avaliadorId: map['avaliadorId'] as String,
      avaliadoId: map['avaliadoId'] as String,
      avaliadoTipo: TipoJogador.values.byName(map['avaliadoTipo'] as String),
      nota: (map['nota'] as num).toDouble(),
      grupoId: map['grupoId'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'rachaId': rachaId,
      'avaliadorId': avaliadorId,
      'avaliadoId': avaliadoId,
      'avaliadoTipo': avaliadoTipo.name,
      'nota': nota,
      'grupoId': grupoId,
    };
  }
}
