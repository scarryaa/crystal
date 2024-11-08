import 'dart:math';

String generateUniqueTempPath() {
  final random = Random();
  final timestamp = DateTime.now().millisecondsSinceEpoch;
  final randomString =
      List.generate(8, (_) => random.nextInt(16).toRadixString(16)).join();

  return '__temp_${timestamp}_$randomString';
}
