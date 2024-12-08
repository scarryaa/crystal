import 'package:crystal/widgets/file_explorer/file_list_item.dart';
import 'package:crystal/widgets/file_explorer/viewmodel/file_explorer_view_model.dart';
import 'package:flutter/material.dart';

class FileExplorer extends StatefulWidget {
  final double width;
  final FileExplorerViewModel viewModel;

  const FileExplorer({
    super.key,
    this.width = 200,
    required this.viewModel,
  });

  @override
  State<StatefulWidget> createState() => _FileExplorerState();
}

class _FileExplorerState extends State<FileExplorer> {
  final Set<String> expandedPaths = {};

  @override
  void initState() {
    super.initState();
    widget.viewModel.populateItems();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      child: Container(
        width: widget.width,
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(right: BorderSide(width: 1, color: Colors.grey)),
        ),
        child: ListenableBuilder(
          listenable: widget.viewModel,
          builder: (context, _) {
            return ListView.builder(
              itemCount: widget.viewModel.items.length,
              itemBuilder: (context, index) {
                return FileListItem(
                  item: widget.viewModel.items[index],
                  expandedPaths: expandedPaths,
                );
              },
            );
          },
        ),
      ),
    );
  }
}
