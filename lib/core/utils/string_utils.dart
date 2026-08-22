/// Deixa a primeira letra de cada palavra maiúscula e o resto minúsculo —
/// "gustavo dias" -> "Gustavo Dias". Usado nos campos de nome (cadastro,
/// convidado) pra manter a exibição consistente independente de como a
/// pessoa digitou.
String capitalizarNome(String nome) {
  return nome
      .trim()
      .split(RegExp(r'\s+'))
      .where((palavra) => palavra.isNotEmpty)
      .map((palavra) => palavra[0].toUpperCase() + palavra.substring(1).toLowerCase())
      .join(' ');
}
