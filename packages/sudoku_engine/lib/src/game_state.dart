/// Represents the full Sudoku game state owned by the engine.
///
/// Responsibilities:
/// - Stores immutable starting clues (`givens`)
/// - Stores the player's current entries (`entries`)
/// - Stores notes/pencil marks as bitmasks (`notesMasks`)
///
/// Design notes:
/// - All three lists must be length 81
/// - Values in `givens` and `entries` must be 0..9
/// - `givens` should never be mutated after construction
class GameState {
  /// The original puzzle clues.
  /// Non-zero cells are fixed and should not be editable.
  final List<int> givens;

  /// The player's current board values.
  /// 0 means blank.
  final List<int> entries;

  /// Pencil marks for each cell, stored as bitmasks.
  /// Length 81. Each int stores candidate digits 1..9.
  final List<int> notesMasks;
  /// Creates a GameState and validates the list sizes.
  GameState({
    required List<int> givens,
    required List<int> entries,
    required List<int> notesMasks,
  })  : givens = List.unmodifiable(givens),
        entries = List<int>.from(entries),
        notesMasks = List<int>.from(notesMasks) {
    if (this.givens.length != 81) {
      throw ArgumentError('givens must contain exactly 81 cells.');
    }
    if (this.entries.length != 81) {
      throw ArgumentError('entries must contain exactly 81 cells.');
    }
    if (this.notesMasks.length != 81) {
      throw ArgumentError('notesMasks must contain exactly 81 cells.');
    }

    for (final value in this.givens) {
      if (value < 0 || value > 9) {
        throw ArgumentError('givens values must be between 0 - 9.');
      }
    }

    for (final value in this.entries) {
      if (value < 0 || value > 9) {
        throw ArgumentError('entries values must be between 0 and 9.');
      }
    }
  }

  /// Creates a new game state from puzzle givens.
  ///
  /// - `entries` starts as a copy of `givens`
  /// - `notesMasks` starts empty (all zeros)
  factory GameState.fromGivens(List<int> givens) {
    if (givens.length != 81) {
      throw ArgumentError('givens must contain exactly 81 cells.');
    }

    return GameState(
      givens: givens,
      /// The player's current entries. Starts as a copy of givens.
      entries: List<int>.from(givens),
      /// Notes bitmask per cell (length 81).
      /// Bit 1 represents candidate 1, bit 2 represents candidate 2, etc.
      /// Example: candidates {1,3,9} => mask = (1<<1) | (1<<3) | (1<<9)
      notesMasks: List<int>.filled(81, 0),
    );
  }

  /// Returns true if the given cell index is a fixed starting clue.
  bool isGivenCell(int index) {
    _validateIndex(index);
    return givens[index] != 0;
  }

  /// Returns the current entry at a cell.
  int entryAt(int index) {
    _validateIndex(index);
    return entries[index];
  }

  /// Returns the current note bitmask at a cell.
  int notesMaskAt(int index) {
    _validateIndex(index);
    return notesMasks[index];
  }

  /// Returns a new GameState with one entry changed.
  ///
  /// Rules:
  /// - Given cells cannot be edited
  /// - Value must be 0..9
  /// - Setting a digit clears notes in that cell
  GameState copyWithEntry(int index, int value) {
    _validateIndex(index);

    if (value < 0 || value > 9) {
      throw ArgumentError('entry value must be between 0 and 9.');
    }

    if (isGivenCell(index)) {
      return this;
    }

    final newEntries = List<int>.from(entries);
    final newNotesMasks = List<int>.from(notesMasks);

    newEntries[index] = value;
    newNotesMasks[index] = 0;

    return GameState(
      givens: givens,
      entries: newEntries,
      notesMasks: newNotesMasks,
    );
  }

  /// Returns a new GameState with one note toggled.
  ///
  /// Rules:
  /// - Given cells cannot be edited
  /// - Notes can only be toggled on empty cells
  /// - Digit must be 1..9
  GameState copyWithToggledNote(int index, int digit) {
    _validateIndex(index);

    if (digit < 1 || digit > 9) {
      throw ArgumentError('note digit must be between 1 and 9.');
    }

    if (isGivenCell(index)) {
      return this;
    }

    if (entries[index] != 0) {
      return this;
    }

    final newNotesMasks = List<int>.from(notesMasks);
    final bit = 1 << digit;

    newNotesMasks[index] ^= bit;

    return GameState(
      givens: givens,
      entries: entries,
      notesMasks: newNotesMasks,
    );
  }

