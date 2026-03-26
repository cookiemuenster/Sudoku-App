import 'package:flutter/material.dart';
import 'package:sudoku_engine/sudoku_engine.dart';
import 'package:sudoku_rules/sudoku_rules.dart';
import 'data/persistence/game_save_store.dart';
import 'data/puzzles/puzzle_catalog.dart';

// App entry point.
// Flutter starts executing here.
void main() {
  runApp(const SudokuApp());
}

// Top-level widget for the entire application.
// - Configures MaterialApp (theme, title, navigation root).
class SudokuApp extends StatelessWidget {
  const SudokuApp({super.key});

  @override
  Widget build(BuildContext context) {
    // MaterialApp sets up the app-wide Material Design behavior and styling.
    return MaterialApp(
      title: 'Sudoku',
      theme: ThemeData(useMaterial3: true), // Enables Material 3 styling.
      home: const PlayScreen(), // The first screen shown when the app starts.
    );
  }
}

// The main gameplay screen.
// The gameplay screen is made stateful so the selected cell can be stored.
// Right now it contains:
// - An AppBar with placeholder buttons
// - A centered SudokuGrid widget
class PlayScreen extends StatefulWidget {
  const PlayScreen({super.key});

  @override
  State<PlayScreen> createState() => _PlayScreenState();
}

class _PlayScreenState extends State<PlayScreen> {
  // Index (0..80) of the currently selected cell, or null if none selected.
  int? _selectedIndex;
  late String _currentPuzzle;
  PuzzleDifficulty _currentDifficulty = PuzzleDifficulty.easy;
  late GameState _gameState;

  ///ADDING UNDO & REDO STACKS
  final List<GameState> _undoStack = [];
  final List<GameState> _redoStack = [];

  //ADDING GAME SAVE STORE FIELD TO ENABLE GAME SAVE AND RESUME FUNCTIONALITY
  final GameSaveStore _saveStore = GameSaveStore();

  ///INITIALIZING GAME ENGINE STATE
  @override
  void initState() {
    super.initState();

    /// Points to the first puzzle in the `PuzzleCatalog` class.
    _currentPuzzle = PuzzleCatalog.puzzles[_currentDifficulty]!.first;

    /// The immutable starting clues of the puzzle (never changes).
    final givens =  _parsePuzzle(_currentPuzzle);

    /// Constructs givens, entries and notesMasks.
    _gameState = GameState.fromGivens(givens);

    //calling `_loadSavedGame` method
    //if there is a saved game, the game will reload from where the user left off in the game.
    _loadSavedGame();
  }

  // Helper to load a previously saved game.
  Future<void> _loadSavedGame() async {
    final savedGame = await _saveStore.loadGame();

    if (!mounted || savedGame == null) return;

    setState(() {
      _gameState = savedGame;
    });
  }

  /// Helper to apply moves/ load a saved game/ check if the state is solved/ update state.
  /// Shows dialogue if the current game is solved.
  void _applyNewState(GameState newState) {
    final wasSolved = _gameState.isSolved();
    final isNowSolved = newState.isSolved();

    setState(() {
      _undoStack.add(_gameState);
      _redoStack.clear();
      _gameState = newState;
    });

    _saveStore.saveGame(_gameState);

    if (!wasSolved && isNowSolved) {
      _showsSolvedDialog();
    }
  }

  /// START NEW GAME
  /// Adding a methos o allow the user to start a new game
  void _startNewGame({PuzzleDifficulty? difficulty}) {
    final selecedDifficulty = difficulty ?? _currentDifficulty;

    final puzzles = PuzzleCatalog.puzzles[selecedDifficulty]!;

    // Very simple selection rule for now:
    // pick a different puzzle if possible.
    final available = puzzles.where((p) => p != _currentPuzzle).toList();
    final nextPuzzle = available.isNotEmpty ? available.first : puzzles.first;

    final givens = _parsePuzzle(nextPuzzle);
    final newState = GameState.fromGivens(givens);

    setState(() {
      _currentPuzzle = nextPuzzle;
      _selectedIndex = null;
      _noteMode = false;
      _undoStack.clear();
      _redoStack.clear();
      _gameState = newState;
    });

    _saveStore.saveGame(_gameState);
  }

