import 'package:crystal/models/editor/config/editor_view_config.dart';
import 'package:crystal/models/git_models.dart';
import 'package:flutter/foundation.dart';

class GitManager {
  final EditorViewConfig config;
  List<BlameLine>? blameInfo;

  GitManager({
    required this.config,
  });

  Future<void> initializeGit() async {
    try {
      final blame =
          await config.services.gitService.getBlame(config.state.path);
      blameInfo = blame;
    } catch (e) {
      debugPrint('Git initialization failed: $e');
      blameInfo = [];
    }
  }
}
