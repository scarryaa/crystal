import 'package:flutter/material.dart';

class FileItem extends StatefulWidget {
  final bool isDirectory;
  final String fileName;
  final VoidCallback? onTap;
  bool expanded;
  int level;

  FileItem({
    super.key,
    required this.fileName,
    required this.expanded,
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
            padding: const EdgeInsets.symmetric(vertical: 2.5, horizontal: 8),
            decoration: BoxDecoration(
              color:
                  _hovered ? Colors.teal.withOpacity(0.1) : Colors.transparent,
            ),
            child: Padding(
              padding: EdgeInsets.only(left: 8.0 * widget.level),
              child: Row(
                children: [
                  Icon(
                    widget.isDirectory ? Icons.folder : Icons.insert_drive_file,
                    size: 16,
                    color: _hovered
                        ? Colors.teal[300]
                        : Colors.black.withOpacity(0.5),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.fileName,
                      style: TextStyle(
                        fontWeight: FontWeight.normal,
                        fontSize: 14,
                        fontStyle: FontStyle.normal,
                        fontFamily: 'IBM Plex Sans',
                        color: _hovered ? Colors.teal[700] : Colors.black,
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
        ));
  }
}
