import 'package:crystal/services/editor/editor_config_service.dart';
import 'package:flutter/material.dart';

class ResizableSplitContainer extends StatefulWidget {
  final List<Widget> children;
  final Axis direction;
  final List<double> initialSizes;
  final void Function(List<double>)? onSizesChanged;
  final EditorConfigService editorConfigService;

  const ResizableSplitContainer({
    super.key,
    required this.children,
    required this.direction,
    required this.initialSizes,
    required this.editorConfigService,
    this.onSizesChanged,
  });

  @override
  State<ResizableSplitContainer> createState() =>
      _ResizableSplitContainerState();
}

class _ResizableSplitContainerState extends State<ResizableSplitContainer> {
  late List<double> sizes;
  double? dragStart;
  int? draggingDivider;

  @override
  void initState() {
    super.initState();
    // Initialize sizes with equal distribution if not provided
    sizes = widget.initialSizes.isEmpty
        ? List.filled(widget.children.length, 1.0 / widget.children.length)
        : List.from(widget.initialSizes);
  }

  void _handleDragStart(DragStartDetails details, int dividerIndex) {
    setState(() {
      dragStart = widget.direction == Axis.horizontal
          ? details.globalPosition.dx
          : details.globalPosition.dy;
      draggingDivider = dividerIndex;
    });
  }

  void _handleDragUpdate(DragUpdateDetails details, int dividerIndex) {
    if (draggingDivider == null) return;

    final isHorizontal = widget.direction == Axis.horizontal;
    final delta = isHorizontal ? details.delta.dx : details.delta.dy;
    final RenderBox box = context.findRenderObject() as RenderBox;
    final totalSize = isHorizontal ? box.size.width : box.size.height;
    final deltaPercent = delta / totalSize;

    const minSize = 0.1;
    if (sizes[dividerIndex] + deltaPercent >= minSize &&
        sizes[dividerIndex + 1] - deltaPercent >= minSize) {
      setState(() {
        sizes[dividerIndex] += deltaPercent;
        sizes[dividerIndex + 1] -= deltaPercent;
      });
      widget.onSizesChanged?.call(sizes);
    }
  }

  void _handleDragEnd(DragEndDetails details) {
    setState(() {
      dragStart = null;
      draggingDivider = null;
    });
  }

  Widget _buildDivider(int index) {
    return MouseRegion(
      cursor: widget.direction == Axis.horizontal
          ? SystemMouseCursors.resizeColumn
          : SystemMouseCursors.resizeRow,
      child: GestureDetector(
        onHorizontalDragStart: widget.direction == Axis.horizontal
            ? (details) => _handleDragStart(details, index)
            : null,
        onVerticalDragStart: widget.direction == Axis.vertical
            ? (details) => _handleDragStart(details, index)
            : null,
        onHorizontalDragUpdate: widget.direction == Axis.horizontal
            ? (details) => _handleDragUpdate(details, index)
            : null,
        onVerticalDragUpdate: widget.direction == Axis.vertical
            ? (details) => _handleDragUpdate(details, index)
            : null,
        onHorizontalDragEnd:
            widget.direction == Axis.horizontal ? _handleDragEnd : null,
        onVerticalDragEnd:
            widget.direction == Axis.vertical ? _handleDragEnd : null,
        child: Container(
          width: widget.direction == Axis.horizontal ? 2 : double.infinity,
          height: widget.direction == Axis.vertical ? 2 : double.infinity,
          color: widget.editorConfigService.themeService.currentTheme?.border ??
              Colors.grey,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.children.isEmpty) return const SizedBox.shrink();

    // Ensure sizes list matches children length
    if (sizes.length != widget.children.length) {
      sizes = List.generate(
        widget.children.length,
        (index) => 1.0 / widget.children.length,
      );
    }

    final children = <Widget>[];
    for (var i = 0; i < widget.children.length; i++) {
      if (i > 0) {
        children.add(_buildDivider(i - 1));
      }
      children.add(
        Expanded(
          flex: (sizes[i] * 100).round(),
          child: widget.children[i],
        ),
      );
    }

    return widget.direction == Axis.horizontal
        ? Row(children: children)
        : Column(children: children);
  }
}
