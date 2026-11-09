// Garante que os SVGs de assets/ilustracoes/ existem, estão registrados no
// pubspec e são lidos pelo flutter_svg sem erro, nos dois temas (T26).
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:racha_app/core/theme/app_theme.dart';
import 'package:racha_app/widgets/ilustracao.dart';

void main() {
  for (final (nomeTema, tema) in [('claro', AppTheme.light), ('escuro', AppTheme.dark)]) {
    testWidgets('todas as ilustrações desenham no tema $nomeTema', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: tema,
        home: Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: [
                for (final i in Ilustracao.values) IlustracaoSvg(i, altura: 60),
                const CamisasNumeradas(),
              ],
            ),
          ),
        ),
      ));
      // A leitura do arquivo é assíncrona (vem do pacote de assets).
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.byType(SvgPicture), findsNWidgets(Ilustracao.values.length + 1));
      expect(find.text('1'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
    });
  }
}
