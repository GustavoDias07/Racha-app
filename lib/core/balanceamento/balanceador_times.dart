import 'jogador_elegivel.dart';
import 'setores.dart';

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
/// Três garantias, nesta ordem de prioridade:
///
/// 1. **Goleiro** — no máximo um por time, o melhor avaliado primeiro. Do
///    terceiro em diante, goleiro vira jogador de linha (melhor aproveitar do
///    que deixar de fora).
/// 2. **Setor** — cada jogador entra pelo setor da sua posição main, e os
///    dois times ficam com a mesma quantidade de defensores, meias e
///    atacantes (diferença de no máximo um em cada setor). Quando um setor
///    fica em falta, a posição usual de quem está sobrando em outro setor é
///    usada como reforço — ver `distribuirPorSetor`.
/// 3. **Nota** — os dois times terminam com médias de avaliação o mais
///    próximas possível. A distribuição inicial já espalha os melhores, e um
///    ajuste final troca jogadores de mesmo setor entre os lados enquanto
///    isso aproximar as médias — como a troca é sempre dentro do mesmo setor,
///    as duas primeiras garantias continuam de pé.
class BalanceadorTimes {
  const BalanceadorTimes();

  ResultadoBalanceamento gerar(
    List<JogadorElegivel> elegiveis, {
    required int qtdJogadoresLinha,
  }) {
    final timeA = <JogadorElegivel>[];
    final timeB = <JogadorElegivel>[];

    final goleiros = elegiveis.where((j) => j.isGoleiro).toList()
      ..sort(_porNotaEEmpate);
    if (goleiros.isNotEmpty) timeA.add(goleiros.first);
    if (goleiros.length > 1) timeB.add(goleiros[1]);

    final linha = [
      ...elegiveis.where((j) => !j.isGoleiro),
      ...goleiros.skip(2),
    ];

    final escalacao =
        distribuirPorSetor(linha, qtdJogadoresLinha: qtdJogadoresLinha);

    // Contadores por setor de cada time: sem isso não dá pra saber quantos
    // meias o time A já tem, porque um jogador remanejado pela posição usual
    // continua com a main dele gravada (um atacante que desceu pro meio
    // ainda é `posicaoMain: atacante`).
    final noSetorA = <SetorCampo, int>{};
    final noSetorB = <SetorCampo, int>{};

    for (final setor in SetorCampo.values) {
      final doSetor = escalacao.porSetor[setor]!..sort(_porNotaEEmpate);
      for (final jogador in doSetor) {
        final destino = _escolherTime(
          timeA,
          timeB,
          noSetorA[setor] ?? 0,
          noSetorB[setor] ?? 0,
        );
        destino.add(jogador);
        if (identical(destino, timeA)) {
          noSetorA[setor] = (noSetorA[setor] ?? 0) + 1;
        } else {
          noSetorB[setor] = (noSetorB[setor] ?? 0) + 1;
        }
      }
    }

    // Quem não declarou posição nenhuma e não foi usado pra tapar buraco:
    // entra onde fizer o time ficar mais equilibrado.
    final semSetor = escalacao.semSetor..sort(_porNotaEEmpate);
    for (final jogador in semSetor) {
      _escolherTime(timeA, timeB, 0, 0).add(jogador);
    }

    _aproximarMedias(timeA, timeB, _gruposDe(timeA, timeB));

    return ResultadoBalanceamento(timeA: timeA, timeB: timeB);
  }

  /// Rótulo do "bolso" em que cada jogador foi escalado. Só faz sentido
  /// trocar jogadores do mesmo bolso: goleiro por goleiro, meia por meia.
  /// Trocar um zagueiro por um atacante desmontaria os setores que o passo
  /// anterior acabou de equilibrar.
  ///
  /// É calculado a partir do resultado (e não durante a alocação) porque um
  /// jogador remanejado pela posição usual continua com a main dele gravada
  /// — `setorDoJogador` resolve isso do mesmo jeito nos dois lugares.
  Map<String, String> _gruposDe(
    List<JogadorElegivel> timeA,
    List<JogadorElegivel> timeB,
  ) {
    return {
      for (final jogador in [...timeA, ...timeB])
        jogador.id: jogador.isGoleiro
            ? 'goleiro'
            : (setorDoJogador(jogador)?.name ?? 'livre'),
    };
  }

