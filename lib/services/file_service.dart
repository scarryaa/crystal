import 'dart:io';

class FileService {
  String rootDirectory = '';

  void setRootDirectory(String directory) {
    rootDirectory = directory;
  }

  static void saveFile(String path, String content) {
    File file = File(path);
    file.writeAsStringSync(content);
  }

  String getRelativePath(String fullPath, String rootDir) {
    if (!fullPath.startsWith(rootDir)) {
      return fullPath;
    }

    String relativePath = fullPath.substring(rootDir.length);
    if (relativePath.startsWith(Platform.pathSeparator)) {
      relativePath = relativePath.substring(1);
    }

    return relativePath;
  }
}
