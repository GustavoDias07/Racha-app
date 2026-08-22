import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'firebase_options.dart';
import 'providers/notification_controller.dart';

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
  runApp(const ProviderScope(child: RachaApp()));
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
      theme: AppTheme.light,
      routerConfig: router,
    );
  }
}
