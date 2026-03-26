/// Temporary in-app puzzle catalog.
///
/// Adding difficulty class.
enum PuzzleDifficulty {
  easy,
  medium,
  hard,
}
/// For now this is a simple hardcoded list.
/// Placeholder "entries" for UI highlighting.
/// - 0 means blank
/// - 1..9 are digits
///
/// Later this can be replaced with:
/// - JSON assets
/// - curated puzzle packs
/// - generated puzzles
class PuzzleCatalog {
  static const Map<PuzzleDifficulty, List<String>> puzzles = {
    PuzzleDifficulty.easy: [
      //Puzzle 1
      '530070000'
      '600195000'
      '098000060'
      '800060003'
      '400803001'
      '700020006'
      '060000280'
      '000419005'
      '000080079',
    ],
    PuzzleDifficulty.medium: [
      //Puzzle 2
      '200080300'
      '060070084'
      '030500209'
      '000105408'
      '000000000'
      '402706000'
      '301007040'
      '720040060'
      '004010003',
    ],
    PuzzleDifficulty.hard: [
      //Puzzle 3
      '000260701'
      '680070090'
      '190004500'
      '820100040'
      '004602900'
      '050003028'
      '009300074'
      '040050036'
      '703018000',
    ],
  };
}