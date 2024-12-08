import 'dart:io';

import 'package:crystal/models/file_explorer/file_item.dart';
import 'package:crystal/screens/editor_screen.dart';
import 'package:flutter/material.dart';

class FileListItem extends StatefulWidget {
  final FileItem item;
  final double leftPadding;
  final Set<String> expandedPaths;

  const FileListItem({
    super.key,
    required this.item,
    this.leftPadding = 0,
    required this.expandedPaths,
  });

  @override
  State<StatefulWidget> createState() => _FileListItemState();
}

class _FileListItemState extends State<FileListItem> {
  bool get isExpanded => widget.expandedPaths.contains(widget.item.path);
  bool isHovered = false;
  List<FileItem> childItems = [];

  @override
  void initState() {
    super.initState();
    // Load children if already expanded
    if (isExpanded) {
      loadDirectoryContents(widget.item.path).then((items) {
        setState(() => childItems = items);
      });
    }
  }

  void handleTap() async {
    if (widget.item.isDirectory) {
      if (isExpanded) {
        setState(() {
          widget.expandedPaths.remove(widget.item.path);
        });
      } else {
        widget.expandedPaths.add(widget.item.path);
        if (childItems.isEmpty) {
          childItems = await loadDirectoryContents(widget.item.path);
        }
        setState(() {});
      }
    } else {
      final editorScreen = context.findAncestorStateOfType<EditorScreenState>();
      if (editorScreen != null) {
        editorScreen.openFile(widget.item.path);
      }
    }
  }

  Future<List<FileItem>> loadDirectoryContents(String path) async {
    final directory = Directory(path);
    final List<FileItem> items = [];

    try {
      await for (var entity in directory.list()) {
        items.add(FileItem(
          name: entity.path.split(Platform.pathSeparator).last,
          path: entity.path,
          isDirectory: entity is Directory,
        ));
      }
    } catch (e) {
      debugPrint('Error loading directory contents: $e');
    }

    return items;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: () => handleTap(),
          child: MouseRegion(
            onHover: (_) => setState(() => isHovered = true),
            onExit: (_) => setState(() => isHovered = false),
            child: Container(
              height: 19,
              color:
                  isHovered ? Colors.blue.withOpacity(0.3) : Colors.transparent,
              child: Padding(
                padding: EdgeInsets.only(
                  left: widget.leftPadding,
                ),
                child: Row(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 4.0),
                      child: Icon(
                        widget.item.isDirectory
                            ? isExpanded
                                ? Icons.folder_open_outlined
                                : Icons.folder_outlined
                            : Icons.insert_drive_file,
                        color: Colors.blueGrey,
                        size: 15,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        widget.item.path.split(Platform.pathSeparator).last,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontFamily: 'IBM Plex Sans',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (isExpanded && childItems.isNotEmpty)
          Column(
            children: childItems
                .map((item) => FileListItem(
                      item: item,
                      expandedPaths: widget.expandedPaths,
                      leftPadding: widget.leftPadding + 16,
                    ))
                .toList(),
          ),
      ],
    );
  }
}