  /// RESTART GAME
  void _resetPuzzle() {
    // Recreates a fresh board from the same puzzle.
    // Using _gameState.givens means reset works even after resume,
    // because it resets the puzzle currently in progress.
    final resetState = GameState.fromGivens(_gameState.givens);

    setState(() {
      _selectedIndex = null;
      _noteMode = false;
      // Clearing undo/redo avoids carrying old history into the reset board.
      _undoStack.clear();
      _redoStack.clear();
      _gameState = resetState;
    });

    _saveStore.saveGame(_gameState);
  }

  // NOTES FEATURE:
  /// When true, number pad toggles notes instead of placing a digit.
  bool _noteMode = false;

  // Converts an 81-character puzzle string into a List<int> of length 81.
  List<int> _parsePuzzle(String puzzle) {
    if (puzzle.length != 81) {
      throw ArgumentError('Puzzle string must be exactly 81 characters.');
    }
    return puzzle.split('').map((ch) {
      final v = int.tryParse(ch);
      if (v == null || v < 0 || v > 9) {
        throw ArgumentError('Puzzle contains an invalid character: $ch');
      }
      return v; // 0...9
    }).toList(growable: false);
  }

  // HELPER FUNCTIONS FOR NOTES => BITMASK OPERATIONS
  /// Returns the bit for a candidate digit 1..9.
  int _bitFor(int digit) => 1 << digit;

  /// True if the note candidate exists in the cell mask.
  bool _hasNote(int index, int digit) {
    return (_gameState.notesMasks[index] & _bitFor(digit)) != 0;
  }

  //USER SELECTS A BOX FEATURE:
  /// Called when the user taps a cell.
  void _handleCellTap(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  //SETTING THE DIGIT SELECTED BY THE USER:
  void _placeDigit(int digit) {
    final idx = _selectedIndex;
    if (idx == null) return;

    final newState = _gameState.copyWithEntry(idx, digit);

    if (identical(newState, _gameState)) return;

    _applyNewState(newState);
  }

  /// Toggle (add/remove) a note candidate digit 1..9.
  void _toggleNote(int index, int digit) {
    final newState = _gameState.copyWithToggledNote(index, digit);

    if (identical(newState, _gameState)) return;
    
    _applyNewState(newState);
  }

  /// Clears all notes in the selected cell.
  void _clearNotes(int index) {
    final newState = _gameState.copyWithClearedNotes(index);
    
    if (identical(newState, _gameState)) return;
    
    _applyNewState(newState);
  }

  void _undo() {
    if (_undoStack.isEmpty) return;

    setState(() {
      _redoStack.add(_gameState);
      _gameState = _undoStack.removeLast();
      _saveStore.saveGame(_gameState);
    });
  }

  void _redo() {
    if (_redoStack.isEmpty) return;

    setState(() {
      _undoStack.add(_gameState);
      _gameState = _redoStack.removeLast();
      _saveStore.saveGame(_gameState);
    });
  }

  // Adding helper to show victory dialogue
  Future<void> _showsSolvedDialog() async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Puzzle Solved'),
          content: const Text('Nice work. You completed the Sudoku puzzle.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  // Adding helper to show confirmation dialogue before calling _resetPuzzle
  Future<void> _confirmResetPuzzle() async {
    // `showDialog<bool>` returns true, false, or null
    final shouldReset = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Reset Puzzle'),
          content: const Text(
            'Clear all progress and restart this puzzle from the beginning?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Reset'),
            ),
          ],
        );
      },
    );

    // only `true` triggers the reset
    if (shouldReset == true) {
      _resetPuzzle();
    }
  }

  // Adding heper to show a confirmation dialog before starting a new game.
  Future<void> _confirmStartNewGame() async {
    final selectedDifficulty = await showDialog<PuzzleDifficulty>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('New Game'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _difficultyButton(context, PuzzleDifficulty.easy),
              _difficultyButton(context, PuzzleDifficulty.medium),
              _difficultyButton(context, PuzzleDifficulty.hard),
            ],
          ),
        );
      },
    );

    if (selectedDifficulty != null) {
      _startNewGame(difficulty: selectedDifficulty);
    }
  }

  /// Widget for difficulty buttons
  Widget _difficultyButton(
    BuildContext context,
    PuzzleDifficulty difficulty,
  ) {
    final label = switch (difficulty) {
      PuzzleDifficulty.easy => 'Easy',
      PuzzleDifficulty.medium => 'Medium',
      PuzzleDifficulty.hard => 'Hard',
    };

    return ListTile(
      title: Text(label),
      onTap: () => Navigator.of(context).pop(difficulty),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Top bar of the screen (title + action buttons).
      appBar: _PlayAppBar(
        onUndo: _undo,
        onRedo: _redo,
        canUndo: _undoStack.isNotEmpty,
        canRedo: _redoStack.isNotEmpty,
        onNewGame: _confirmStartNewGame,
        onResetPuzzle: _confirmResetPuzzle,
      ),
      // SafeArea prevents UI from being hidden by notches / system overlays.
      body: SafeArea(
        child: Center(
          /// Adding number pad below the sudoku puzzle.
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              /// Board
              SudokuGrid(
                selectedIndex: _selectedIndex,
                givens: _gameState.givens,
                entries: _gameState.entries,
                notesMasks: _gameState.notesMasks,
                onCellTap: _handleCellTap,
              ),
              const SizedBox(height: 12),
              /// Number pad behavior features
              _NumberPad(
                /// Note mode toggle behavior
                noteMode: _noteMode,
                onToggleNoteMode: () {
                  setState(() {
                    _noteMode = !_noteMode; /// note mode off by default
                  });
                },
                /// Place selected digit behavior
                onNumber: (n) {
                  final idx = _selectedIndex;
                  if (idx == null) return;

                  /// Ensuring default numbers (givens) can't be changed.
                  if (_gameState.givens[idx] != 0) return;

                  if(_noteMode) {
                    /// Only allow notes on empty cells (common UX).
                    if (_gameState.entries[idx] != 0) return;
                    _toggleNote(idx, n);
                  } else {
                    _placeDigit(n);
                  }
                },
                /// Clear selected digit behavior
                onClear: () {
                  final idx = _selectedIndex;
                  if(idx == null) return;

                  /// Checks if the block has a default number
                  if (_gameState.givens[idx] != 0) return;

                  if (_noteMode) {
                    _clearNotes(idx);
                  } else {
                    _placeDigit(0);
                  }
                },
              ),
            ],
          ),
        )
      ),
    );
  }
}

