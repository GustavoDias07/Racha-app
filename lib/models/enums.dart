/// Tipo de campo do racha. Determina a formação (goleiro fixo + vagas de linha).
enum TipoCampo { campao, society, futsal, minicampo }

extension TipoCampoX on TipoCampo {
  String get label => switch (this) {
        TipoCampo.campao => 'Campão',
        TipoCampo.society => 'Society',
        TipoCampo.futsal => 'Futsal',
        TipoCampo.minicampo => 'Minicampo',
      };

  /// Quantidade padrão de jogadores de linha (sem contar o goleiro).
  int get qtdJogadoresLinhaPadrao => switch (this) {
        TipoCampo.campao => 10,
        TipoCampo.futsal => 4,
        TipoCampo.society => 6,
        TipoCampo.minicampo => 7,
      };

  /// Campão e futsal têm formação fixa; society e minicampo podem ser
  /// ajustados pelo admin ao criar o racha.
  bool get qtdConfiguravel =>
      this == TipoCampo.society || this == TipoCampo.minicampo;
}

/// Posição em campo. O goleiro é a única vaga obrigatória e específica;
/// as demais são "vagas de linha" livres.
enum Posicao { goleiro, zagueiro, lateral, volante, meia, atacante }

extension PosicaoX on Posicao {
  String get label => switch (this) {
        Posicao.goleiro => 'Goleiro',
        Posicao.zagueiro => 'Zagueiro',
        Posicao.lateral => 'Lateral',
        Posicao.volante => 'Volante',
        Posicao.meia => 'Meia',
        Posicao.atacante => 'Atacante',
      };

  bool get isLinha => this != Posicao.goleiro;
}

/// Status do ciclo de vida de um racha.
enum RachaStatus { aberto, emAndamento, finalizado }

/// Time em que o jogador foi alocado pelo algoritmo de balanceamento.
enum TimeRacha { A, B }

/// Status de confirmação de presença de um Participante (User convidado
/// para um racha específico).
///
/// Desvio em relação à modelagem original (`confirmado: bool`): a tela de
/// Detalhes do Racha precisa distinguir pendente/confirmado/recusado, o que
/// um booleano não representa. `confirmado == true` continua sendo a mesma
/// condição usada pelo algoritmo de balanceamento para elegibilidade.
enum StatusConfirmacao { pendente, confirmado, recusado }

/// O que de fato aconteceu no dia do jogo, registrado por quem faz a chamada
/// (admin ou anotador). Diferente de `StatusConfirmacao`, que é a **intenção**
/// declarada dias antes.
///
/// A distinção que justifica esse enum existir: quem recusou com antecedência
/// e quem confirmou e não apareceu são coisas completamente diferentes pra
/// quem organiza — o primeiro avisou a tempo de chamar outro, o segundo
/// deixou o racha com um a menos. No `StatusConfirmacao` os dois acabavam
/// indistinguíveis depois do jogo.
enum PresencaFinal { compareceu, atrasou, faltou }

extension PresencaFinalX on PresencaFinal {
  String get label => switch (this) {
        PresencaFinal.compareceu => 'Compareceu',
        PresencaFinal.atrasou => 'Atrasou',
        PresencaFinal.faltou => 'Faltou',
      };
}

/// Status de aprovação de um Convidado pelo admin do racha.
///
/// Mesmo raciocínio do `StatusConfirmacao`: a tela de Aprovação de
/// Convidados precisa listar pendentes separadamente de recusados.
enum StatusAprovacao { pendente, aprovado, recusado }

/// Distingue a origem de um jogador (User cadastrado x Convidado sem login)
/// em referências como Avaliacao.avaliado_id e Estatistica.jogador_id.
/// Necessário porque User e Convidado vivem em coleções diferentes e um id
/// sozinho não diz qual delas consultar.
enum TipoJogador { user, convidado }

/// Dia da semana usado no Grupo (racha recorrente).
enum DiaSemana { segunda, terca, quarta, quinta, sexta, sabado, domingo }

extension DiaSemanaX on DiaSemana {
  String get label => switch (this) {
        DiaSemana.segunda => 'Segunda-feira',
        DiaSemana.terca => 'Terça-feira',
        DiaSemana.quarta => 'Quarta-feira',
        DiaSemana.quinta => 'Quinta-feira',
        DiaSemana.sexta => 'Sexta-feira',
        DiaSemana.sabado => 'Sábado',
        DiaSemana.domingo => 'Domingo',
      };
}