  /// Ajuste final: enquanto existir uma troca de jogadores do mesmo bolso que
  /// aproxime as médias dos dois times, faz a troca. Sem isso a nota ficava
  /// em último lugar na fila de critérios — bastava um setor com número ímpar
  /// de jogadores e notas desiguais pra um time sair claramente mais forte,
  /// mesmo com setores e tamanhos perfeitos.
  ///
  /// Compara **médias**, não somas: os times podem ter um jogador de
  /// diferença, e nesse caso somas iguais significariam o time menor sendo
  /// bem mais forte por jogador.
  void _aproximarMedias(
    List<JogadorElegivel> timeA,
    List<JogadorElegivel> timeB,
    Map<String, String> grupos,
  ) {
    if (timeA.isEmpty || timeB.isEmpty) return;

    var distanciaAtual = _distanciaDeMedias(timeA, timeB);

    // Cada iteração aplica a melhor troca disponível. O laço para sozinho
    // quando nenhuma troca melhora — o limite de voltas é só uma trava de
    // segurança contra empates que fiquem alternando entre si.
    for (var volta = 0; volta < timeA.length * timeB.length; volta++) {
      var melhorDistancia = distanciaAtual;
      var melhorA = -1;
      var melhorB = -1;

      for (var i = 0; i < timeA.length; i++) {
        for (var k = 0; k < timeB.length; k++) {
          if (grupos[timeA[i].id] != grupos[timeB[k].id]) continue;
          if (timeA[i].nota == timeB[k].nota) continue;

          final candidata = _distanciaSeTrocar(timeA, timeB, i, k);
          // Margem pequena pra não ficar trocando por diferença de
          // arredondamento de ponto flutuante.
          if (candidata < melhorDistancia - 1e-9) {
            melhorDistancia = candidata;
            melhorA = i;
            melhorB = k;
          }
        }
      }

      if (melhorA < 0) return;

      final trocado = timeA[melhorA];
      timeA[melhorA] = timeB[melhorB];
      timeB[melhorB] = trocado;
      distanciaAtual = melhorDistancia;
    }
  }

  double _distanciaDeMedias(
    List<JogadorElegivel> timeA,
    List<JogadorElegivel> timeB,
  ) {
    return (_somaNota(timeA) / timeA.length - _somaNota(timeB) / timeB.length)
        .abs();
  }

  double _distanciaSeTrocar(
    List<JogadorElegivel> timeA,
    List<JogadorElegivel> timeB,
    int i,
    int k,
  ) {
    final delta = timeB[k].nota - timeA[i].nota;
    final mediaA = (_somaNota(timeA) + delta) / timeA.length;
    final mediaB = (_somaNota(timeB) - delta) / timeB.length;
    return (mediaA - mediaB).abs();
  }

  /// Nota é o critério de desempate final. Empate de nota (jogador novo, ou
  /// convidado, que entra com a nota neutra) cai no peso — evita que os
  /// times sejam montados por ordem de chegada na lista.
  int _porNotaEEmpate(JogadorElegivel a, JogadorElegivel b) {
    final porNota = b.nota.compareTo(a.nota);
    if (porNota != 0) return porNota;
    return b.peso.compareTo(a.peso);
  }

  /// Decide o lado do próximo jogador: primeiro quem tem menos gente naquele
  /// setor, depois quem tem menos jogadores no total, e só então quem soma
  /// menos nota. Nessa ordem os três objetivos convivem — o setor nunca
  /// desequilibra em mais de um jogador, o tamanho dos times também não, e a
  /// nota decide todo o resto.
  List<JogadorElegivel> _escolherTime(
    List<JogadorElegivel> timeA,
    List<JogadorElegivel> timeB,
    int noSetorA,
    int noSetorB,
  ) {
    if (noSetorA != noSetorB) return noSetorA < noSetorB ? timeA : timeB;
    if (timeA.length != timeB.length) {
      return timeA.length < timeB.length ? timeA : timeB;
    }
    return _somaNota(timeA) <= _somaNota(timeB) ? timeA : timeB;
  }

  double _somaNota(List<JogadorElegivel> time) =>
      time.fold<double>(0, (soma, j) => soma + j.nota);
}
