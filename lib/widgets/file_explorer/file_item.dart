import 'package:colorful_iconify_flutter/icons/vscode_icons.dart';
import 'package:flutter/material.dart';
import 'package:iconify_flutter/iconify_flutter.dart';

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

  String _getFileIcon() {
    if (widget.isDirectory) {
      return VscodeIcons.default_folder;
    }

    // Get file extension
    final extension = widget.fileName.split('.').last.toLowerCase();

    // Map common file extensions to VSCode icons
    switch (extension) {
      case 'dart':
        return VscodeIcons.file_type_dartlang;
      case 'js':
        return VscodeIcons.file_type_js;
      case 'jsx':
        return VscodeIcons.file_type_reactjs;
      case 'ts':
        return VscodeIcons.file_type_typescript;
      case 'tsx':
        return VscodeIcons.file_type_reactts;
      case 'py':
        return VscodeIcons.file_type_python;
      case 'java':
        return VscodeIcons.file_type_java;
      case 'html':
        return VscodeIcons.file_type_html;
      case 'css':
        return VscodeIcons.file_type_css;
      case 'scss':
        return VscodeIcons.file_type_scss;
      case 'json':
        return VscodeIcons.file_type_json;
      case 'xml':
        return VscodeIcons.file_type_xml;
      case 'md':
        return VscodeIcons.file_type_markdown;
      case 'yaml':
      case 'yml':
        return VscodeIcons.file_type_yaml;
      case 'php':
        return VscodeIcons.file_type_php;
      case 'cpp':
        return VscodeIcons.file_type_cpp;
      case 'c':
        return VscodeIcons.file_type_c;
      case 'cs':
        return VscodeIcons.file_type_csharp;
      case 'go':
        return VscodeIcons.file_type_go;
      case 'rs':
        return VscodeIcons.file_type_rust;
      case 'swift':
        return VscodeIcons.file_type_swift;
      case 'kt':
        return VscodeIcons.file_type_kotlin;
      case 'rb':
        return VscodeIcons.file_type_ruby;
      case 'sql':
        return VscodeIcons.file_type_sql;
      case 'pdf':
        return VscodeIcons.file_type_pdf2;
      case 'zip':
      case 'rar':
      case '7z':
        return VscodeIcons.file_type_zip;
      case 'gitignore':
        return VscodeIcons.file_type_git;
      case 'svg':
        return VscodeIcons.file_type_svg;
      case 'png':
      case 'jpg':
      case 'jpeg':
      case 'gif':
        return VscodeIcons.file_type_image;
      default:
        return VscodeIcons.default_file;
    }
  }

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
                  Iconify(
                    _getFileIcon(),
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
