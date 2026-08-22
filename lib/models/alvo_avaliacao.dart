import 'enums.dart';

/// Um jogador que o usuário logado precisa avaliar: companheiro de time ou
/// candidato a adversário. Não é uma entidade persistida — só carrega o
/// necessário pra tela de Avaliação Pós-Jogo montar o formulário e, no
/// fim, gravar o `AvaliacaoModel` correspondente (id vira `avaliadoId`).
class AlvoAvaliacao {
  const AlvoAvaliacao({
    required this.id,
    required this.tipo,
    this.nome,
  });

  /// Id "de identidade" do avaliado: o userId real (Firebase Auth) quando
  /// `tipo == TipoJogador.user`, ou o id do documento Convidado quando
  /// `tipo == TipoJogador.convidado`.
  ///
  /// Importante: NUNCA o id do documento `Participante` — esse muda a cada
  /// racha que o User participa, então usá-lo como `avaliadoId` quebraria a
  /// consulta que soma "todas as avaliações que esse User já recebeu"
  /// (`AvaliacaoRepository.buscarRecebidasPor`, `RankingController`).
  final String id;
  final TipoJogador tipo;

  /// Preenchido só quando `tipo == TipoJogador.convidado` (nome já vem
  /// pronto no documento). Pra User, o nome é buscado via
  /// `userPorIdProvider(id)`, já que `id` é o userId real.
  final String? nome;
}

/// O que a tela de Avaliação Pós-Jogo precisa saber sobre o usuário logado
/// pra montar o formulário, ou pra explicar por que ele ainda não pode
/// avaliar (times não gerados, ou já avaliou essa rodada).
class ContextoAvaliacao {
  const ContextoAvaliacao({
    required this.jaAvaliou,
    required this.meuTime,
    required this.companheiros,
    required this.adversarios,
  });

  final bool jaAvaliou;
  final TimeRacha? meuTime;
  final List<AlvoAvaliacao> companheiros;
  final List<AlvoAvaliacao> adversarios;
}
