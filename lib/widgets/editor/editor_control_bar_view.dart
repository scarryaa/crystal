import 'package:crystal/models/editor/breadcrumb_item.dart';
import 'package:crystal/services/editor/breadcrumb_generator.dart';
import 'package:crystal/services/editor/editor_config_service.dart';
import 'package:crystal/state/editor/editor_state.dart';
import 'package:crystal/widgets/editor/symbol_popup.dart';
import 'package:flutter/material.dart';

class EditorControlBarView extends StatefulWidget {
  final String filePath;
  final int currentSearchTermMatch;
  final int totalSearchTermMatches;
  final Function(String newTerm) searchTermChanged;
  final Function() previousSearchTerm;
  final Function() nextSearchTerm;
  final Function(bool active) toggleCaseSensitive;
  final Function(bool active) toggleRegex;
  final Function(bool active) toggleWholeWord;
  final Function(String newTerm) replaceNextMatch;
  final Function(String newTerm) replaceAllMatches;
  final bool isCaseSensitiveActive;
  final bool isWholeWordActive;
  final bool isRegexActive;
  final EditorConfigService editorConfigService;
  final EditorState editorState;
  final Function() scrollToCursor;

  const EditorControlBarView({
    super.key,
    required this.filePath,
    required this.searchTermChanged,
    required this.currentSearchTermMatch,
    required this.totalSearchTermMatches,
    required this.previousSearchTerm,
    required this.nextSearchTerm,
    required this.isCaseSensitiveActive,
    required this.isWholeWordActive,
    required this.isRegexActive,
    required this.toggleRegex,
    required this.toggleWholeWord,
    required this.toggleCaseSensitive,
    required this.replaceNextMatch,
    required this.replaceAllMatches,
    required this.editorConfigService,
    required this.editorState,
    required this.scrollToCursor,
  });

  @override
  State<StatefulWidget> createState() => _EditorControlBarViewState();
}

class _EditorControlBarViewState extends State<EditorControlBarView> {
  bool _isSearchActive = false;
  bool _isReplaceActive = false;
  bool _searchHovered = false;
  bool _replaceHovered = false;
  bool _replaceNextHovered = false;
  bool _replaceAllHovered = false;
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _replaceController = TextEditingController();
  List<BreadcrumbItem> _breadcrumbs = [];
  final BreadcrumbGenerator _breadcrumbGenerator = BreadcrumbGenerator();

  @override
  void initState() {
    super.initState();
    widget.editorState.editorCursorManager.onCursorChange = _updateBreadcrumbs;
    _populateSymbols();
  }

  void _populateSymbols() {
    if (!widget.filePath.toLowerCase().endsWith('.dart')) {
      return;
    }

    String sourceCode = widget.editorState.buffer.lines.join('\n');
    _breadcrumbGenerator.getAllSymbols(sourceCode);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _replaceController.dispose();
    widget.editorState.editorCursorManager.onCursorChange = null;
    super.dispose();
  }

  void _updateBreadcrumbs(int line, int column) {
    if (!widget.filePath.toLowerCase().endsWith('.dart')) {
      setState(() {
        _breadcrumbs = [];
      });
      return;
    }

    String sourceCode = widget.editorState.buffer.lines.join('\n');
    int cursorOffset = _calculateCursorOffset(sourceCode, line, column);

    setState(() {
      _breadcrumbs =
          _breadcrumbGenerator.generateBreadcrumbs(sourceCode, cursorOffset);
    });
  }

