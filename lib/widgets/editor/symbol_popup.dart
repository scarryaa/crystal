import 'package:crystal/models/editor/breadcrumb_item.dart';
import 'package:flutter/material.dart';

class SymbolPopup extends StatelessWidget {
  final List<BreadcrumbItem> symbols;
  final Function(BreadcrumbItem) onSymbolSelected;

  const SymbolPopup({
    super.key,
    required this.symbols,
    required this.onSymbolSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 250,
      constraints: const BoxConstraints(maxHeight: 300),
      decoration: BoxDecoration(
        color: Theme.of(context).canvasColor,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ListView.builder(
        itemCount: symbols.length,
        itemBuilder: (context, index) {
          return ListTile(
            title: Text(symbols[index].name),
            subtitle: Text(symbols[index].type),
            onTap: () {
              onSymbolSelected(symbols[index]);
              Navigator.of(context).pop();
            },
          );
        },
      ),
    );
  }
}
