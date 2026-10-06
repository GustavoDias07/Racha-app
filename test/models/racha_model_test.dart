import 'package:flutter_test/flutter_test.dart';

import 'package:racha_app/models/enums.dart';
import 'package:racha_app/models/racha_model.dart';

void main() {
  final racha = RachaModel(
    id: 'r1',
    nome: 'Racha',
    local: 'Campo',
    dataHora: DateTime(2026, 10, 5),
    tipoCampo: TipoCampo.society,
    qtdJogadoresLinha: 6,
    adminId: 'admin',
    anotadores: const ['anotador'],
  );

  group('quem pode conferir estatística', () {
    test('admin e anotador conferem os números de outro jogador', () {
      expect(racha.podeConferirEstatistica('admin', 'jogador'), isTrue);
      expect(racha.podeConferirEstatistica('anotador', 'jogador'), isTrue);
    });

    test('jogador comum não confere nem os próprios números', () {
      expect(racha.podeConferirEstatistica('jogador', 'jogador'), isFalse);
      expect(racha.podeConferirEstatistica('jogador', 'outro'), isFalse);
      expect(racha.podeConferirEstatistica(null, 'jogador'), isFalse);
    });

    test('anotador não confere os próprios números', () {
      expect(racha.podeConferirEstatistica('anotador', 'anotador'), isFalse);
    });

    test('admin confere os próprios, porque já pode editar os de qualquer um',
        () {
      expect(racha.podeConferirEstatistica('admin', 'admin'), isTrue);
    });
  });
}
