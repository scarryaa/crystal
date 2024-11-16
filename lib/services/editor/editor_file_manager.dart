import 'package:crystal/models/editor/buffer.dart';
import 'package:crystal/services/file_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;

class EditorFileManager {
  final Buffer buffer;
  final FileService fileService;
  EditorFileManager(this.buffer, this.fileService);

  Future<bool> saveFile(String path) async {
    if (path.isEmpty || path.startsWith('__temp')) {
      return saveFileAs(path);
    }
    final String content = buffer.lines.join('\n');
    return writeFileToDisk(path, content);
  }

  Future<bool> saveFileAs(String path) async {
    try {
      final String? outputFile = await FilePicker.platform.saveFile(
          dialogTitle: 'Save As',
          fileName: p.basename(path).contains('__temp') ? '' : p.basename(path),
          initialDirectory: p.dirname(path));
      if (outputFile == null) {
        return false; // User cancelled
      }
      final String content = buffer.lines.join('\n');
      return writeFileToDisk(outputFile, content);
    } catch (e) {
      return false;
    }
  }

  Future<bool> writeFileToDisk(String path, String content) async {
    try {
      FileService.saveFile(path, content);
      buffer.setOriginalContent(content);
      buffer.clearDirty();
      return true;
    } catch (e) {
      // Handle error
      return false;
    }
  }

  void openFile(String content) {
    buffer.setContent(content);
    buffer.setOriginalContent(content);
    buffer.clearDirty();
  }
}