  int _calculateCursorOffset(String sourceCode, int line, int column) {
    List<String> lines = sourceCode.split('\n');
    int offset = 0;
    for (int i = 0; i < line; i++) {
      offset += lines[i].length + 1; // +1 for newline character
    }
    return offset + column;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          height: widget.editorConfigService.config.uiFontSize * 3.0,
          decoration: BoxDecoration(
            color: widget.editorConfigService.themeService.currentTheme != null
                ? widget
                    .editorConfigService.themeService.currentTheme!.background
                : Colors.white,
            border: Border(
              bottom: BorderSide(
                color: !_isSearchActive
                    ? widget.editorConfigService.themeService.currentTheme !=
                            null
                        ? widget.editorConfigService.themeService.currentTheme!
                            .border
                        : Colors.grey[200]!
                    : Colors.transparent,
              ),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: _buildFilePath(widget.filePath),
              ),
              _buildSearchToggle(),
            ],
          ),
        ),
        if (_isSearchActive) _buildSearchPane(),
        if (_isSearchActive && _isReplaceActive) _buildReplacePane(),
      ],
    );
  }

  Widget _buildFilePath(String path) {
    return Row(
      children: [
        Flexible(
          child: Text(
            (path.isEmpty || path.substring(0, 6) == '__temp')
                ? 'untitled'
                : path,
            style: TextStyle(
              fontSize: widget.editorConfigService.config.uiFontSize,
              color: widget.editorConfigService.themeService.currentTheme !=
                      null
                  ? widget.editorConfigService.themeService.currentTheme!.text
                  : Colors.black87,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Flexible(
          flex: 2,
          child: _buildBreadcrumbs(),
        ),
      ],
    );
  }

  Widget _buildSearchOptionButton({
    required bool value,
    required ValueChanged<bool> onChanged,
    required String tooltip,
    required Widget child,
  }) {
    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 2.0),
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Tooltip(
            message: tooltip,
            child: GestureDetector(
              onTap: () => onChanged(!value),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                height: widget.editorConfigService.config.uiFontSize * 1.5,
                width: widget.editorConfigService.config.uiFontSize * 1.5,
                decoration: BoxDecoration(
                  color: value
                      ? widget.editorConfigService.themeService.currentTheme!
                          .primary
                          .withOpacity(0.2)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: value
                        ? widget.editorConfigService.themeService.currentTheme!
                            .primary
                            .withOpacity(0.3)
                        : Colors.transparent,
                  ),
                ),
                child: Center(
                  child: DefaultTextStyle(
                    style: TextStyle(
                      fontSize: widget.editorConfigService.config.uiFontSize,
                      fontWeight: FontWeight.w500,
                      color: value
                          ? widget.editorConfigService.themeService
                              .currentTheme!.primary
                          : widget.editorConfigService.themeService
                              .currentTheme!.text,
                    ),
                    child: child,
                  ),
                ),
              ),
            ),
          ),
        ));
  }

  Widget _buildToggleButton(Widget icon, Function(dynamic)? onEnter,
      Function(dynamic)? onExit, bool? hovered, VoidCallback onPress) {
    return MouseRegion(
      onEnter: onEnter,
      onExit: onExit,
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onPress,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: widget.editorConfigService.config.uiFontSize * 2,
          width: widget.editorConfigService.config.uiFontSize * 2,
          decoration: BoxDecoration(
            color: (hovered != null && hovered)
                ? widget.editorConfigService.themeService.currentTheme!
                    .backgroundLight
                    .withOpacity(0.2)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: (hovered != null && hovered)
                  ? widget.editorConfigService.themeService.currentTheme!.border
                      .withOpacity(0.3)
                  : Colors.transparent,
            ),
          ),
          child: Center(child: icon),
        ),
      ),
    );
  }

  Widget _buildSearchToggle() {
    return _buildToggleButton(
      Icon(
        Icons.search,
        color: _isSearchActive
            ? widget.editorConfigService.themeService.currentTheme!.primary
            : widget.editorConfigService.themeService.currentTheme!.text,
        size: widget.editorConfigService.config.uiFontSize,
      ),
      (_) => setState(() => _searchHovered = true),
      (_) => setState(() => _searchHovered = false),
      _searchHovered || _isSearchActive,
      () => setState(() {
        _isSearchActive = !_isSearchActive;
        if (!_isSearchActive) {
          _isReplaceActive = false;
          widget.searchTermChanged('');
        } else {
          if (_searchController.text.isNotEmpty) {
            widget.searchTermChanged(_searchController.text);
          }
        }
      }),
    );
  }

  Widget _buildReplaceToggle() {
    return _buildToggleButton(
      Icon(
        Icons.find_replace,
        color: _isReplaceActive
            ? widget.editorConfigService.themeService.currentTheme!.primary
            : widget.editorConfigService.themeService.currentTheme!.text,
        size: widget.editorConfigService.config.uiFontSize,
      ),
      (_) => setState(() => _replaceHovered = true),
      (_) => setState(() => _replaceHovered = false),
      _replaceHovered || _isReplaceActive,
      () => setState(() => _isReplaceActive = !_isReplaceActive),
    );
  }

  Widget _buildReplaceActionButton({
    required String text,
    required VoidCallback onPressed,
    bool? hovered,
    Function(dynamic)? onEnter,
    Function(dynamic)? onExit,
  }) {
    return _buildToggleButton(
      Text(
        text,
        style: TextStyle(
          fontSize: widget.editorConfigService.config.uiFontSize,
          fontWeight: FontWeight.w500,
          color: widget.editorConfigService.themeService.currentTheme!.text,
        ),
      ),
      onEnter,
      onExit,
      hovered,
      onPressed,
    );
  }

  Widget _buildSearchPane() {
    return Container(
      padding: const EdgeInsets.fromLTRB(6.0, 0.0, 6.0, 4.0),
      height: widget.editorConfigService.config.uiFontSize * 2,
      decoration: BoxDecoration(
        color: widget.editorConfigService.themeService.currentTheme!.background,
        border: Border(
          bottom: BorderSide(
              color: _isReplaceActive
                  ? Colors.transparent
                  : widget
                      .editorConfigService.themeService.currentTheme!.border),
        ),
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Row(children: [
          Row(children: [
            ConstrainedBox(
              constraints: BoxConstraints(
                  maxWidth:
                      widget.editorConfigService.config.uiFontSize * 30.0),
              child: TextField(
                controller: _searchController,
                onChanged: widget.searchTermChanged,
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'Search',
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8.0, vertical: 8.0),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4.0),
                    borderSide: BorderSide(
                        color: widget.editorConfigService.themeService
                            .currentTheme!.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4.0),
                    borderSide: BorderSide(
                        color: widget.editorConfigService.themeService
                            .currentTheme!.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4.0),
                    borderSide: BorderSide(
                        color: widget.editorConfigService.themeService
                            .currentTheme!.border),
                  ),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildSearchOptionButton(
                        value: widget.isCaseSensitiveActive,
                        onChanged: (value) => setState(() {
                          widget.toggleCaseSensitive(value);
                        }),
                        tooltip: 'Match Case',
                        child: const Text('Aa'),
                      ),
                      _buildSearchOptionButton(
                        value: widget.isWholeWordActive,
                        onChanged: (value) => setState(() {
                          widget.toggleWholeWord(value);
                        }),
                        tooltip: 'Match Whole Word',
                        child: const Text('ab'),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(right: 3.0),
                        child: _buildSearchOptionButton(
                          value: widget.isRegexActive,
                          onChanged: (value) => setState(() {
                            widget.toggleRegex(value);
                          }),
                          tooltip: 'Use Regular Expression',
                          child: const Text('.*'),
                        ),
                      )
                    ],
                  ),
                ),
                style: TextStyle(
                  fontSize: widget.editorConfigService.config.uiFontSize,
                  color: widget
                      .editorConfigService.themeService.currentTheme!.text,
                ),
              ),
            ),
          ]),
          _buildReplaceToggle(),
          _buildToggleButton(
              Icon(
                Icons.arrow_left,
                size: widget.editorConfigService.config.uiFontSize * 1.25,
                color:
                    widget.editorConfigService.themeService.currentTheme!.text,
              ),
              null,
              null,
              null,
              widget.previousSearchTerm),
          _buildToggleButton(
              Icon(
                size: widget.editorConfigService.config.uiFontSize * 1.25,
                Icons.arrow_right,
                color:
                    widget.editorConfigService.themeService.currentTheme!.text,
              ),
              null,
              null,
              null,
              widget.nextSearchTerm),
          _buildCurrentSearchMatchLabel(),
        ]),
      ),
    );
  }

  Widget _buildCurrentSearchMatchLabel() {
    var currentSearchTermMatch = widget.currentSearchTermMatch +
        (widget.totalSearchTermMatches == 0 ? 0 : 1);
    var totalSearchTermMatches = widget.totalSearchTermMatches;
    return Text(
      '$currentSearchTermMatch/$totalSearchTermMatches',
      style: TextStyle(
        color: widget.editorConfigService.themeService.currentTheme!.text,
        fontSize: widget.editorConfigService.config.uiFontSize,
      ),
    );
  }

  Widget _buildReplacePane() {
    return Container(
      padding: const EdgeInsets.fromLTRB(6.0, 0.0, 6.0, 5.0),
      height: widget.editorConfigService.config.uiFontSize * 2.0,
      decoration: BoxDecoration(
        color: widget.editorConfigService.themeService.currentTheme!.background,
        border: Border(
          bottom: BorderSide(
              color:
                  widget.editorConfigService.themeService.currentTheme!.border),
        ),
      ),
      child: Row(children: [
        Align(
          alignment: Alignment.centerLeft,
          child: ConstrainedBox(
            constraints: BoxConstraints(
                maxWidth: widget.editorConfigService.config.uiFontSize * 30.0),
            child: TextField(
              controller: _replaceController,
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Replace',
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4.0),
                  borderSide: BorderSide(
                      color: widget.editorConfigService.themeService
                          .currentTheme!.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4.0),
                  borderSide: BorderSide(
                      color: widget.editorConfigService.themeService
                          .currentTheme!.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4.0),
                  borderSide: BorderSide(
                      color: widget.editorConfigService.themeService
                          .currentTheme!.border),
                ),
              ),
              style: TextStyle(
                fontSize: widget.editorConfigService.config.uiFontSize,
                color:
                    widget.editorConfigService.themeService.currentTheme!.text,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        _buildReplaceActionButton(
          text: '1↓',
          onPressed: () =>
              widget.replaceNextMatch(_replaceController.value.text),
          hovered: _replaceNextHovered,
          onEnter: (_) => setState(() => _replaceNextHovered = true),
          onExit: (_) => setState(() => _replaceNextHovered = false),
        ),
        _buildReplaceActionButton(
          text: 'all',
          onPressed: () =>
              widget.replaceAllMatches(_replaceController.value.text),
          hovered: _replaceAllHovered,
          onEnter: (_) => setState(() => _replaceAllHovered = true),
          onExit: (_) => setState(() => _replaceAllHovered = false),
        ),
      ]),
    );
  }

  Widget _buildBreadcrumbs() {
    if (!widget.filePath.toLowerCase().endsWith('.dart')) {
      return const SizedBox.shrink();
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(width: 8),
          for (int i = 0; i < _breadcrumbs.length; i++)
            _buildBreadcrumbItem(_breadcrumbs[i].type, _breadcrumbs[i].name,
                isLast: i == _breadcrumbs.length - 1),
        ],
      ),
    );
  }

  Widget _buildBreadcrumbItem(String type, String name,
      {required bool isLast}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: () {
            _showSymbolPopup(context, type);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  type,
                  style: TextStyle(
                    fontSize: widget.editorConfigService.config.uiFontSize,
                    color: widget
                        .editorConfigService.themeService.currentTheme?.text
                        .withOpacity(0.5),
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  name,
                  style: TextStyle(
                    fontSize: widget.editorConfigService.config.uiFontSize,
                    color: widget
                        .editorConfigService.themeService.currentTheme?.text
                        .withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (!isLast)
          Icon(
            Icons.chevron_right,
            size: widget.editorConfigService.config.uiFontSize,
            color: widget.editorConfigService.themeService.currentTheme?.text
                .withOpacity(0.5),
          ),
      ],
    );
  }

  void _showSymbolPopup(BuildContext context, String type) {
    final RenderBox button = context.findRenderObject() as RenderBox;
    final Offset topLeft = button.localToGlobal(Offset.zero);

    List<BreadcrumbItem> symbols = _getSymbolsOfType(type);

    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        topLeft.dx,
        topLeft.dy + button.size.height,
        topLeft.dx + button.size.width,
        topLeft.dy + button.size.height + 10,
      ),
      items: [
        PopupMenuItem(
          child: SymbolPopup(
            symbols: symbols,
            onSymbolSelected: _jumpToSymbol,
          ),
        ),
      ],
    );
  }

  List<BreadcrumbItem> _getSymbolsOfType(String type) {
    String sourceCode = widget.editorState.buffer.lines.join('\n');
    return _breadcrumbGenerator.getAllSymbols(sourceCode);
  }

  void _jumpToSymbol(BreadcrumbItem symbol) {
    widget.editorState.editorCursorManager
        .moveCursor(symbol.line - 1, symbol.column - 1);
    widget.scrollToCursor();
  }
}
