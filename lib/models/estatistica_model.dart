import 'enums.dart';

/// Estatísticas de um jogador (User ou Convidado) em um Racha.
///
/// "Cartões" foi desmembrado em amarelos/vermelhos: mesma informação do
/// enunciado original, só que já separada por tipo em vez de um contador
/// genérico, o que é o mínimo necessário para exibir isso de forma útil
/// no perfil/estatísticas.
class EstatisticaModel {
  final String id;
  final String rachaId;
  final String jogadorId;
  final TipoJogador jogadorTipo;
  final int gols;
  final int assistencias;
  final int cartoesAmarelos;
  final int cartoesVermelhos;

  const EstatisticaModel({
    required this.id,
    required this.rachaId,
    required this.jogadorId,
    required this.jogadorTipo,
    this.gols = 0,
    this.assistencias = 0,
    this.cartoesAmarelos = 0,
    this.cartoesVermelhos = 0,
  });

  factory EstatisticaModel.fromMap(String id, Map<String, dynamic> map) {
    return EstatisticaModel(
      id: id,
      rachaId: map['rachaId'] as String,
      jogadorId: map['jogadorId'] as String,
      jogadorTipo: TipoJogador.values.byName(map['jogadorTipo'] as String),
      gols: map['gols'] as int? ?? 0,
      assistencias: map['assistencias'] as int? ?? 0,
      cartoesAmarelos: map['cartoesAmarelos'] as int? ?? 0,
      cartoesVermelhos: map['cartoesVermelhos'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'rachaId': rachaId,
      'jogadorId': jogadorId,
      'jogadorTipo': jogadorTipo.name,
      'gols': gols,
      'assistencias': assistencias,
      'cartoesAmarelos': cartoesAmarelos,
      'cartoesVermelhos': cartoesVermelhos,
    };
  }

  EstatisticaModel copyWith({
    int? gols,
    int? assistencias,
    int? cartoesAmarelos,
    int? cartoesVermelhos,
  }) {
    return EstatisticaModel(
      id: id,
      rachaId: rachaId,
      jogadorId: jogadorId,
      jogadorTipo: jogadorTipo,
      gols: gols ?? this.gols,
      assistencias: assistencias ?? this.assistencias,
      cartoesAmarelos: cartoesAmarelos ?? this.cartoesAmarelos,
      cartoesVermelhos: cartoesVermelhos ?? this.cartoesVermelhos,
    );
  }
}
