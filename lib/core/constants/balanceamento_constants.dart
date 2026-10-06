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

// ---------------------------------------------------------------------------
// Pesos do balanceamento
// ---------------------------------------------------------------------------
//
// Depois de distribuir goleiro e setores, o algoritmo troca jogadores de
// mesma posição entre os times enquanto isso deixar os dois mais parecidos.
// "Parecidos" é medido por quatro critérios ao mesmo tempo, e cada um entra
// na conta multiplicado por um destes pesos.
//
// Como as grandezas são diferentes (nota vai de 1 a 5, idade em anos, peso
// em kg), cada uma é dividida antes pela sua escala: a diferença que, para
// aquele critério, já é considerada grande. Assim "1 ponto de nota" e "10
// anos de idade" passam a valer a mesma coisa na conta, e só o peso decide
// qual importa mais.
//
// Para mudar a prioridade, basta mexer nos pesos. Zerar um deles desliga o
// critério por completo.

/// Nota média de avaliação. É o critério principal: resume o desempenho que
/// os próprios jogadores enxergaram em campo.
const double pesoNota = 1.0;

/// Gols por rodada. Separa quem decide o jogo de quem só participa, coisa que
/// a nota sozinha não captura — um zagueiro sólido e um artilheiro podem ter
/// a mesma nota.
const double pesoGols = 0.6;

/// Idade média. Evita o time dos garotos contra o time dos veteranos: com
/// nota e gols empatados, fôlego e velocidade ainda decidem a partida.
const double pesoIdade = 0.4;

/// Peso corporal. Critério fraco no futebol amador, entra só para desempatar
/// quando o resto já está equilibrado.
const double pesoCorporal = 0.15;

/// Diferença de nota média já considerada grande (escala 1 a 5).
const double escalaNota = 1.0;

/// Diferença de gols por rodada já considerada grande.
const double escalaGols = 1.0;

/// Diferença de idade média, em anos, já considerada grande.
const double escalaIdade = 10.0;

/// Diferença de peso médio, em kg, já considerada grande.
const double escalaPeso = 15.0;
