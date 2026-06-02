class HistoryManager<T> {
  final List<T> _undoStack = [];
  final List<T> _redoStack = [];
  final int maxHistorySize;

  HistoryManager({this.maxHistorySize = 50});

  bool get canUndo => _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;

  int get undoCount => _undoStack.length;
  int get redoCount => _redoStack.length;

  void push(T state) {
    _undoStack.add(state);
    _redoStack.clear();

    if (_undoStack.length > maxHistorySize) {
      _undoStack.removeAt(0);
    }
  }

  T? undo(T currentState) {
    if (!canUndo) return null;

    _redoStack.add(currentState);
    return _undoStack.removeLast();
  }

  T? redo(T currentState) {
    if (!canRedo) return null;

    _undoStack.add(currentState);
    return _redoStack.removeLast();
  }

  void clear() {
    _undoStack.clear();
    _redoStack.clear();
  }
}
