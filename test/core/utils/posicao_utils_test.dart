import 'package:flutter_test/flutter_test.dart';
import 'package:racha_app/core/utils/posicao_utils.dart';
import 'package:racha_app/models/enums.dart';
import 'package:racha_app/models/participante_model.dart';

ParticipanteModel _com(Posicao? main, {Posicao? usual}) {
  return ParticipanteModel(
    id: 'p',
    rachaId: 'r',
    userId: 'u',
    posicaoMain: main,
    posicaoUsual: usual,
    statusConfirmacao: StatusConfirmacao.confirmado,
  );
}

void main() {
  test('sem participações não há posição', () {
    expect(posicaoMaisFrequente(const []), isNull);
  });

  test('quem nunca informou posição não tem posição derivada', () {
    expect(posicaoMaisFrequente([_com(null), _com(null)]), isNull);
  });

  test('devolve a posição mais repetida, com a contagem', () {
    final resultado = posicaoMaisFrequente([
      _com(Posicao.atacante),
      _com(Posicao.zagueiro),
      _com(Posicao.atacante),
      _com(Posicao.atacante),
    ]);

    expect(resultado!.posicao, Posicao.atacante);
    expect(resultado.vezes, 3);
  });

  test('ignora a posição secundária', () {
    // A secundária existe para cobrir setor em falta no balanceamento; contá-la
    // aqui faria um zagueiro eventual parecer meia.
    final resultado = posicaoMaisFrequente([
      _com(Posicao.zagueiro, usual: Posicao.meia),
      _com(Posicao.zagueiro, usual: Posicao.meia),
    ]);

    expect(resultado!.posicao, Posicao.zagueiro);
  });

  test('participação sem posição não atrapalha a contagem das outras', () {
    final resultado = posicaoMaisFrequente([
      _com(null),
      _com(Posicao.goleiro),
      _com(null),
    ]);

    expect(resultado!.posicao, Posicao.goleiro);
    expect(resultado.vezes, 1);
  });

  test('empate é resolvido pela ordem do enum, não pela ordem da lista', () {
    // Sem isso a resposta mudaria conforme a ordem em que o Firestore
    // devolvesse os documentos, e a mesma pessoa apareceria ora goleiro ora
    // atacante entre dois carregamentos.
    final umaOrdem = posicaoMaisFrequente([
      _com(Posicao.atacante),
      _com(Posicao.goleiro),
    ]);
    final outraOrdem = posicaoMaisFrequente([
      _com(Posicao.goleiro),
      _com(Posicao.atacante),
    ]);

    expect(umaOrdem!.posicao, Posicao.goleiro);
    expect(outraOrdem!.posicao, Posicao.goleiro);
  });
}
