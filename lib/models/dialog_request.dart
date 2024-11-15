class DialogRequest {
  final String title;
  final String message;
  final List<String> actions;

  DialogRequest({
    required this.title,
    required this.message,
    required this.actions,
  });
}
