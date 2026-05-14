import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/game_state.dart';

/// Supabase service for multiplayer: real-time board sync, matchmaking, deep links.
class SupabaseService {
  static SupabaseService? _instance;
  late final SupabaseClient _client;

  SupabaseService._();

  static SupabaseService get instance {
    _instance ??= SupabaseService._();
    return _instance!;
  }

  /// Initialize the Supabase client with project URL and anon key.
  Future<void> initialize({
    required String url,
    required String anonKey,
  }) async {
    await Supabase.initialize(
      url: url,
      anonKey: anonKey,
    );
    _client = Supabase.instance.client;
  }

  SupabaseClient get client => _client;

  // ─── Game CRUD ───────────────────────────────────────────────────────────

  /// Create a new game and return the game ID.
  Future<String> createGame({required String whitePlayerId}) async {
    final response = await _client.from('games').insert({
      'white_player_id': whitePlayerId,
      'status': 'waiting',
      'board_state': GameState.newGame(gameId: '', whitePlayerId: whitePlayerId)
          .board
          .toJson(),
      'turn': 'white',
    }).select('id').single();

    return response['id'] as String;
  }

  /// Join a game as black.
  Future<void> joinGame({
    required String gameId,
    required String blackPlayerId,
  }) async {
    await _client.from('games').update({
      'black_player_id': blackPlayerId,
      'status': 'playing',
    }).eq('id', gameId);
  }

  /// Update the board state (called after every move).
  Future<void> updateBoardState({
    required String gameId,
    required GameState state,
  }) async {
    await _client.from('games').update({
      'board_state': state.toJson(),
      'turn': state.board.turn.name,
      'status': state.status.name,
      'full_turn_count': state.fullTurnCount,
    }).eq('id', gameId);
  }

  /// Subscribe to real-time game updates.
  RealtimeChannel subscribeToGame(String gameId, void Function(GameState) onUpdate) {
    return _client
        .channel('game:$gameId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'games',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: gameId,
          ),
          callback: (payload) {
            final data = payload.newRecord;
            final gameState = GameState.fromJson(
              Map<String, dynamic>.from(data),
            );
            onUpdate(gameState);
          },
        )
        .subscribe();
  }

  /// Generate a deep link for sharing.
  String generateDeepLink(String gameId) {
    return 'https://chessroguelike.com/join/$gameId';
  }
}
