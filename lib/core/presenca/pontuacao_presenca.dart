import '../../models/enums.dart';

// Pontuação de presença (RF22 no Trello, T16/T17 em docs/tarefas.md).
//
// Mede só a assiduidade — nunca entra na nota de habilidade nem no
// balanceamento dos times. Serve para decidir quem fica com a vaga quando
// aparece mais gente do que cabe nos dois times.
//
// Lógica pura, sem Firebase: quem grava o histórico é o `RachaController`
// (ao finalizar a rodada) e quem monta o banco é o `TimesController`. Assim
// as regras abaixo dão pra testar sem emulador (test/core/presenca).

/// Pontos por rodada, combinados com o grupo em 26/10/2026.
const int pontosCompareceu = 3;
const int pontosFaltou = -1;
const int pontosNaoVai = 0;

/// Quantas rodadas entram na conta. Só as rodadas para as quais a pessoa foi
/// convidada contam — quem entrou no grupo semana passada não é comparado
/// com quem está lá há um ano.
const int janelaRodadas = 10;

/// Antes de 3 rodadas o número ainda não diz nada sobre a pessoa (uma falta
/// na primeira semana viraria "−1 de média"). Até lá ela é tratada como a
/// média do grupo, nem na frente nem atrás de ninguém.
const int minimoRodadasParaValer = 3;

/// Pontos que um participante ganha numa rodada já encerrada.
///
/// - Confirmou e foi (compareceu ou atrasou): +3. Atrasar não tira ponto —
///   a punição do atraso é perder a vaga só naquela rodada (ver
///   [montarElenco]).
/// - Confirmou e não foi: −1. É o "cano": o grupo contava com a pessoa.
/// - Disse que não vai, ou nem respondeu: 0. Avisar com antecedência é
///   neutro, nunca negativo.
///
/// Devolve `null` quando a rodada não teve chamada para essa pessoa
/// (presença nula): sem chamada não dá pra saber se ela foi, e a rodada
/// simplesmente não entra no histórico dela.
int? pontosDaRodada({
  required StatusConfirmacao confirmacao,
  required PresencaFinal? presenca,
}) {
  if (confirmacao != StatusConfirmacao.confirmado) return pontosNaoVai;
  if (presenca == null) return null;
  return presenca == PresencaFinal.faltou ? pontosFaltou : pontosCompareceu;
}

/// Acrescenta os pontos de uma rodada ao histórico, mantendo só as últimas
/// [janelaRodadas] (a mais recente fica no fim da lista).
List<int> acrescentarAoHistorico(List<int> historico, int pontos) {
  final novo = [...historico, pontos];
  return novo.length <= janelaRodadas
      ? novo
      : novo.sublist(novo.length - janelaRodadas);
}

/// Resumo da pontuação de um jogador num grupo.
class PontuacaoPresenca {
  const PontuacaoPresenca(this.historico);

  /// Pontos das últimas rodadas, a mais recente no fim.
  final List<int> historico;

  /// Soma dos pontos — é o número da tabela e o que decide o banco.
  ///
  /// Soma, e não média, de propósito: com a média, dizer "não vou" (0)
  /// derrubaria a pontuação de quem costuma ir (+3), e avisar com
  /// antecedência viraria castigo. Na soma o 0 só não acrescenta nada, que
  /// foi exatamente a regra combinada.
  int get total => historico.fold(0, (soma, p) => soma + p);
  int get rodadas => historico.length;

  /// Já tem rodadas suficientes para a pontuação valer.
  bool get valida => rodadas >= minimoRodadasParaValer;
}

/// Alguém disputando vaga numa rodada: um User confirmado ou um Convidado
/// aprovado.
class CandidatoVaga {
  const CandidatoVaga({
    required this.id,
    this.pontuacao,
    this.atrasou = false,
    this.confirmadoEm,
  });

  /// Id do Participante ou do Convidado.
  final String id;

  /// Nulo para convidado e para quem ainda não tem pontuação no grupo.
  final PontuacaoPresenca? pontuacao;

  /// Marcado "atrasou" na chamada desta rodada.
  final bool atrasou;

  /// Quando confirmou presença. Nulo para documentos antigos, criados antes
  /// de esse campo existir — esses contam como os primeiros a confirmar.
  final DateTime? confirmadoEm;
}

/// Resultado da divisão entre quem joga e quem espera.
class ElencoDaRodada {
  const ElencoDaRodada({required this.titulares, required this.banco});

  final List<CandidatoVaga> titulares;

  /// Em ordem: o primeiro da lista é o primeiro a entrar se abrir vaga.
  final List<CandidatoVaga> banco;
}

/// Separa quem joga de quem fica no banco quando há mais confirmados do que
/// [vagas] (os dois times completos).
///
/// Ordem de prioridade:
/// 1. Quem **não** atrasou nesta rodada vem antes de quem atrasou. Só vale
///    para esta rodada: na próxima, quem atrasou volta a ser ordenado pela
///    pontuação normalmente.
/// 2. Maior pontuação de presença (soma das últimas rodadas).
/// 3. Empate: quem confirmou primeiro.
///
/// Quem ainda não tem pontuação válida (convidado, jogador novo) entra com
/// a média das pontuações de quem já tem — nem na frente nem atrás.
ElencoDaRodada montarElenco(List<CandidatoVaga> candidatos, {required int vagas}) {
  if (candidatos.length <= vagas) {
    return ElencoDaRodada(titulares: [...candidatos], banco: const []);
  }

  final validas = [
    for (final c in candidatos)
      if (c.pontuacao != null && c.pontuacao!.valida) c.pontuacao!.total,
  ];
  final mediaDoGrupo =
      validas.isEmpty ? 0.0 : validas.reduce((a, b) => a + b) / validas.length;

  double pontosDe(CandidatoVaga c) => (c.pontuacao != null && c.pontuacao!.valida)
      ? c.pontuacao!.total.toDouble()
      : mediaDoGrupo;

  final ordenados = [...candidatos]..sort((a, b) {
      if (a.atrasou != b.atrasou) return a.atrasou ? 1 : -1;
      final porPontos = pontosDe(b).compareTo(pontosDe(a));
      if (porPontos != 0) return porPontos;
      final ta = a.confirmadoEm, tb = b.confirmadoEm;
      if (ta == null && tb == null) return 0;
      if (ta == null) return -1;
      if (tb == null) return 1;
      return ta.compareTo(tb);
    });

  return ElencoDaRodada(
    titulares: ordenados.sublist(0, vagas),
    banco: ordenados.sublist(vagas),
  );
}
