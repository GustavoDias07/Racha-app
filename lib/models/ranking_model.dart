/// Estatísticas acumuladas de um User, recalculadas após cada racha
/// finalizado. Documento único por usuário (id do doc == userId).
class RankingModel {
  final String userId;
  final double mediaAvaliacoes;
  final int totalMvps;
  final int totalGols;
  final int totalAssistencias;
  final int totalRachas;

  const RankingModel({
    required this.userId,
    this.mediaAvaliacoes = 0,
    this.totalMvps = 0,
    this.totalGols = 0,
    this.totalAssistencias = 0,
    this.totalRachas = 0,
  });

  factory RankingModel.fromMap(String userId, Map<String, dynamic> map) {
    return RankingModel(
      userId: userId,
      mediaAvaliacoes: (map['mediaAvaliacoes'] as num?)?.toDouble() ?? 0,
      totalMvps: map['totalMvps'] as int? ?? 0,
      totalGols: map['totalGols'] as int? ?? 0,
      totalAssistencias: map['totalAssistencias'] as int? ?? 0,
      totalRachas: map['totalRachas'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'mediaAvaliacoes': mediaAvaliacoes,
      'totalMvps': totalMvps,
      'totalGols': totalGols,
      'totalAssistencias': totalAssistencias,
      'totalRachas': totalRachas,
    };
  }

  RankingModel copyWith({
    double? mediaAvaliacoes,
    int? totalMvps,
    int? totalGols,
    int? totalAssistencias,
    int? totalRachas,
  }) {
    return RankingModel(
      userId: userId,
      mediaAvaliacoes: mediaAvaliacoes ?? this.mediaAvaliacoes,
      totalMvps: totalMvps ?? this.totalMvps,
      totalGols: totalGols ?? this.totalGols,
      totalAssistencias: totalAssistencias ?? this.totalAssistencias,
      totalRachas: totalRachas ?? this.totalRachas,
    );
  }
}
