/// Nota usada no balanceamento quando o jogador ainda não tem histórico de
/// avaliação: quem acabou de entrar no app e todo Convidado (que não é User
/// e, por isso, não tem Ranking). Numa escala de 1 a 5 fica no meio — não
/// beneficia nem prejudica quem é novo.
///
/// Quem já foi avaliado não passa por aqui: entra com a média real
/// (`Ranking.mediaAvaliacoes`), que o `TimesController` busca na hora de
/// gerar os times. Um ranking existente com média zero também cai na nota
/// neutra — zero ali quer dizer "nunca foi avaliado", não "joga mal".
const double notaNeutra = 3.0;
