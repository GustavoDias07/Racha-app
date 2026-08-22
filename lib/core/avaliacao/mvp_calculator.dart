import '../../models/avaliacao_model.dart';
import '../../models/enums.dart';

/// Resultado do cálculo de MVP de um racha: quem venceu e com que média.
class MvpResultado {
  const MvpResultado({
    required this.avaliadoId,
    required this.mediaNota,
    required this.totalAvaliacoes,
  });

  final String avaliadoId;
  final double mediaNota;
  final int totalAvaliacoes;
}

/// Calcula o MVP de um racha a partir das avaliações recebidas: quem tiver
/// a maior média de nota vence; empate é resolvido por quem recebeu mais
/// avaliações, e o último critério é o id (só pra ser determinístico).
///
/// Só considera avaliados do tipo User — Convidados não têm um documento de
/// Ranking persistente pra receber o crédito de MVP (ver docs/estrutura.md,
/// Fluxo 3.1: isso só passa a fazer sentido quando o convidado oficializa
/// a conta).
///
/// Retorna null se não houver nenhuma avaliação (ou nenhuma pra um User)
/// de onde tirar um MVP.
MvpResultado? calcularMvpDoRacha(List<AvaliacaoModel> avaliacoes) {
  final porAvaliado = <String, List<AvaliacaoModel>>{};
  for (final avaliacao in avaliacoes) {
    if (avaliacao.avaliadoTipo != TipoJogador.user) continue;
    porAvaliado.putIfAbsent(avaliacao.avaliadoId, () => []).add(avaliacao);
  }
  if (porAvaliado.isEmpty) return null;

  MvpResultado? melhor;
  for (final entry in porAvaliado.entries) {
    final notas = entry.value.map((a) => a.nota);
    final media = notas.reduce((a, b) => a + b) / notas.length;
    final candidato = MvpResultado(
      avaliadoId: entry.key,
      mediaNota: media,
      totalAvaliacoes: entry.value.length,
    );

    if (melhor == null || _melhorQue(candidato, melhor)) {
      melhor = candidato;
    }
  }
  return melhor;
}

bool _melhorQue(MvpResultado a, MvpResultado b) {
  if (a.mediaNota != b.mediaNota) return a.mediaNota > b.mediaNota;
  if (a.totalAvaliacoes != b.totalAvaliacoes) return a.totalAvaliacoes > b.totalAvaliacoes;
  return a.avaliadoId.compareTo(b.avaliadoId) < 0;
}
