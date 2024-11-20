import 'package:crystal/services/editor/editor_config_service.dart';
import 'package:crystal/services/editor/editor_layout_service.dart';
import 'package:crystal/services/git_service.dart';

class EditorServices {
  final EditorConfigService configService;
  final EditorLayoutService layoutService;
  final GitService gitService;

  EditorServices({
    required this.configService,
    required this.layoutService,
    required this.gitService,
  });
}
