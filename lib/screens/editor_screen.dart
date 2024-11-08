import 'dart:io';
import 'dart:math';

import 'package:crystal/models/cursor.dart';
import 'package:crystal/models/editor/search_match.dart';
import 'package:crystal/models/selection.dart';
import 'package:crystal/services/editor/editor_config_service.dart';
import 'package:crystal/services/editor/editor_layout_service.dart';
import 'package:crystal/state/editor/editor_state.dart';
import 'package:crystal/widgets/editor/editor_control_bar_view.dart';
import 'package:crystal/widgets/editor/editor_tab_bar.dart';
import 'package:crystal/widgets/editor/editor_view.dart';
import 'package:crystal/widgets/file_explorer/file_explorer.dart';
import 'package:crystal/widgets/gutter/gutter.dart';
import 'package:crystal/widgets/status_bar/status_bar.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class EditorScreen extends StatefulWidget {
  final double horizontalPadding;
  final int verticalPaddingLines;
  final double lineHeightMultipler;

  const EditorScreen({
    super.key,
    required this.horizontalPadding,
    required this.verticalPaddingLines,
    required this.lineHeightMultipler,
  });

  @override
  State<StatefulWidget> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  late final EditorLayoutService _editorLayoutService;
  late final EditorConfigService _editorConfigService;
  final ScrollController _gutterScrollController = ScrollController();
  final ScrollController _editorVerticalScrollController = ScrollController();
  final ScrollController _editorHorizontalScrollController = ScrollController();
  final List<EditorState> _editors = [];
  String _searchTerm = '';
  List<SearchMatch> _searchTermMatches = [];
  int _currentSearchTermMatch = 0;
  bool _caseSensitiveActive = false;
  bool _wholeWordActive = false;
  bool _regexActive = false;

  int activeEditorIndex = 0;
  EditorState? get activeEditor =>
      _editors.isEmpty ? null : _editors[activeEditorIndex];

  Future<void> tapCallback(String path) async {
    final editorIndex = _editors.indexWhere((editor) => editor.path == path);
    if (editorIndex != -1) {
      setState(() {
        activeEditorIndex = editorIndex;
      });
    } else {
      String content = await File(path).readAsString();

      final newEditor = EditorState(
          editorConfigService: _editorConfigService,
          editorLayoutService: _editorLayoutService,
          resetGutterScroll: _resetGutterScroll,
          path: path);
      setState(() {
        _editors.add(newEditor);
        activeEditorIndex = _editors.length - 1;

        _editors[activeEditorIndex].openFile(content);
        _onSearchTermChanged(_searchTerm);
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _editorConfigService = EditorConfigService();
    _editorLayoutService = EditorLayoutService(
        fontFamily: 'IBM Plex Mono',
        fontSize: 14.0,
        horizontalPadding: widget.horizontalPadding,
        verticalPaddingLines: widget.verticalPaddingLines,
        lineHeightMultiplier: widget.lineHeightMultipler);
    _editorVerticalScrollController.addListener(_handleEditorScroll);
    _gutterScrollController.addListener(_handleGutterScroll);
    _editorConfigService.themeService.addListener(_onThemeChanged);
  }

  void _onThemeChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _handleEditorScroll() {
    if (_gutterScrollController.offset !=
        _editorVerticalScrollController.offset) {
      _gutterScrollController.jumpTo(_editorVerticalScrollController.offset);
      activeEditor!
          .updateVerticalScrollOffset(_editorVerticalScrollController.offset);
    }

    activeEditor!
        .updateHorizontalScrollOffset(_editorHorizontalScrollController.offset);
  }

  void _handleGutterScroll() {
    if (_editorVerticalScrollController.offset !=
        _gutterScrollController.offset) {
      _editorVerticalScrollController.jumpTo(_gutterScrollController.offset);
      activeEditor!.updateVerticalScrollOffset(_gutterScrollController.offset);
    }
  }

  void _scrollToCursor() {
    if (activeEditor == null) return;

    final cursorLine = activeEditor!.editorCursorManager.cursors.last.line;
    final lineHeight = _editorLayoutService.config.lineHeight;
    final viewportHeight =
        _editorVerticalScrollController.position.viewportDimension;
    final currentOffset = _editorVerticalScrollController.offset;
    final verticalPadding = _editorLayoutService.config.verticalPadding;

    final cursorY = cursorLine * lineHeight;
    if (cursorY < currentOffset + verticalPadding) {
      _editorVerticalScrollController.jumpTo(max(0, cursorY - verticalPadding));
    } else if (cursorY + lineHeight >
        currentOffset + viewportHeight - verticalPadding) {
      _editorVerticalScrollController
          .jumpTo(cursorY + lineHeight - viewportHeight + verticalPadding);
    }

    final cursorColumn = activeEditor!.editorCursorManager.cursors.last.column;
    final currentLine = activeEditor!.buffer.getLine(cursorLine);
    final textBeforeCursor = currentLine.substring(0, cursorColumn);
    final cursorX =
        textBeforeCursor.length * _editorLayoutService.config.charWidth;
    final viewportWidth =
        _editorHorizontalScrollController.position.viewportDimension;
    final currentHorizontalOffset = _editorHorizontalScrollController.offset;
    final horizontalPadding = _editorLayoutService.config.horizontalPadding;

    if (cursorX < currentHorizontalOffset + horizontalPadding) {
      _editorHorizontalScrollController
          .jumpTo(max(0, cursorX - horizontalPadding));
    } else if (cursorX + _editorLayoutService.config.charWidth >
        currentHorizontalOffset + viewportWidth - horizontalPadding) {
      _editorHorizontalScrollController.jumpTo(cursorX +
          _editorLayoutService.config.charWidth -
          viewportWidth +
          horizontalPadding);
    }

    activeEditor!
        .updateVerticalScrollOffset(_editorVerticalScrollController.offset);
    activeEditor!
        .updateHorizontalScrollOffset(_editorHorizontalScrollController.offset);
  }

  void _resetGutterScroll() {
    if (_gutterScrollController.hasClients) _gutterScrollController.jumpTo(0);
  }

  void onActiveEditorChanged(int index) {
    setState(() {
      activeEditorIndex = index;
      _editorVerticalScrollController
          .jumpTo(activeEditor!.scrollState.verticalOffset);
      _editorHorizontalScrollController
          .jumpTo(activeEditor!.scrollState.horizontalOffset);
      _onSearchTermChanged(_searchTerm);
    });
  }

  void onEditorClosed(int index) {
    setState(() {
      if (_editors[index].isPinned) {
        return;
      }

      _editors.removeAt(index);
      if (activeEditorIndex >= _editors.length) {
        activeEditorIndex = _editors.length - 1;
      }
    });
  }

  void onPin(int index) {
    setState(() {
      _editors[index].isPinned = !_editors[index].isPinned;

      if (_editors[index].isPinned) {
        int pinnedCount = _editors.where((e) => e.isPinned).length - 1;
        if (index > pinnedCount) {
          final editor = _editors.removeAt(index);
          _editors.insert(pinnedCount, editor);
          if (activeEditorIndex == index) {
            activeEditorIndex = pinnedCount;
          }
        }
      }
    });
  }

  void onReorder(int oldIndex, int newIndex) {
    setState(() {
      final movingEditor = _editors[oldIndex];
      final pinnedCount = _editors.where((e) => e.isPinned).length;

      // Prevent moving unpinned tabs before pinned ones
      if (!movingEditor.isPinned && newIndex < pinnedCount) {
        newIndex = pinnedCount;
      }

      // Prevent moving pinned tabs after unpinned ones
      if (movingEditor.isPinned && newIndex > pinnedCount - 1) {
        newIndex = pinnedCount - 1;
      }

      if (oldIndex < newIndex) {
        newIndex -= 1;
      }

      final item = _editors.removeAt(oldIndex);
      _editors.insert(newIndex, item);

      // Update activeEditorIndex
      if (activeEditorIndex == oldIndex) {
        activeEditorIndex = newIndex;
      } else if (activeEditorIndex > oldIndex &&
          activeEditorIndex <= newIndex) {
        activeEditorIndex--;
      } else if (activeEditorIndex < oldIndex &&
          activeEditorIndex >= newIndex) {
        activeEditorIndex++;
      }
    });
  }

  void _updateSearchMatches(String newTerm) {
    setState(() {
      _searchTerm = newTerm;

      if (activeEditor?.buffer.lines != null) {
        _searchTermMatches = findMatches(
          lines: activeEditor!.buffer.lines,
          searchTerm: newTerm,
          caseSensitive: _caseSensitiveActive,
          wholeWord: _wholeWordActive,
          useRegex: _regexActive,
        );
      }
    });
  }

  void _onSearchTermChanged(String newTerm) {
    setState(() {
      _searchTerm = newTerm;

      if (activeEditor?.buffer.lines != null) {
        _searchTermMatches = findMatches(
          lines: activeEditor!.buffer.lines,
          searchTerm: newTerm,
          caseSensitive: _caseSensitiveActive,
          wholeWord: _wholeWordActive,
          useRegex: _regexActive,
        );

        // Reset current match index when search term changes
        _currentSearchTermMatch = 0;

        // If there are matches, position cursor at the first match
        if (_searchTermMatches.isNotEmpty) {
          _positionCursorAtMatch(_searchTermMatches[0]);
        }
      } else {
        _searchTermMatches = [];
      }
      activeEditor!.clearSelection();
    });
  }

  List<SearchMatch> findMatches({
    required List<String> lines,
    required String searchTerm,
    required bool caseSensitive,
    required bool wholeWord,
    required bool useRegex,
  }) {
    if (searchTerm.isEmpty || lines.isEmpty) {
      return [];
    }

    final List<SearchMatch> matches = [];

    // Prepare regex pattern based on search options
    RegExp? pattern;
    try {
      if (useRegex) {
        pattern = RegExp(
          searchTerm,
          caseSensitive: caseSensitive,
          multiLine: true,
        );
      } else if (wholeWord) {
        // Escape special regex characters in the search term
        final escapedTerm = RegExp.escape(searchTerm);
        pattern = RegExp(
          r'\b' + escapedTerm + r'\b',
          caseSensitive: caseSensitive,
          multiLine: true,
        );
      } else {
        // Escape special regex characters in the search term
        final escapedTerm = RegExp.escape(searchTerm);
        pattern = RegExp(
          escapedTerm,
          caseSensitive: caseSensitive,
          multiLine: true,
        );
      }
    } catch (e) {
      // Handle invalid regex pattern
      print('Invalid regex pattern: $e');
      return [];
    }

    // Process each line
    for (int lineNumber = 0; lineNumber < lines.length; lineNumber++) {
      final line = lines[lineNumber];
      if (line.isEmpty) continue;

      // Find all matches in the current line
      final Iterable<RegExpMatch> lineMatches = pattern.allMatches(line);

      for (final match in lineMatches) {
        matches.add(SearchMatch(
          lineNumber: lineNumber,
          startIndex: match.start,
          length: match.end - match.start,
        ));
      }
    }

    return matches;
  }

  int getNextMatchIndex(int currentIndex, int totalMatches) {
    if (totalMatches == 0) return 0;
    return (currentIndex + 1) % totalMatches;
  }

  int getPreviousMatchIndex(int currentIndex, int totalMatches) {
    if (totalMatches == 0) return 0;
    return currentIndex > 0 ? currentIndex - 1 : totalMatches - 1;
  }

  void _nextSearchTerm() {
    if (_searchTermMatches.isEmpty) return;

    setState(() {
      _currentSearchTermMatch = getNextMatchIndex(
        _currentSearchTermMatch,
        _searchTermMatches.length,
      );

      // Position cursor at the current match
      _positionCursorAtMatch(_searchTermMatches[_currentSearchTermMatch]);
    });
  }

  void _previousSearchTerm() {
    if (_searchTermMatches.isEmpty) return;

    setState(() {
      _currentSearchTermMatch = getPreviousMatchIndex(
        _currentSearchTermMatch,
        _searchTermMatches.length,
      );

      // Position cursor at the current match
      _positionCursorAtMatch(_searchTermMatches[_currentSearchTermMatch]);
    });
  }

  void _positionCursorAtMatch(SearchMatch match) {
    if (activeEditor == null) return;

    final matchLine = match.lineNumber;
    final matchEndColumn = match.startIndex + match.length;

    // Update cursor position to end of match
    activeEditor!.editorCursorManager.clearAll();
    activeEditor!.editorCursorManager
        .addCursor(Cursor(matchLine, matchEndColumn));

    // Update selection to cover the entire match
    activeEditor!.editorSelectionManager.clearAll();
    activeEditor!.editorSelectionManager.addSelection(Selection(
      startLine: matchLine,
      startColumn: match.startIndex,
      endLine: matchLine,
      endColumn: matchEndColumn,
      anchorLine: matchLine,
      anchorColumn: match.startIndex,
    ));

    // Scroll to make the cursor visible
    _scrollToCursor();
  }

  void _toggleRegex(bool active) {
    setState(() {
      _regexActive = active;
      _onSearchTermChanged(_searchTerm);
    });
  }

  void _toggleWholeWord(bool active) {
    setState(() {
      _wholeWordActive = active;
      _onSearchTermChanged(_searchTerm);
    });
  }

  void _toggleCaseSensitive(bool active) {
    setState(() {
      _caseSensitiveActive = active;
      _onSearchTermChanged(_searchTerm);
    });
  }

  void _replaceNextMatch(String newTerm) {
    if (_searchTermMatches.isEmpty) return;

    activeEditor!.buffer.replace(
        _searchTermMatches[_currentSearchTermMatch].lineNumber,
        _searchTermMatches[_currentSearchTermMatch].startIndex,
        _searchTermMatches[_currentSearchTermMatch].length,
        newTerm);
    _onSearchTermChanged(_searchTerm);
  }

  void _replaceAllMatches(String newTerm) {
    if (_searchTermMatches.isEmpty) return;

    for (int i = 0; i < _searchTermMatches.length; i++) {
      activeEditor!.buffer.replace(
          _searchTermMatches[i].lineNumber,
          _searchTermMatches[i].startIndex,
          _searchTermMatches[i].length,
          newTerm);
    }
    _onSearchTermChanged(_searchTerm);
  }

  @override
  void dispose() {
    _gutterScrollController.removeListener(_handleEditorScroll);
    _gutterScrollController.removeListener(_handleGutterScroll);
    _gutterScrollController.dispose();
    _editorVerticalScrollController.dispose();
    _editorHorizontalScrollController.dispose();
    _editorConfigService.themeService.removeListener(_onThemeChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: activeEditor,
      child: Consumer<EditorState?>(
        builder: (context, state, _) {
          final gutterWidth = state?.getGutterWidth();

          return Material(
            child: Column(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      FileExplorer(
                        editorConfigService: _editorConfigService,
                        rootDir: '',
                        tapCallback: tapCallback,
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            if (_editors.isNotEmpty)
                              EditorTabBar(
                                onPin: onPin,
                                editorConfigService: _editorConfigService,
                                editors: _editors,
                                activeEditorIndex: activeEditorIndex,
                                onActiveEditorChanged: onActiveEditorChanged,
                                onEditorClosed: onEditorClosed,
                                onReorder: onReorder,
                              ),
                            if (_editors.isNotEmpty)
                              EditorControlBarView(
                                editorConfigService: _editorConfigService,
                                filePath: activeEditor!.path,
                                searchTermChanged: _onSearchTermChanged,
                                nextSearchTerm: _nextSearchTerm,
                                previousSearchTerm: _previousSearchTerm,
                                currentSearchTermMatch: _currentSearchTermMatch,
                                totalSearchTermMatches:
                                    _searchTermMatches.length,
                                isCaseSensitiveActive: _caseSensitiveActive,
                                isRegexActive: _regexActive,
                                isWholeWordActive: _wholeWordActive,
                                toggleRegex: _toggleRegex,
                                toggleWholeWord: _toggleWholeWord,
                                toggleCaseSensitive: _toggleCaseSensitive,
                                replaceNextMatch: _replaceNextMatch,
                                replaceAllMatches: _replaceAllMatches,
                              ),
                            Expanded(
                              child: Container(
                                color: _editorConfigService
                                            .themeService.currentTheme !=
                                        null
                                    ? _editorConfigService
                                        .themeService.currentTheme!.background
                                    : Colors.white,
                                child: Row(
                                  children: [
                                    if (_editors.isNotEmpty)
                                      Gutter(
                                        editorConfigService:
                                            _editorConfigService,
                                        editorLayoutService:
                                            _editorLayoutService,
                                        editorState: state!,
                                        verticalScrollController:
                                            _gutterScrollController,
                                      ),
                                    Expanded(
                                      child: _editors.isNotEmpty
                                          ? EditorView(
                                              editorConfigService:
                                                  _editorConfigService,
                                              editorLayoutService:
                                                  _editorLayoutService,
                                              state: state!,
                                              searchTerm: _searchTerm,
                                              searchTermMatches:
                                                  _searchTermMatches,
                                              currentSearchTermMatch:
                                                  _currentSearchTermMatch,
                                              onSearchTermChanged:
                                                  _updateSearchMatches,
                                              scrollToCursor: _scrollToCursor,
                                              gutterWidth: gutterWidth!,
                                              verticalScrollController:
                                                  _editorVerticalScrollController,
                                              horizontalScrollController:
                                                  _editorHorizontalScrollController,
                                            )
                                          : Container(
                                              color: _editorConfigService
                                                          .themeService
                                                          .currentTheme !=
                                                      null
                                                  ? _editorConfigService
                                                      .themeService
                                                      .currentTheme!
                                                      .background
                                                  : Colors.white),
                                    )
                                  ],
                                ),
                              ),
                            )
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                StatusBar(
                  editorConfigService: _editorConfigService,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
