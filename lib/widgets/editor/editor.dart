import 'dart:math';

import 'package:crystal/core/buffer_manager.dart';
import 'package:crystal/core/cursor_manager.dart';
import 'package:crystal/core/editor/editor_config.dart';
import 'package:crystal/core/editor/editor_core.dart';
import 'package:crystal/core/selection_manager.dart';
import 'package:crystal/widgets/editor/editor_input_manager.dart';
import 'package:crystal/widgets/editor/editor_painter.dart';
import 'package:flutter/material.dart';

class Editor extends StatefulWidget {
  final ScrollController horizontalScrollController;
  final ScrollController verticalScrollController;
  final void Function(EditorCore)? onCoreInitialized;

  const Editor({
    super.key,
    this.onCoreInitialized,
    required this.horizontalScrollController,
    required this.verticalScrollController,
  });

  @override
  State<StatefulWidget> createState() => _EditorState();
}

class _EditorState extends State<Editor> {
  late final EditorCore _core;
  final EditorInputManager editorInputManager = EditorInputManager();
  final ValueNotifier<bool> _scrollChanged = ValueNotifier<bool>(false);
  final lineBuffer = 5;

  @override
  void initState() {
    super.initState();
    final bufferManager = BufferManager();
    _core = EditorCore(
      bufferManager: bufferManager,
      selectionManager: SelectionManager(),
      cursorManager: CursorManager(bufferManager),
      editorConfig: EditorConfig(),
    );

    _core.bufferManager.cursorManager = _core.cursorManager;
    widget.onCoreInitialized?.call(_core);

    widget.verticalScrollController.addListener(_onScroll);
    widget.horizontalScrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    widget.verticalScrollController.removeListener(_onScroll);
    widget.horizontalScrollController.removeListener(_onScroll);
    _scrollChanged.dispose();
    super.dispose();
  }

  void _onScroll() {
    _scrollChanged.value = !_scrollChanged.value;
  }

  double _calculateWidgetHeight() {
    return max(
        MediaQuery.of(context).size.height,
        (_core.lines.length * _core.config.lineHeight) +
            _core.config.heightPadding);
  }

  double _calculateWidgetWidth() {
    return max(MediaQuery.of(context).size.width - _core.config.minGutterWidth,
        _calculateMaxLineWidth() + _core.config.widthPadding);
  }

  double _calculateMaxLineWidth() {
    return _core.lines.fold(
        0,
        (maxWidth, element) =>
            max(maxWidth, element.length * _core.config.characterWidth));
  }

  Future<KeyEventResult> handleKeyEventAsync(
      FocusNode node, KeyEvent keyEvent) {
    return editorInputManager.handleKeyEvent(_core, keyEvent);
  }

  KeyEventResult handleKeyEvent(FocusNode node, KeyEvent keyEvent) {
    handleKeyEventAsync(node, keyEvent);

    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    return ScrollbarTheme(
        data: ScrollbarThemeData(
          thickness: WidgetStateProperty.resolveWith((states) {
            return 8;
          }),
          thumbColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) {
              return Colors.grey[500];
            }
            if (states.contains(WidgetState.hovered)) {
              return Colors.grey[700];
            }
            return Colors.grey[600];
          }),
          radius: Radius.zero,
          minThumbLength: 50,
          crossAxisMargin: 0,
        ),
        child: ListenableBuilder(
            listenable: Listenable.merge([_core, _scrollChanged]),
            builder: (context, child) {
              final int firstVisibleLine =
                  widget.verticalScrollController.hasClients
                      ? max(
                          0,
                          (widget.verticalScrollController.offset ~/
                                  _core.config.lineHeight) -
                              lineBuffer)
                      : 0;

              final int lastVisibleLine = firstVisibleLine +
                  (widget.verticalScrollController.hasClients
                      ? min(
                          _core.lines.length,
                          (widget.verticalScrollController.position
                                      .viewportDimension ~/
                                  _core.config.lineHeight) +
                              lineBuffer)
                      : min(
                          _core.lines.length,
                          (MediaQuery.of(context).size.height ~/
                                  _core.config.lineHeight) +
                              lineBuffer));

              return Scrollbar(
                  controller: widget.verticalScrollController,
                  interactive: true,
                  child: Scrollbar(
                      controller: widget.horizontalScrollController,
                      interactive: true,
                      notificationPredicate: (notification) =>
                          notification.depth == 1,
                      child: SingleChildScrollView(
                          scrollDirection: Axis.vertical,
                          controller: widget.verticalScrollController,
                          child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              controller: widget.horizontalScrollController,
                              child: SizedBox(
                                  width: _calculateWidgetWidth(),
                                  height: _calculateWidgetHeight(),
                                  child: Focus(
                                      autofocus: true,
                                      onKeyEvent: (node, keyEvent) =>
                                          handleKeyEvent(node, keyEvent),
                                      child: CustomPaint(
                                          painter: EditorPainter(
                                        core: _core,
                                        firstVisibleLine: firstVisibleLine,
                                        lastVisibleLine: lastVisibleLine,
                                        viewportHeight: MediaQuery.of(context)
                                                .size
                                                .height +
                                            _core.config.heightPadding +
                                            (widget.verticalScrollController
                                                    .hasClients
                                                ? widget
                                                    .verticalScrollController
                                                    .offset
                                                : 0),
                                      ))))))));
            }));
  }
}
