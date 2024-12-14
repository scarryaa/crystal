import 'package:path_provider/path_provider.dart';
import 'package:uuid/v7.dart';

class Utils {
  static Future<String> getTempPath() async {
    return '${(await getApplicationDocumentsDirectory()).path}/_temp_${const UuidV7().generate()}';
  }

  bool isWordCharacter(String char) {
    return RegExp(r'[a-zA-Z0-9_]').hasMatch(char);
  }
}
