import 'dart:io';

class FileService {
  static void saveFile(String path, String content) {
    File file = File(path);
    file.writeAsStringSync(content);
  }
}