  /// Returns a new GameState with all notes cleared in one cell.
  GameState copyWithClearedNotes(int index) {
    _validateIndex(index);

    if (isGivenCell(index)) {
      return this;
    }

    final newNotesMasks = List<int>.from(notesMasks);
    newNotesMasks[index] = 0;

    return GameState(
      givens: givens,
      entries: entries,
      notesMasks: newNotesMasks,
    );
  }

  /// Returns true if the board is completely and validly solved.
  ///
  /// A solved board must:
  /// - contain no zeros
  /// - have digits 1..9 exactly once in every row
  /// - have digits 1..9 exactly once in every column
  /// - have digits 1..9 exactly once in every 3x3 box
  bool isSolved() {
    // A solved board cannot contain blanks.
    if (entries.contains(0)) {
      return false;
    }

    // Validate all rows.
    for (int row = 0; row < 9; row++) {
      if (!_rowValid(row)) {
        return false;
     }
    }

    // Validate all columns.
    for (int col = 0; col < 9; col++) {
      if (!_colValid(col)) {
        return false;
      }
    }

    // Validate all 3x3 boxes.
    for (int box = 0; box < 9; box++) {
      if (!_boxValid(box)) {
        return false;
      }
    }

    return true;
  }

  /// Returns true if the specified row contains digits 1..9 exactly once.
  bool _rowValid(int row) {
    if (row < 0 || row >= 9) {
      throw RangeError.range(row, 0, 8, 'row');
    }

    int seen = 0;

    for (int col = 0; col < 9; col++) {
      final value = entries[row * 9 + col];

      // Rows in a solved board must not contain zeros.
      if (value < 1 || value > 9) {
        return false;
      }

      final bit = 1 << value;

      // If we've already seen this digit, the row is invalid.
      if ((seen & bit) != 0) {
        return false;
      }

      seen |= bit;
    }

    return true;
  }

  /// Returns true if the specified column contains digits 1..9 exactly once.
  bool _colValid(int col) {
    if (col < 0 || col >= 9) {
      throw RangeError.range(col, 0, 9, 'col');
    }

    int seen = 0;

    for (int row = 0; row< 9; row++) {
      final value = entries[row * 9 + col];

      if (value < 1 || value > 9) {
        return false;
      }

      final bit = 1 << value;

      if ((seen & bit) != 0) {
        return false;
      }

      seen |= bit;
    }

    return true;
  }

  /// Returns true if the specified 3x3 box contains digits 1..9 exactly once.
  ///
  /// Boxes are indexed left-to-right, top-to-bottom:
  /// 0 1 2
  /// 3 4 5
  /// 6 7 8
  bool _boxValid(int box) {
    if (box < 0 || box >= 9) {
      throw RangeError.range(box, 0, 8, 'box');
    }

    final startRow = (box ~/ 3) * 3;
    final startCol = (box % 3) * 3;

    int seen = 0;

    for (int rowOffset = 0; rowOffset < 3; rowOffset++) {
      for (int colOffset = 0; colOffset < 3; colOffset++) {
        final row = startRow + rowOffset;
        final col = startCol + colOffset;
        final value = entries[row * 9 + col];

        if (value < 1 || value > 9) {
          return false;
        }

        final bit = 1 << value;

        if ((seen & bit) != 0) {
          return false;
        }

        seen |= bit;
      }
    }

    return true;
  }

  /// Converts this game state into a JSON-serializable map.
  Map<String, dynamic> toJson() {
    return {
      'givens': givens,
      'entries': entries,
      'notesMasks': notesMasks,
    };
  }

  /// Reconstructs a GameState from JSON data.
  factory GameState.fromJson(Map<String, dynamic> json) {
    return GameState(
      givens: List<int>.from(json['givens'] as List),
      entries: List<int>.from(json['entries'] as List),
      notesMasks: List<int>.from(json['notesMasks'] as List),
    );
  }

  /// Validates that an index is within the board range 0..80.
  void _validateIndex(int index) {
    if (index < 0 || index >= 81) {
      throw RangeError.index(index, entries, 'index', null, 81);
    }
  }
}