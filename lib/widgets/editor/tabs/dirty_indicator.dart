import 'package:flutter/material.dart';

class DirtyIndicator extends StatefulWidget {
  final bool isDirty;

  const DirtyIndicator({
    super.key,
    required this.isDirty,
  });

  @override
  State<StatefulWidget> createState() => _DirtyIndicatorState();
}

class _DirtyIndicatorState extends State<DirtyIndicator> {
  @override
  Widget build(BuildContext context) {
    return widget.isDirty
        ? Container(
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
              borderRadius: BorderRadius.circular(8.0),
            ),
            width: 8.0,
            height: 8.0,
          )
        : const SizedBox(width: 8.0, height: 8.0);
  }
}
