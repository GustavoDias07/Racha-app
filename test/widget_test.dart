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

void main() {
  test('AppTheme.dark monta um ThemeData válido e escuro', () {
    final tema = AppTheme.dark;
    expect(tema.useMaterial3, isTrue);
    expect(tema.brightness, Brightness.dark);
  });

  // O app não tem versão clara: se alguém trocar a cor de fundo por engano,
  // o contraste do texto some e nenhuma tela avisa. Estes dois travam isso.
  test('o fundo é escuro e a cor do app é o verde da marca', () {
    final cores = AppTheme.dark.colorScheme;
    expect(cores.surface, AppColors.fundo);
    expect(cores.primary, AppColors.verde);
  });

  test('texto sobre o verde é preto, não branco', () {
    // Branco sobre o verde vibrante fica ilegível; o contraste alto é o que
    // define esse estilo visual.
    expect(AppTheme.dark.colorScheme.onPrimary, const Color(0xFF000000));
  });
}
