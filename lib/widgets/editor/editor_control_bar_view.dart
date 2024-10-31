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
  final bool isCaseSensitiveActive;
  final bool isWholeWordActive;
  final bool isRegexActive;

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
  });

  @override
  State<StatefulWidget> createState() => _EditorControlBarViewState();
}

class _EditorControlBarViewState extends State<EditorControlBarView> {
  bool _isSearchActive = false;
  bool _isReplaceActive = false;
  bool _searchHovered = false;
  bool _replaceHovered = false;
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _replaceController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    _replaceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Container(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          height: 36,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(
              bottom: BorderSide(
                  color: !_isSearchActive
                      ? Colors.grey[200]!
                      : Colors.transparent),
            ),
          ),
          child: Row(children: [
            _buildFilePath(widget.filePath),
            const Spacer(),
            _buildSearchToggle(),
          ])),
      if (_isSearchActive) _buildSearchPane(),
      if (_isReplaceActive) _buildReplacePane(),
    ]);
  }

  Widget _buildFilePath(String path) {
    return Text(
      path,
      style: const TextStyle(
        fontFamily: 'IBM Plex Sans',
        fontSize: 14,
        color: Colors.black87,
      ),
      overflow: TextOverflow.ellipsis,
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
              child: Container(
                height: 24,
                width: 28,
                decoration: BoxDecoration(
                  color:
                      value ? Colors.blue.withOpacity(0.1) : Colors.transparent,
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Center(
                  child: DefaultTextStyle(
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: value ? Colors.blue : Colors.black54,
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
      child: GestureDetector(
        onTap: onPress,
        child: Container(
          height: 24,
          width: 24,
          decoration: BoxDecoration(
            color: (hovered != null && hovered)
                ? Colors.grey[200]
                : Colors.transparent,
            borderRadius: const BorderRadius.all(Radius.circular(4)),
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
        color: _isSearchActive ? Colors.blue : Colors.black54,
        size: 16,
      ),
      (_) => setState(() => _searchHovered = true),
      (_) => setState(() => _searchHovered = false),
      _searchHovered,
      () => setState(() => _isSearchActive = !_isSearchActive),
    );
  }

  Widget _buildReplaceToggle() {
    return _buildToggleButton(
      Icon(
        Icons.find_replace,
        color: _isReplaceActive ? Colors.blue : Colors.black54,
        size: 16,
      ),
      (_) => setState(() => _replaceHovered = true),
      (_) => setState(() => _replaceHovered = false),
      _replaceHovered,
      () => setState(() => _isReplaceActive = !_isReplaceActive),
    );
  }

  Widget _buildSearchPane() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      height: 36,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(
              color: _isReplaceActive ? Colors.transparent : Colors.grey[200]!),
        ),
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Row(children: [
          Row(children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 450),
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
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4.0),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4.0),
                    borderSide: BorderSide(color: Colors.grey[300]!),
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
                style: const TextStyle(
                  fontSize: 14,
                  fontFamily: 'IBM Plex Sans',
                ),
              ),
            ),
          ]),
          _buildReplaceToggle(),
          _buildToggleButton(const Icon(Icons.arrow_left), null, null, null,
              widget.previousSearchTerm),
          _buildToggleButton(const Icon(Icons.arrow_right), null, null, null,
              widget.nextSearchTerm),
          _buildCurrentSearchMatchLabel(),
        ]),
      ),
    );
  }

  Widget _buildCurrentSearchMatchLabel() {
    var currentSearchTermMatch =
        widget.currentSearchTermMatch + widget.totalSearchTermMatches == 0
            ? 0
            : 1;
    var totalSearchTermMatches = widget.totalSearchTermMatches;
    return Text('$currentSearchTermMatch/$totalSearchTermMatches');
  }

  Widget _buildReplacePane() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      height: 36,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey[200]!),
        ),
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 450),
          child: TextField(
            controller: _replaceController,
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Replace',
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4.0),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4.0),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4.0),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
            ),
            style: const TextStyle(
              fontSize: 14,
              fontFamily: 'IBM Plex Sans',
            ),
          ),
        ),
      ),
    );
  }
}
