import '../../models/enums.dart';
import '../../models/participante_model.dart';

/// A posição em que o jogador mais aparece escalado.
///
/// Serve para o admin ter uma noção de onde a pessoa joga antes de aprovar um
/// pedido de entrada. Considera só a `posicaoMain` — a secundária existe para
/// cobrir setor em falta no balanceamento e distorceria a leitura aqui.
///
/// Nulo quando o jogador nunca informou posição nenhuma. Empate é resolvido
/// pela ordem do enum, para a resposta ser estável entre duas chamadas em vez
/// de variar conforme a ordem em que o Firestore devolveu os documentos.
({Posicao posicao, int vezes})? posicaoMaisFrequente(
  List<ParticipanteModel> participacoes,
) {
  final contagem = <Posicao, int>{};
  for (final p in participacoes) {
    final posicao = p.posicaoMain;
    if (posicao == null) continue;
    contagem[posicao] = (contagem[posicao] ?? 0) + 1;
  }
  if (contagem.isEmpty) return null;

  var melhor = contagem.entries.first;
  for (final entrada in contagem.entries) {
    final maisVezes = entrada.value > melhor.value;
    final empateComOrdemMenor =
        entrada.value == melhor.value && entrada.key.index < melhor.key.index;
    if (maisVezes || empateComOrdemMenor) melhor = entrada;
  }
  return (posicao: melhor.key, vezes: melhor.value);
}
