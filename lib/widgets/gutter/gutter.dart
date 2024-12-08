import 'dart:math';

import 'package:crystal/core/editor/editor_core.dart';
import 'package:crystal/widgets/gutter/gutter_painter.dart';
import 'package:flutter/material.dart';

class Gutter extends StatefulWidget {
  final EditorCore core;
  final ScrollController verticalScrollController;
  final double tabBarHeight;

  const Gutter({
    super.key,
    required this.core,
    required this.verticalScrollController,
    required this.tabBarHeight,
  });

  @override
  State<StatefulWidget> createState() => _GutterState();
}

class _GutterState extends State<Gutter> with AutomaticKeepAliveClientMixin {
  final int lineBuffer = 5;
  final ValueNotifier<bool> _scrollChanged = ValueNotifier<bool>(false);

  @override
  void initState() {
    super.initState();
    widget.verticalScrollController.addListener(_onScroll);
  }

  void _onScroll() {
    _scrollChanged.value = !_scrollChanged.value;
  }

  double _calculateWidgetHeight() {
    return max(
        MediaQuery.of(context).size.height - widget.tabBarHeight,
        (widget.core.lines.length * widget.core.config.lineHeight) +
            widget.core.config.heightPadding);
  }

  double _calculateWidgetWidth() {
    final textStyle = TextStyle(
      fontSize: widget.core.config.fontSize,
      fontFamily: widget.core.config.fontFamily,
    );

    final textPainter = TextPainter(
      text: TextSpan(
        text: widget.core.lines.length.toString(),
        style: textStyle,
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    return max(widget.core.config.minGutterWidth, textPainter.width + 40.0);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return ListenableBuilder(
        listenable: Listenable.merge([widget.core, _scrollChanged]),
        builder: (context, child) {
          final int firstVisibleLine =
              widget.verticalScrollController.hasClients
                  ? max(
                      0,
                      (widget.verticalScrollController.offset ~/
                              widget.core.config.lineHeight) -
                          lineBuffer)
                  : 0;

          final int lastVisibleLine = firstVisibleLine +
              (widget.verticalScrollController.hasClients
                  ? min(
                      widget.core.lines.length,
                      (widget.verticalScrollController.position
                                  .viewportDimension
                                  .toInt() ~/
                              widget.core.config.lineHeight) +
                          lineBuffer)
                  : min(
                      widget.core.lines.length,
                      (MediaQuery.of(context).size.height ~/
                              widget.core.config.lineHeight) +
                          lineBuffer));

          return ScrollConfiguration(
              behavior: const ScrollBehavior().copyWith(scrollbars: false),
              child: SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  controller: widget.verticalScrollController,
                  child: SizedBox(
                      width: _calculateWidgetWidth(),
                      height: _calculateWidgetHeight(),
                      child: CustomPaint(
                          painter: GutterPainter(
                        core: widget.core,
                        firstVisibleLine: firstVisibleLine,
                        lastVisibleLine: lastVisibleLine,
                        viewportHeight: MediaQuery.of(context).size.height +
                            widget.core.config.heightPadding +
                            (widget.verticalScrollController.hasClients
                                ? widget.verticalScrollController.offset
                                : 0),
                      )))));
        });
  }

  @override
  bool get wantKeepAlive => true;
}
