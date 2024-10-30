import 'package:crystal/state/editor/editor_state.dart';
import 'package:flutter/material.dart';

class EditorTab extends StatelessWidget {
  final EditorState editor;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback onClose;

  const EditorTab({
    required this.editor,
    required this.isActive,
    required this.onTap,
    required this.onClose,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
        onTap: onTap,
        child: GestureDetector(
          onTertiaryTapDown: (_) => onClose(),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border(
                right: BorderSide(
                  color: Colors.grey[200]!,
                ),
                bottom: BorderSide(
                  color: isActive ? Colors.transparent : Colors.grey[200]!,
                ),
              ),
              color: isActive ? Colors.white : Colors.grey[50],
            ),
            child: Row(
              children: [
                if (editor.buffer.isDirty) ...[
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isActive ? Colors.blue : Colors.black54,
                    ),
                  ),
                ],
                const SizedBox(width: 8),
                Text(
                  editor.path.split('/').last,
                  style: TextStyle(
                    color: isActive ? Colors.blue : Colors.black87,
                  ),
                ),
                MouseRegion(
                  child: GestureDetector(
                    onTap: onClose,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: onClose,
                          hoverColor: Colors.black12,
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.all(2),
                            child: Icon(
                              Icons.close,
                              size: 16,
                              color: isActive ? Colors.blue : Colors.black54,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ));
  }
}
