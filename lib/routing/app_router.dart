import 'package:go_router/go_router.dart';
import '../ui/screens/home_screen.dart';
import '../ui/screens/game_screen.dart';

/// App routing with deep link support for game invites.
class AppRouter {
  static const home = '/';
  static const game = '/game/:gameId';
  static const join = '/join/:gameId'; // Deep link entry point

  static final GoRouter router = GoRouter(
    initialLocation: home,
    routes: [
      GoRoute(
        path: home,
        name: 'home',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/game/:gameId',
        name: 'game',
        builder: (context, state) {
          final gameId = state.pathParameters['gameId']!;
          final isOffline = state.uri.queryParameters['offline'] == 'true';
          return GameScreen(gameId: gameId, isOffline: isOffline);
        },
      ),
      // Deep link: /join/{gameId} → same as /game/{gameId}
      GoRoute(
        path: '/join/:gameId',
        redirect: (context, state) {
          final gameId = state.pathParameters['gameId']!;
          return '/game/$gameId';
        },
      ),
    ],
  );
}
