import '../../models/enums.dart';
import 'jogador_elegivel.dart';

/// Setor do campo em que o jogador atua. O algoritmo de balanceamento não
/// raciocina em cima da posição exata (zagueiro x lateral são intercambiáveis
/// num racha), e sim em cima destes três blocos — é o nível de detalhe que
/// realmente muda o jogo quando um deles fica vazio.
enum SetorCampo { defesa, meio, ataque }

extension SetorCampoX on SetorCampo {
  String get label => switch (this) {
        SetorCampo.defesa => 'Defesa',
        SetorCampo.meio => 'Meio',
        SetorCampo.ataque => 'Ataque',
      };
}

/// Setor de uma posição de linha. Goleiro e posição não informada devolvem
/// nulo — goleiro tem tratamento próprio no balanceador (é a única vaga
/// realmente obrigatória).
SetorCampo? setorDe(Posicao? posicao) => switch (posicao) {
      Posicao.zagueiro || Posicao.lateral => SetorCampo.defesa,
      Posicao.volante || Posicao.meia => SetorCampo.meio,
      Posicao.atacante => SetorCampo.ataque,
      Posicao.goleiro => null,
      null => null,
    };

/// Setor em que o jogador entra na conta: a posição **main** manda. A usual
/// só responde quando a main não diz nada sobre a linha — jogador que não
/// escolheu posição, ou goleiro excedente (o terceiro em diante, que vira
/// jogador de linha porque só há duas vagas de goleiro).
SetorCampo? setorDoJogador(JogadorElegivel jogador) =>
    setorDe(jogador.posicaoMain) ?? setorDe(jogador.posicaoUsual);

/// Quantos jogadores de linha um time deveria ter em cada setor, dada a
/// formação do racha. Não é uma regra rígida — é o alvo que o algoritmo usa
/// pra saber quando um setor está em falta e precisa ser reforçado por quem
/// joga ali como segunda posição.
///
/// Os valores até 10 são as formações clássicas correspondentes (10 de linha
/// = 4-4-2, 6 = 2-2-2, 4 = 2-1-1). Acima disso cai numa proporção
/// aproximada, já que não existe formação consagrada.
Map<SetorCampo, int> distribuicaoIdeal(int qtdJogadoresLinha) {
  const tabela = <int, (int, int, int)>{
    1: (0, 1, 0),
    2: (1, 1, 0),
    3: (1, 1, 1),
    4: (2, 1, 1),
    5: (2, 2, 1),
    6: (2, 2, 2),
    7: (3, 2, 2),
    8: (3, 3, 2),
    9: (3, 4, 2),
    10: (4, 4, 2),
  };

  if (qtdJogadoresLinha <= 0) {
    return {for (final setor in SetorCampo.values) setor: 0};
  }

  final (defesa, meio, ataque) = tabela[qtdJogadoresLinha] ??
      _proporcional(qtdJogadoresLinha);

  return {
    SetorCampo.defesa: defesa,
    SetorCampo.meio: meio,
    SetorCampo.ataque: ataque,
  };
}

(int, int, int) _proporcional(int qtd) {
  final defesa = (qtd * 0.4).round();
  final ataque = (qtd * 0.25).round();
  final meio = qtd - defesa - ataque;
  return (defesa, meio < 0 ? 0 : meio, ataque);
}

/// Jogadores de linha já separados por setor, prontos pro balanceador
/// distribuir entre os dois times.
class EscalacaoPorSetor {
  const EscalacaoPorSetor({required this.porSetor, required this.semSetor});

  final Map<SetorCampo, List<JogadorElegivel>> porSetor;

  /// Quem não declarou nenhuma posição de linha (nem main, nem usual) e
  /// sobrou depois de tapar os buracos — entra em qualquer lugar.
  final List<JogadorElegivel> semSetor;
}

/// Encaixa cada jogador de linha no setor da sua posição main e, só onde
/// faltar gente, puxa reforço.
///
/// A ordem importa e é o coração da regra: primeiro entra quem não declarou
/// posição nenhuma (não tira ninguém do lugar), e só depois se mexe em quem
/// já está alocado — e mesmo aí, apenas em jogadores cuja posição **usual**
/// é justamente a do setor em falta, tirados de um setor que está sobrando.
/// Assim um racha com dez atacantes e nenhum meia não entra em campo sem
/// meio: os atacantes que também jogam de meia descem, e os que só jogam na
/// frente ficam onde estão.
///
/// Entre os candidatos a serem remanejados, sai o de menor nota — os
/// melhores continuam jogando na posição em que são melhores.
EscalacaoPorSetor distribuirPorSetor(
  List<JogadorElegivel> linha, {
  required int qtdJogadoresLinha,
}) {
  final porSetor = <SetorCampo, List<JogadorElegivel>>{
    for (final setor in SetorCampo.values) setor: <JogadorElegivel>[],
  };
  final semSetor = <JogadorElegivel>[];

  for (final jogador in linha) {
    final setor = setorDoJogador(jogador);
    if (setor == null) {
      semSetor.add(jogador);
    } else {
      porSetor[setor]!.add(jogador);
    }
  }

  // O alvo é para os dois times somados: o balanceador divide depois.
  final alvo = {
    for (final entrada in distribuicaoIdeal(qtdJogadoresLinha).entries)
      entrada.key: entrada.value * 2,
  };

  int falta(SetorCampo setor) => alvo[setor]! - porSetor[setor]!.length;
  bool sobra(SetorCampo setor) => porSetor[setor]!.length > alvo[setor]!;

  final setoresEmFalta = SetorCampo.values.toList()
    ..sort((a, b) => falta(b).compareTo(falta(a)));

  for (final setor in setoresEmFalta) {
    while (falta(setor) > 0 && semSetor.isNotEmpty) {
      porSetor[setor]!.add(semSetor.removeLast());
    }
  }

  for (final setor in setoresEmFalta) {
    while (falta(setor) > 0) {
      JogadorElegivel? reforco;
      SetorCampo? origem;

      for (final outro in SetorCampo.values) {
        if (outro == setor || !sobra(outro)) continue;
        for (final candidato in porSetor[outro]!) {
          if (setorDe(candidato.posicaoUsual) != setor) continue;
          if (reforco == null || candidato.nota < reforco.nota) {
            reforco = candidato;
            origem = outro;
          }
        }
      }

      // Ninguém cobre esse setor como segunda posição: o racha vai entrar em
      // campo desfalcado ali mesmo, e forçar alguém a jogar fora das duas
      // posições dele seria pior do que isso.
      if (reforco == null) break;

      porSetor[origem]!.remove(reforco);
      porSetor[setor]!.add(reforco);
    }
  }

  return EscalacaoPorSetor(porSetor: porSetor, semSetor: semSetor);
}
