import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/grupo_model.dart';
import '../../models/racha_model.dart';
import '../../models/user_model.dart';
import '../../providers/firebase_providers.dart';
import '../../screens/auth/cadastro_screen.dart';
import '../../screens/auth/login_screen.dart';
import '../../screens/grupo/criar_grupo_screen.dart';
import '../../screens/grupo/editar_grupo_screen.dart';
import '../../screens/grupo/grupo_detalhe_screen.dart';
import '../../screens/grupo/grupo_ranking_screen.dart';
import '../../screens/grupo/historico_grupo_screen.dart';
import '../../screens/home/home_screen.dart';
import '../../screens/perfil/editar_perfil_screen.dart';
import '../../screens/perfil/perfil_screen.dart';
import '../../screens/racha/avaliacao_screen.dart';
import '../../screens/racha/convidar_jogador_screen.dart';
import '../../screens/racha/criar_racha_screen.dart';
import '../../screens/racha/editar_racha_screen.dart';
import '../../screens/racha/racha_detalhe_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateChangesProvider);

  return GoRouter(
    initialLocation: '/login',
    refreshListenable: GoRouterRefreshStream(ref, authStateChangesProvider),
    redirect: (context, state) {
      final logado = authState.valueOrNull != null;
      final indoParaAuth =
          state.matchedLocation == '/login' || state.matchedLocation == '/cadastro';

      if (!logado && !indoParaAuth) return '/login';
      if (logado && indoParaAuth) return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
          path: '/cadastro', builder: (context, state) => const CadastroScreen()),
      GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
      GoRoute(path: '/perfil', builder: (context, state) => const PerfilScreen()),
      GoRoute(
        path: '/perfil/editar',
        builder: (context, state) =>
            EditarPerfilScreen(user: state.extra as UserModel),
      ),
      GoRoute(
        path: '/grupos/criar',
        builder: (context, state) => const CriarGrupoScreen(),
      ),
      GoRoute(
        path: '/rachas/criar',
        builder: (context, state) => const CriarRachaScreen(),
      ),
      GoRoute(
        path: '/grupos/:id',
        builder: (context, state) =>
            GrupoDetalheScreen(grupo: state.extra as GrupoModel),
      ),
      GoRoute(
        path: '/grupos/:id/ranking',
        builder: (context, state) {
          final grupo = state.extra as GrupoModel;
          return GrupoRankingScreen(grupoId: grupo.id, grupoNome: grupo.nome);
        },
      ),
      GoRoute(
        path: '/grupos/:id/historico',
        builder: (context, state) {
          final grupo = state.extra as GrupoModel;
          return HistoricoGrupoScreen(grupoId: grupo.id, grupoNome: grupo.nome);
        },
      ),
      GoRoute(
        path: '/grupos/:id/editar',
        builder: (context, state) =>
            EditarGrupoScreen(grupo: state.extra as GrupoModel),
      ),
      GoRoute(
        path: '/rachas/:id',
        builder: (context, state) =>
            RachaDetalheScreen(rachaId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/rachas/:id/convidar',
        builder: (context, state) => ConvidarJogadorScreen(
          rachaId: state.pathParameters['id']!,
          convidadoPor: state.extra as String,
        ),
      ),
      GoRoute(
        path: '/rachas/:id/editar',
        builder: (context, state) =>
            EditarRachaScreen(racha: state.extra as RachaModel),
      ),
      GoRoute(
        path: '/rachas/:id/avaliar',
        builder: (context, state) =>
            AvaliacaoScreen(rachaId: state.pathParameters['id']!),
      ),
    ],
  );
});

/// Ponte entre um StreamProvider do Riverpod e o Listenable que o go_router
/// espera em `refreshListenable`, pra revalidar o redirect toda vez que o
/// estado de autenticação mudar.
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Ref ref, StreamProvider provider) {
    ref.listen(provider, (_, _) => notifyListeners());
  }
}