/// Custom AppBar widget for the PlayScreen.
///
/// Implements PreferredSizeWidget because Scaffold.appBar requires it
/// (so it knows how tall the app bar should be).
class _PlayAppBar extends StatelessWidget implements PreferredSizeWidget {
  final VoidCallback onUndo;
  final VoidCallback onRedo;
  final VoidCallback onNewGame;
  final VoidCallback onResetPuzzle;
  final bool canUndo;
  final bool canRedo;

  const _PlayAppBar({
    required this.onUndo,
    required this.onRedo,
    required this.onNewGame,
    required this.onResetPuzzle,
    required this.canUndo,
    required this.canRedo,
  });

  /// Preferred size (height) of this app bar.
  /// kToolbarHeight is the standard Material AppBar height.
  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: const Text('Sudoku'),
      actions: [
        // Undo button.
        // onPressed is null => button is disabled (greyed out).
        IconButton(
          tooltip: 'Undo',
          onPressed: canUndo ? onUndo : null,
          icon: const Icon(Icons.undo),
        ),
        // Redo button.
        IconButton(
          tooltip: 'Redo',
          onPressed: canRedo ? onRedo : null,
          icon: const Icon(Icons.redo),
        ),
        // New Game button
        IconButton(
          tooltip: 'New Game',
          onPressed: onNewGame,
          icon: const Icon(Icons.refresh),
        ),
        // Reset Puzzle
        IconButton(
          tooltip: 'Reset Puzzle',
          onPressed: onResetPuzzle,
          icon: const Icon(Icons.restart_alt),
        )
      ],
    );
  }
}

// Displays a responsive square 9x9 Sudoku grid with tap selection and highlights.
class SudokuGrid extends StatelessWidget {
  /// Standard Sudoku dimensions (9 rows x 9 columns).
  static const int size = 9;

  /// Currently selected cell index (0..80), or null.
  final int? selectedIndex;

