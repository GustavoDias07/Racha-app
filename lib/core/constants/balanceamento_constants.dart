/// Nota neutra usada como avaliação de todo jogador elegível, já que o
/// sistema de Avaliação/Ranking (docs/estrutura.md) ainda não existe — sem
/// isso não há `Ranking.mediaAvaliacoes` real pra alimentar o Estágio 2 do
/// algoritmo de balanceamento. Numa escala de 1 a 5, fica no meio.
///
/// Provisório: quando Avaliação/Ranking forem implementados, o
/// `TimesController` passa a buscar a média real de cada jogador em vez
/// deste valor fixo — o `BalanceadorTimes` não muda, ele só recebe a nota
/// já pronta em `JogadorElegivel.nota`.
const double notaNeutra = 3.0;
