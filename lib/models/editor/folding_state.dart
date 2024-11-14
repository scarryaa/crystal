import 'package:flutter/material.dart';

class Interval {
  final int start;
  final int end;

  Interval(this.start, this.end);

  bool contains(int point) => point > start && point <= end;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Interval &&
          runtimeType == other.runtimeType &&
          start == other.start &&
          end == other.end;

  @override
  int get hashCode => start.hashCode ^ end.hashCode;
}

class IntervalNode {
  Interval interval;
  int max;
  IntervalNode? left;
  IntervalNode? right;
  int height;

  IntervalNode(this.interval)
      : max = interval.end,
        height = 1;
}

class IntervalTree {
  IntervalNode? root;

  void add(Interval interval) {
    root = _insert(root, interval);
  }

  void remove(Interval interval) {
    root = _delete(root, interval);
  }

  void clear() {
    root = null;
  }

  bool containsPoint(int point) {
    return _searchPoint(root, point);
  }

  List<Interval> searchPoint(int point) {
    List<Interval> result = [];
    _searchPointAndCollect(root, point, result);
    return result;
  }

  IntervalNode? _insert(IntervalNode? node, Interval interval) {
    if (node == null) return IntervalNode(interval);

    if (interval.start < node.interval.start) {
      node.left = _insert(node.left, interval);
    } else {
      node.right = _insert(node.right, interval);
    }

    node.max = _max(
        node.interval.end, _max(_maxValue(node.left), _maxValue(node.right)));
    node.height = 1 + _max(_getHeight(node.left), _getHeight(node.right));

    return _balance(node);
  }

  IntervalNode? _delete(IntervalNode? node, Interval interval) {
    if (node == null) return null;

    if (interval == node.interval) {
      if (node.left == null) return node.right;
      if (node.right == null) return node.left;

      IntervalNode? temp = node.right;
      while (temp?.left != null) {
        temp = temp?.left;
      }
      node.interval = temp!.interval;
      node.right = _delete(node.right, temp.interval);
    } else if (interval.start < node.interval.start) {
      node.left = _delete(node.left, interval);
    } else {
      node.right = _delete(node.right, interval);
    }

    node.height = 1 + _max(_getHeight(node.left), _getHeight(node.right));
    node.max = _max(
        node.interval.end, _max(_maxValue(node.left), _maxValue(node.right)));

    return _balance(node);
  }

  bool _searchPoint(IntervalNode? node, int point) {
    if (node == null) return false;

    if (node.interval.contains(point)) return true;

    if (node.left != null && node.left!.max >= point) {
      return _searchPoint(node.left, point);
    }

    return _searchPoint(node.right, point);
  }

  void _searchPointAndCollect(
      IntervalNode? node, int point, List<Interval> result) {
    if (node == null) return;

    if (node.interval.contains(point)) {
      result.add(node.interval);
    }

    if (node.left != null && node.left!.max >= point) {
      _searchPointAndCollect(node.left, point, result);
    }

    _searchPointAndCollect(node.right, point, result);
  }

  IntervalNode _balance(IntervalNode node) {
    int balance = _getBalance(node);

    if (balance > 1) {
      if (_getBalance(node.left!) < 0) {
        node.left = _rotateLeft(node.left!);
      }
      return _rotateRight(node);
    }

    if (balance < -1) {
      if (_getBalance(node.right!) > 0) {
        node.right = _rotateRight(node.right!);
      }
      return _rotateLeft(node);
    }

    return node;
  }

  int _getBalance(IntervalNode node) {
    return _getHeight(node.left) - _getHeight(node.right);
  }

  IntervalNode _rotateLeft(IntervalNode x) {
    IntervalNode y = x.right!;
    IntervalNode? T2 = y.left;

    y.left = x;
    x.right = T2;

    x.height = _max(_getHeight(x.left), _getHeight(x.right)) + 1;
    y.height = _max(_getHeight(y.left), _getHeight(y.right)) + 1;

    x.max = _max(x.interval.end, _max(_maxValue(x.left), _maxValue(x.right)));
    y.max = _max(y.interval.end, _max(_maxValue(y.left), _maxValue(y.right)));

    return y;
  }

  IntervalNode _rotateRight(IntervalNode y) {
    IntervalNode x = y.left!;
    IntervalNode? T2 = x.right;

    x.right = y;
    y.left = T2;

    y.height = _max(_getHeight(y.left), _getHeight(y.right)) + 1;
    x.height = _max(_getHeight(x.left), _getHeight(x.right)) + 1;

    y.max = _max(y.interval.end, _max(_maxValue(y.left), _maxValue(y.right)));
    x.max = _max(x.interval.end, _max(_maxValue(x.left), _maxValue(x.right)));

    return x;
  }

  int _getHeight(IntervalNode? node) {
    if (node == null) return 0;
    return node.height;
  }

  int _maxValue(IntervalNode? node) {
    if (node == null) return 0;
    return node.max;
  }

  int _max(int a, int b) {
    return (a > b) ? a : b;
  }
}

class FoldingState extends ChangeNotifier {
  final IntervalTree _foldedRanges = IntervalTree();
  final Map<int, int> _foldStartToEnd = {};
  Map<int, int> get foldingRanges => Map.unmodifiable(_foldStartToEnd);

  bool isLineHidden(int line) {
    for (var entry in foldingRanges.entries) {
      if (line > entry.key && line <= entry.value) {
        return true;
      }
    }
    return false;
  }

  bool isLineFolded(int line) => _foldStartToEnd.containsKey(line);

  void fold(int startLine, int endLine) {
    _foldedRanges.add(Interval(startLine, endLine));
    _foldStartToEnd[startLine] = endLine;
    notifyListeners();
  }

  void unfold(int startLine) {
    if (_foldStartToEnd.containsKey(startLine)) {
      final endLine = _foldStartToEnd[startLine]!;
      _foldedRanges.remove(Interval(startLine, endLine));
      _foldStartToEnd.remove(startLine);
      notifyListeners();
    }
  }

  void toggleFold(int startLine, int endLine, {Map<int, int>? nestedFolds}) {
    if (isLineFolded(startLine)) {
      unfold(startLine);
      if (nestedFolds != null) {
        for (final entry in nestedFolds.entries) {
          fold(entry.key, entry.value);
        }
      }
    } else {
      fold(startLine, endLine);
    }
  }

  List<int> getVisibleLines(List<String> lines) {
    final visibleLines = <int>[];
    int currentLine = 0;

    while (currentLine < lines.length) {
      if (!isLineHidden(currentLine)) {
        visibleLines.add(currentLine);
        currentLine++;
      } else {
        // Find the next visible line by getting the end of the containing interval
        final containingIntervals = _foldedRanges.searchPoint(currentLine);
        if (containingIntervals.isNotEmpty) {
          // Jump to the end of the largest interval containing this point
          currentLine = containingIntervals
              .map((i) => i.end)
              .reduce((max, end) => end > max ? end : max);
        } else {
          currentLine++;
        }
      }
    }

    return visibleLines;
  }

  void clearFolds() {
    _foldedRanges.clear();
    _foldStartToEnd.clear();
    notifyListeners();
  }
}
