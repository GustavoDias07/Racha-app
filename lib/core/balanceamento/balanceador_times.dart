import 'jogador_elegivel.dart';

/// Dois times já montados pelo algoritmo — quem chamou decide como
/// persistir (`TimesController`), esta classe não sabe nada de Firestore.
class ResultadoBalanceamento {
  const ResultadoBalanceamento({required this.timeA, required this.timeB});

  final List<JogadorElegivel> timeA;
  final List<JogadorElegivel> timeB;
}

/// Algoritmo de balanceamento de times — ver docs/estrutura.md, seção
/// "Estágio 1 — Preencher posições" e "Estágio 2 — Balancear por nota".
///
/// Vagas de linha são livres (decisão já tomada no documento): o único
/// requisito de posição é o goleiro fixo (no máximo 1 por time); o resto da
/// linha é distribuído sem sub-cota fixa por posição (zagueiro/meia/atacante).
class BalanceadorTimes {
  const BalanceadorTimes();

  ResultadoBalanceamento gerar(List<JogadorElegivel> elegiveis) {
    final timeA = <JogadorElegivel>[];
    final timeB = <JogadorElegivel>[];

    final goleiros = elegiveis.where((j) => j.isGoleiro).toList()
      ..sort(_porNotaEEmpate);
    final linha = elegiveis.where((j) => !j.isGoleiro).toList();

    // Goleiro fixo: no máximo 1 por time, o melhor avaliado primeiro.
    // Goleiros excedentes (3º em diante) entram como linha normal — melhor
    // aproveitá-los do que deixá-los de fora do balanceamento.
    if (goleiros.isNotEmpty) timeA.add(goleiros.first);
    if (goleiros.length > 1) timeB.add(goleiros[1]);
    final linhaCompleta = [...linha, ...goleiros.skip(2)];

    // Estágio 1: menos flexíveis primeiro (só jogam numa posição), os
    // versáteis (main != usual) preenchem o que sobrar.
    final naoVersateis = linhaCompleta.where((j) => !j.isVersatil).toList()
      ..sort(_porNotaEEmpate);
    final versateis = linhaCompleta.where((j) => j.isVersatil).toList()
      ..sort(_porNotaEEmpate);

    // Estágio 2: dentro de cada grupo (na ordem do Estágio 1), aloca cada
    // jogador no time mais fraco/menor, buscando tamanhos e médias de nota
    // parecidos nos dois lados.
    for (final jogador in [...naoVersateis, ...versateis]) {
      _alocar(timeA, timeB, jogador);
    }

    return ResultadoBalanceamento(timeA: timeA, timeB: timeB);
  }

  /// Nota é o critério principal. Enquanto não existir histórico real de
  /// avaliação (todo mundo entra com `notaNeutra`, ver
  /// core/constants/balanceamento_constants.dart), a nota empata pra
  /// todo mundo e o peso vira o critério que efetivamente distingue os
  /// jogadores — evitando que os times sejam montados só por ordem de
  /// chegada na lista.
  int _porNotaEEmpate(JogadorElegivel a, JogadorElegivel b) {
    final porNota = b.nota.compareTo(a.nota);
    if (porNota != 0) return porNota;
    return b.peso.compareTo(a.peso);
  }

  void _alocar(
    List<JogadorElegivel> timeA,
    List<JogadorElegivel> timeB,
    JogadorElegivel jogador,
  ) {
    if (timeA.length != timeB.length) {
      (timeA.length < timeB.length ? timeA : timeB).add(jogador);
      return;
    }
    final notaA = timeA.fold<double>(0, (soma, j) => soma + j.nota);
    final notaB = timeB.fold<double>(0, (soma, j) => soma + j.nota);
    (notaA <= notaB ? timeA : timeB).add(jogador);
  }
}
