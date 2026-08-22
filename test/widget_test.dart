// O teste padrão do template (contador) não se aplica mais.
//
// Testar o RachaApp inteiro exige Firebase inicializado (main() chama
// Firebase.initializeApp antes de montar o widget, e os providers leem
// FirebaseAuth.instance direto). Isso pede mocks dos plugins do Firebase
// (ex: firebase_auth_mocks, fake_cloud_firestore), que ainda não fazem
// parte do projeto — fica como próximo passo ao testar telas/providers.
import 'package:flutter_test/flutter_test.dart';

import 'package:racha_app/core/theme/app_theme.dart';

void main() {
  test('AppTheme.light monta um ThemeData válido', () {
    expect(AppTheme.light.useMaterial3, isTrue);
  });
}
