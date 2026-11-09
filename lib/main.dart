import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'firebase_options.dart';
import 'providers/notification_controller.dart';
import 'providers/tema_controller.dart';

/// Mensagem chegou com o app em segundo plano ou fechado — o próprio
/// Android já mostra a notificação sozinho (o payload tem `notification`),
/// esse handler só existe pro dia em que precisar processar dados extras
/// junto. Tem que ser uma função de nível de topo (não um método de
/// classe) — é assim que o Firebase exige, porque roda num isolate
/// separado.
@pragma('vm:entry-point')
Future<void> _aoReceberEmSegundoPlano(RemoteMessage message) async {}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseMessaging.onBackgroundMessage(_aoReceberEmSegundoPlano);
  await initializeDateFormatting('pt_BR');
  // Abre a preferência de tema antes do app subir, para a primeira tela já
  // nascer no tema escolhido (ver tema_controller.dart).
  final prefs = await SharedPreferences.getInstance();
  runApp(ProviderScope(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    child: const RachaApp(),
  ));
}

class RachaApp extends ConsumerWidget {
  const RachaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    ref.watch(notificationSyncProvider);

    return MaterialApp.router(
      title: 'Racha App',
      debugShowCheckedModeBanner: false,
      // `theme` é usado no modo claro, `darkTheme` no escuro, e `themeMode`
      // diz qual vale: claro, escuro ou o do celular (ThemeMode.system).
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ref.watch(temaProvider),
      routerConfig: router,
    );
  }
}
