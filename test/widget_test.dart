// O teste padrão do template (contador) não se aplica mais.
//
// Testar o RachaApp inteiro exige Firebase inicializado (main() chama
// Firebase.initializeApp antes de montar o widget, e os providers leem
// FirebaseAuth.instance direto). Isso pede mocks dos plugins do Firebase
// (ex: firebase_auth_mocks, fake_cloud_firestore), que ainda não fazem
// parte do projeto — fica como próximo passo ao testar telas/providers.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:racha_app/core/theme/app_theme.dart';
import 'package:racha_app/providers/tema_controller.dart';

void main() {
  test('AppTheme.dark monta um ThemeData válido e escuro', () {
    final tema = AppTheme.dark;
    expect(tema.useMaterial3, isTrue);
    expect(tema.brightness, Brightness.dark);
  });

  test('AppTheme.light monta um ThemeData válido e claro', () {
    final tema = AppTheme.light;
    expect(tema.useMaterial3, isTrue);
    expect(tema.brightness, Brightness.light);
  });

  // Se alguém trocar a cor de fundo por engano, o contraste do texto some e
  // nenhuma tela avisa. Estes testes travam isso nos dois temas.
  test('cada tema pendura o seu conjunto de cores', () {
    expect(AppTheme.dark.extension<AppCores>(), AppCores.escuro);
    expect(AppTheme.light.extension<AppCores>(), AppCores.claro);
  });

  test('o fundo e o verde da marca chegam ao colorScheme', () {
    expect(AppTheme.dark.colorScheme.surface, AppCores.escuro.fundo);
    expect(AppTheme.light.colorScheme.surface, AppCores.claro.fundo);
    // O verde de preencher é o mesmo nos dois: é a identidade do app.
    expect(AppTheme.dark.colorScheme.primary, const Color(0xFF1DB954));
    expect(AppTheme.light.colorScheme.primary, const Color(0xFF1DB954));
  });

  test('texto sobre o verde é preto, não branco, nos dois temas', () {
    // Branco sobre o verde vibrante fica ilegível; o contraste alto é o que
    // define esse estilo visual.
    expect(AppTheme.dark.colorScheme.onPrimary, const Color(0xFF000000));
    expect(AppTheme.light.colorScheme.onPrimary, const Color(0xFF000000));
  });

  test('no claro, o verde de texto é mais escuro que o de preencher', () {
    // Letra #1DB954 em fundo claro tem contraste baixo; por isso existe o
    // verdeTexto. Luminância menor = cor mais escura = mais contraste.
    expect(
      AppCores.claro.verdeTexto.computeLuminance(),
      lessThan(AppCores.claro.verde.computeLuminance()),
    );
    // E o texto comum do claro tem contraste alto com o fundo.
    expect(AppCores.claro.texto.computeLuminance(), lessThan(0.05));
  });

  group('preferência de tema salva no aparelho', () {
    test('ida e volta: cada opção vira texto e volta igual', () {
      for (final modo in ThemeMode.values) {
        expect(modoDoTexto(textoDoModo(modo)), modo);
      }
    });

    test('sem nada salvo (ou valor estranho), segue o celular', () {
      expect(modoDoTexto(null), ThemeMode.system);
      expect(modoDoTexto('qualquer-coisa'), ThemeMode.system);
    });
  });
}
