import '../constants/balanceamento_constants.dart';
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
/// 3. **Força** — os dois times terminam o mais parecidos possível em quatro
///    critérios ao mesmo tempo: nota média, gols por rodada, idade e peso
///    (os pesos de cada um estão em `balanceamento_constants.dart`). A
///    distribuição inicial já espalha os melhores pela nota, e um ajuste
///    final troca jogadores de mesmo setor entre os lados enquanto isso
///    aproximar os times — como a troca é sempre dentro do mesmo setor, as
///    duas primeiras garantias continuam de pé.
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

    _aproximarTimes(
      timeA,
      timeB,
      _gruposDe(timeA, timeB),
      _golsEfetivos([...timeA, ...timeB]),
    );

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

  /// Gols por rodada de cada jogador, com o desconhecido preenchido pela
  /// média de quem tem histórico.
  ///
  /// Preencher com zero seria tratar o jogador novo e o convidado como quem
  /// nunca marca, e o algoritmo os empurraria todos para o mesmo lado para
  /// "compensar" o artilheiro do outro. Com a média, o desconhecido fica
  /// neutro. Se ninguém tem histórico, todo mundo fica igual e o critério
  /// simplesmente não pesa.
  Map<String, double> _golsEfetivos(List<JogadorElegivel> todos) {
    final conhecidos = [
      for (final j in todos)
        if (j.golsPorJogo != null) j.golsPorJogo!,
    ];
    final media = conhecidos.isEmpty
        ? 0.0
        : conhecidos.reduce((a, b) => a + b) / conhecidos.length;
    return {for (final j in todos) j.id: j.golsPorJogo ?? media};
  }

  /// Ajuste final: enquanto existir uma troca de jogadores do mesmo bolso que
  /// deixe os times mais parecidos, faz a troca.
  ///
  /// "Parecidos" é o [_desequilibrio] entre os dois lados, que soma as
  /// diferenças de nota, gols, idade e peso, cada uma com o seu peso. Antes
  /// era só a nota: idade e peso chegavam até aqui e nunca eram lidos, e
  /// gols nem chegavam. Bastava uma rodada com os mais novos todos de um lado
  /// para o jogo ficar decidido no fôlego, mesmo com notas idênticas.
  ///
  /// Compara **médias**, não somas: os times podem ter um jogador de
  /// diferença, e nesse caso somas iguais significariam o time menor sendo
  /// bem mais forte por jogador.
  void _aproximarTimes(
    List<JogadorElegivel> timeA,
    List<JogadorElegivel> timeB,
    Map<String, String> grupos,
    Map<String, double> gols,
  ) {
    if (timeA.isEmpty || timeB.isEmpty) return;

    var somaA = _Somas.de(timeA, gols);
    var somaB = _Somas.de(timeB, gols);
    var atual = _desequilibrio(somaA, timeA.length, somaB, timeB.length);

    // Cada iteração aplica a melhor troca disponível. O laço para sozinho
    // quando nenhuma troca melhora — o limite de voltas é só uma trava de
    // segurança contra empates que fiquem alternando entre si.
    for (var volta = 0; volta < timeA.length * timeB.length; volta++) {
      var melhor = atual;
      var melhorA = -1;
      var melhorB = -1;

      for (var i = 0; i < timeA.length; i++) {
        for (var k = 0; k < timeB.length; k++) {
          if (grupos[timeA[i].id] != grupos[timeB[k].id]) continue;

          final delta = _Somas.diferenca(timeB[k], timeA[i], gols);
          final candidata = _desequilibrio(
            somaA + delta,
            timeA.length,
            somaB - delta,
            timeB.length,
          );
          // Margem pequena pra não ficar trocando por diferença de
          // arredondamento de ponto flutuante.
          if (candidata < melhor - 1e-9) {
            melhor = candidata;
            melhorA = i;
            melhorB = k;
          }
        }
      }

      if (melhorA < 0) return;

      final delta = _Somas.diferenca(timeB[melhorB], timeA[melhorA], gols);
      somaA = somaA + delta;
      somaB = somaB - delta;
      final trocado = timeA[melhorA];
      timeA[melhorA] = timeB[melhorB];
      timeB[melhorB] = trocado;
      atual = melhor;
    }
  }

  /// O quanto os dois times estão diferentes, num número só. Zero é
  /// perfeitamente equilibrado.
  ///
  /// Cada critério é dividido pela sua escala antes de entrar na soma —
  /// sem isso 1 kg de diferença valeria o mesmo que 1 ponto inteiro de nota,
  /// e o peso corporal dominaria a conta só por ser medido num número maior.
  double _desequilibrio(_Somas a, int tamA, _Somas b, int tamB) {
    double dif(double somaA, double somaB, double escala) =>
        (somaA / tamA - somaB / tamB).abs() / escala;

    return pesoNota * dif(a.nota, b.nota, escalaNota) +
        pesoGols * dif(a.gols, b.gols, escalaGols) +
        pesoIdade * dif(a.idade, b.idade, escalaIdade) +
        pesoCorporal * dif(a.peso, b.peso, escalaPeso);
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

/// Somatórios de um time nos quatro critérios do balanceamento.
///
/// Guardar somas, em vez de recalcular as médias a cada candidata, é o que
/// deixa avaliar uma troca em tempo constante: trocar dois jogadores só tira
/// a contribuição de um e põe a do outro. Num campo cheio são centenas de
/// candidatas por volta, e recalcular tudo do zero em cada uma pesaria.
class _Somas {
  const _Somas(this.nota, this.gols, this.idade, this.peso);

  final double nota;
  final double gols;
  final double idade;
  final double peso;

  factory _Somas.de(List<JogadorElegivel> time, Map<String, double> gols) {
    var nota = 0.0, golsTotal = 0.0, idade = 0.0, peso = 0.0;
    for (final j in time) {
      nota += j.nota;
      golsTotal += gols[j.id]!;
      idade += j.idade;
      peso += j.peso;
    }
    return _Somas(nota, golsTotal, idade, peso);
  }

  /// O que muda nas somas de um time quando [sai] dá lugar a [entra].
  static _Somas diferenca(
    JogadorElegivel entra,
    JogadorElegivel sai,
    Map<String, double> gols,
  ) {
    return _Somas(
      entra.nota - sai.nota,
      gols[entra.id]! - gols[sai.id]!,
      (entra.idade - sai.idade).toDouble(),
      entra.peso - sai.peso,
    );
  }

  _Somas operator +(_Somas o) =>
      _Somas(nota + o.nota, gols + o.gols, idade + o.idade, peso + o.peso);

  _Somas operator -(_Somas o) =>
      _Somas(nota - o.nota, gols - o.gols, idade - o.idade, peso - o.peso);
}
