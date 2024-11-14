class BreadcrumbItem {
  final String type;
  final String name;
  final int line;
  final int column;

  BreadcrumbItem(
      {required this.type,
      required this.name,
      required this.line,
      required this.column});
}