  // Default numbers on the board. Uneditable.
  final List<int> givens;

  /// Current numbers on the board (0 blank, 1..9 digit).
  final List<int> entries;

  /// Callback when a cell is tapped.
  final void Function(int index) onCellTap;

  /// For notes mode
  final List<int> notesMasks;

  const SudokuGrid({
    super.key,
    required this.selectedIndex,
    required this.givens,
    required this.entries,
    required this.notesMasks,
    required this.onCellTap,
  });

  @override
  Widget build(BuildContext context) {
    /// LayoutBuilder provides the available width/height constraints of the parent.
    /// We use it to keep the board perfectly square and responsive.
    return LayoutBuilder(
      builder: (context, constraints) {
        /// boardSize chooses the smaller dimension so the board fits on screen
        /// without overflowing either width or height.
        final double boardSize =
            constraints.maxWidth < constraints.maxHeight
                ? constraints.maxWidth
                : constraints.maxHeight;

        return SizedBox(
          // Force the Sudoku board to be square.
          width: boardSize,
          height: boardSize,
          child: AspectRatio(
            aspectRatio: 1, // 1:1 aspect ratio ensures squareness.
            child: _BoardBorder(
              // GridView.builder efficiently builds 81 cells (9x9).
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.zero,

                // 9 columns. GridView will create 9 rows automatically.
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: size,
                ),

                // Total number of cells: 9 * 9 = 81.
                itemCount: size * size,

                itemBuilder: (context, index) {
                  // Convert the 0..80 index into row/column coordinates.
                  final row = index ~/ size; // Integer division.
                  final col = index % size;  // Remainder.

                  /// These booleans decide where to draw thicker borders
                  /// between 3x3 subgrids:
                  /// - A thick line after columns 2 and 5
                  /// - A thick line after rows 2 and 5
                  final isBoxBorderRight = (col + 1) % 3 == 0 && col != 8;
                  final isBoxBorderBottom = (row + 1) % 3 == 0 && row != 8;
                  
                  final bool isGiven = givens[index] != 0;
                  final bool isSelected = selectedIndex == index;

                  // Highlight row/col/box if a cell is selected.
                  final bool inSelectedRowColBox = selectedIndex != null
                      ? BoardRules.sharesRowColOrBox(index, selectedIndex!) : false;
                  
                  // Highlight same number if a cell is selected AND it has a number.
                  final int selectedValue = selectedIndex != null ? entries[selectedIndex!] : 0;

                  final bool isSameNumber = selectedValue != 0 && 
                      entries[index] == selectedValue && selectedIndex != null;
                  
                  final Set<int> conflictSet = selectedIndex != null ? BoardRules.conflictsForIndex(
                      index: selectedIndex!, entries: entries) : {};
                  
                  final bool isConflict = selectedIndex != null &&
                      (index == selectedIndex || conflictSet.contains(index));

                  return _Cell(
                    text: entries[index] == 0 ? '' : entries[index].toString(),
                    isGiven: isGiven,
                    isConflict: isConflict,
                    drawRightThick: isBoxBorderRight,
                    drawBottomThick: isBoxBorderBottom,
                    isSelected: isSelected,
                    isPeerHighlight: inSelectedRowColBox && !isSelected,
                    isSameNumberHighlight: isSameNumber && !isSelected,
                    onTap: () => onCellTap(index),
                    notesMask: notesMasks[index],
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Draws the thick outer border around the whole Sudoku board.
class _BoardBorder extends StatelessWidget {
  /// The widget inside the border (our GridView).
  final Widget child;
  const _BoardBorder({required this.child});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        // Outer border thickness of the entire board.
        border: Border.all(width: 2),
      ),
      child: child,
    );
  }
}

/// Renders a single tappable Sudoku cell.
/// - Draws thin borders between most cells
/// - Draws thicker borders between 3x3 subgrids
/// - Centers the text
/// Uses different background colors depending on selection/highlight state.
class _Cell extends StatelessWidget {
  /// What number to display in the cell.
  /// (In the real app this will be puzzle givens / user entries / notes.)
  final String text;

  /// Whether to draw a thick border on the right edge of this cell
  /// (used to separate 3x3 boxes).
  final bool drawRightThick;

  /// Whether to draw a thick border on the bottom edge of this cell
  /// (used to separate 3x3 boxes).
  final bool drawBottomThick;

  final bool isGiven;
  final bool isConflict;
  final bool isSelected;
  final bool isPeerHighlight;
  final bool isSameNumberHighlight;
  final int notesMask;

  final VoidCallback onTap;

  const _Cell({
    required this.text,
    required this.drawRightThick,
    required this.drawBottomThick,
    required this.isGiven,
    required this.isConflict,
    required this.isSelected,
    required this.isPeerHighlight,
    required this.isSameNumberHighlight,
    required this.onTap,
    required this.notesMask,
  });

  @override
  Widget build(BuildContext context) {
    /// Border for this cell.
    /// - Thin borders by default (0.5)
    /// - Thick borders at box boundaries (2)
    ///
    /// Note: left/top are always thin here, and the right/bottom vary.
    /// This is fine because each cell draws its own border.
    final border = Border(
      right: BorderSide(width: drawRightThick ? 2 : 0.5),
      bottom: BorderSide(width: drawBottomThick ? 2 : 0.5),
      left: const BorderSide(width: 0.5),
      top: const BorderSide(width: 0.5),
    );

    // titleLarge is a readable default size for the placeholder digits.
    final textStyle = isGiven
        ? Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)
        : Theme.of(context).textTheme.titleLarge;

    // Background highlight rules (simple and clear).
    // We avoid specifying custom colors; we use theme-based tints instead.
    final Color? background = switch ((isSelected, isConflict, isSameNumberHighlight, isPeerHighlight)) {
      (true, _, _, _) => Theme.of(context).colorScheme.primaryContainer,
      (false, true, _, _) => Theme.of(context).colorScheme.errorContainer,
      (false, false, true, _) => Theme.of(context).colorScheme.secondaryContainer,
      (false, false, false, true) => Theme.of(context).colorScheme.surfaceVariant,
      _ => null,
    };

    return Material(
      color: background ?? Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(border: border),
          alignment: Alignment.center,
          /// Conditional text rendering.
          child: text.isNotEmpty
              ? Text(text, style: textStyle)
              : _NotesGrid(notesMask: notesMask),
        ),
      ),
    );
  }
}

// Number pad widget
class _NumberPad extends StatelessWidget {
  final void Function(int n) onNumber;
  final VoidCallback onClear;
  final bool noteMode;
  final VoidCallback onToggleNoteMode;

  /// Number Pad constructor
  const _NumberPad({
    required this.onNumber,
    required this.onClear,
    required this.noteMode,
    required this.onToggleNoteMode,
  });

  /// Number Pad UI elements
  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      /// Children contains buttons
      children: [
        /// Creates a button for numbers 1 - 9.
        for (int n = 1; n <= 9; n++)
          _PadButton(
            label: n.toString(),
            onPressed: () => onNumber(n),
          ),
          /// Clear button
        _PadButton(
          label: 'Clear',
          onPressed: onClear,
        ),
        /// Notes toggle button
        _PadButton(
          label: noteMode ? 'Notes: ON' : 'Notes: OFF',
          onPressed: onToggleNoteMode,
        ),
      ],
    );
  }
}

// Number pad button component
class _PadButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _PadButton({
    required this.label,
    required this.onPressed,
  });

  @override Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onPressed,
      child: Text(label),
    );
  }
}

// Notes grid component
// Implements another grid inside of each cell.
class _NotesGrid extends StatelessWidget {
  final int notesMask;

  const _NotesGrid({required this.notesMask});

  bool _has(int digit) => (notesMask & (1 << digit)) != 0;

  @override
  Widget build(BuildContext context) {
    if (notesMask == 0) {
      return const SizedBox.shrink(); /// renders nothing if there are no notes
    }

    final style = Theme.of(context).textTheme.labelSmall;

    /// 3x3 mini-grid of digits 1..9.
    return Padding(
      padding: const EdgeInsets.all(2),
      child: GridView.count(
        crossAxisCount: 3,
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        children: [
          for (int d = 1; d <= 9; d++)
            Center(
              child: Text(_has(d) ? d.toString() : '', style: style),
            ),
        ],
      ),
    );
  }
}