import 'package:flutter/material.dart';

class FileItem extends StatefulWidget {
  final bool isDirectory;
  final String fileName;
  final VoidCallback? onTap;
  final bool expanded;
  final int level;
  final Color textColor;
  final Color highlightColor;
  final double fontSize;

  const FileItem({
    super.key,
    required this.fileName,
    required this.expanded,
    required this.textColor,
    required this.highlightColor,
    required this.fontSize,
    this.level = 0,
    this.isDirectory = false,
    this.onTap,
  });

  @override
  State<FileItem> createState() => _FileItemState();
}

class _FileItemState extends State<FileItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() {
        _hovered = true;
      }),
      onExit: (_) => setState(() {
        _hovered = false;
      }),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 1.5, horizontal: 8),
          decoration: BoxDecoration(
            color: _hovered
                ? widget.highlightColor.withOpacity(0.2)
                : Colors.transparent,
          ),
          child: SizedBox(
            width: 400,
            child: Padding(
              padding: EdgeInsets.only(left: 8.0 * widget.level),
              child: Row(
                children: [
                  Icon(
                    widget.isDirectory ? Icons.folder : Icons.insert_drive_file,
                    size: 16,
                    color: _hovered
                        ? widget.highlightColor
                        : widget.textColor.withOpacity(0.5),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.fileName,
                      style: TextStyle(
                        fontSize: widget.fontSize,
                        fontStyle: FontStyle.normal,
                        fontVariations: const [
                          FontVariation('wght', 400),
                        ],
                        fontWeight: FontWeight.w400,
                        color:
                            _hovered ? widget.highlightColor : widget.textColor,
                        decoration: TextDecoration.none,
                        decorationStyle: TextDecorationStyle.solid,
                        decorationThickness: 0,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      softWrap: false,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
