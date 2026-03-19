import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sudoku_engine/sudoku_engine.dart';

/// Handles saving and loading the current Sudoku game locally.
class GameSaveStore {
  static const String _currentGameKey = 'current_game';

  /// Saves the current game state as JSON.
  Future<void> saveGame(GameState gameState) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(gameState.toJson());
    await prefs.setString(_currentGameKey, jsonString);
  }

  /// Loads the saved game state, or returns null if none exists.
  Future<GameState?> loadGame() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_currentGameKey);

    if (jsonString == null) {
      return null;
    }

    final decoded = jsonDecode(jsonString) as Map<String, dynamic>;
    return GameState.fromJson(decoded);
  }

  /// Removes the saved game from storage.
  Future<void> clearGame() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_currentGameKey);
  }
}