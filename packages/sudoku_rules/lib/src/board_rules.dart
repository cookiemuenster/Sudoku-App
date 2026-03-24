/// Stateless helper methods for Sudoku board relationships and conflict checks.
class BoardRules {
  static const int size = 9;

  /// Returns true if cell [a] shares a row, column, or 3x3 box with cell [b].
  static bool sharesRowColOrBox(int a, int b) {
    final aRow = a ~/ size;
    final aCol = a % size;

    final bRow = b ~/ size;
    final bCol = b % size;

    final sameRow = aRow == bRow;
    final sameCol = aCol == bCol;

    final aBox = (aRow ~/ 3) * 3 + (aCol ~/ 3);
    final bBox = (bRow ~/ 3) * 3 + (bCol ~/ 3);
    final sameBox = aBox == bBox;

    return sameRow || sameCol || sameBox;
  }

  /// Returns the set of indices that conflict with the value at [index].
  ///
  /// A conflict means another cell in the same row, column, or 3x3 box
  /// contains the same non-zero value.
  static Set<int> conflictsForIndex({
    required int index,
    required List<int> entries,
  }) {
    final v =entries[index];
    if (v == 0) return <int>{};
    // row and col are derived from the single linear cell index 0..80.
    //Since the board is stored as a flat list, you need:
    // row = index ~/ 9
    // col = index % 9
    // Without those two variables, the later calculations have nothing to reference.
    final row = index ~/ size;
    final col = index % size;

    final boxRow = (row ~/ 3) * 3;
    final boxCol = (col ~/ 3) * 3;

    final conflicts = <int>{};

    // Row conflicts
    for (int c = 0; c < size; c++) {
      final i = row * size + c;
      if (i != index && entries[i] == v) {
        conflicts.add(i);
      }
    }

    // Column conflicts
    for (int r = 0; r < size; r++) {
      final i = r * size + col;
      if (i != index && entries[i] == v) {
        conflicts.add(i);
      }
    }

    // Box conflicts
    for (int r = boxRow; r < boxRow + 3; r++) {
      for (int c = boxCol; c < boxCol + 3; c++) {
        final i = r * size + c;
        if (i != index && entries[i] == v) {
          conflicts.add(i);
        }
      }
    }

    return conflicts;
  }
}