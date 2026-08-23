/// Nomes de coleções do Firestore, centralizados para evitar strings soltas
/// espalhadas pelo código.
///
/// Estrutura: `users`, `grupos` e `rachas` são coleções de topo. Tudo que só
/// existe no contexto de um racha específico (participantes, convidados,
/// avaliações, estatísticas) fica em subcoleção de `rachas/{rachaId}`, que é
/// o padrão de consulta mais comum (ex: "lista de participantes do racha X").
class FirestorePaths {
  FirestorePaths._();

  static const users = 'users';
  static const grupos = 'grupos';
  static const rachas = 'rachas';
  static const rankings = 'rankings';

  // Subcoleções de rachas/{rachaId}
  static const participantes = 'participantes';
  static const convidados = 'convidados';
  static const avaliacoes = 'avaliacoes';
  static const estatisticas = 'estatisticas';

  // Subcoleção de users/{userId} — recados curtos pro jogador (ver AvisoModel).
  static const avisos = 'avisos';

  // Subcoleção de grupos/{grupoId} — pedidos de entrada (aba "Rachas Próximos").
  static const solicitacoes = 'solicitacoes';
}
