class FileItem {
  final String name;
  final String path;
  final bool isDirectory;
  List<FileItem>? children;

  FileItem({
    required this.name,
    required this.path,
    required this.isDirectory,
    this.children,
  });
}
