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
    this.golsPorJogo,
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

  /// Média de gols por rodada, ou `null` para quem não tem histórico —
  /// convidado, ou jogador que ainda não teve rodada avaliada.
  ///
  /// `null` é diferente de zero: zero é "joga e não marca", `null` é "não
  /// sabemos". O balanceador trata o desconhecido como a média do grupo, para
  /// que ele não puxe para nenhum lado.
  final double? golsPorJogo;

  bool get isGoleiro => posicaoMain == Posicao.goleiro;

  /// Versátil = joga em mais de uma posição (main != usual). No Estágio 1
  /// do algoritmo, entra por último — sobra pra quem se adapta mais fácil.
  bool get isVersatil =>
      posicaoMain != null && posicaoUsual != null && posicaoMain != posicaoUsual;
}
