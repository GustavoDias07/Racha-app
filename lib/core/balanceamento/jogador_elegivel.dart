import '../../models/enums.dart';

/// "Jogador Elegível" unificado: um User confirmado (via Participante) ou
/// um Convidado aprovado, tratados da mesma forma pelo algoritmo de
/// balanceamento — só a origem do dado muda (docs/estrutura.md, nota da
/// entidade Convidado).
class JogadorElegivel {
  const JogadorElegivel({
    required this.id,
    required this.tipo,
    required this.nome,
    required this.posicaoMain,
    required this.posicaoUsual,
    required this.nota,
    required this.idade,
    required this.peso,
  });

  /// Id do Participante ou do Convidado (não o userId) — é o que o
  /// `TimesController` usa pra saber em qual documento gravar o `time`.
  final String id;
  final TipoJogador tipo;
  final String nome;
  final Posicao? posicaoMain;
  final Posicao? posicaoUsual;
  final double nota;
  final int idade;
  final double peso;

  bool get isGoleiro => posicaoMain == Posicao.goleiro;

  /// Versátil = joga em mais de uma posição (main != usual). No Estágio 1
  /// do algoritmo, entra por último — sobra pra quem se adapta mais fácil.
  bool get isVersatil =>
      posicaoMain != null && posicaoUsual != null && posicaoMain != posicaoUsual;
}
