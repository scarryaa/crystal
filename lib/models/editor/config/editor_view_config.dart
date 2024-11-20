import 'package:crystal/models/editor/commands/search_config.dart';
import 'package:crystal/models/editor/config/completion_config.dart';
import 'package:crystal/models/editor/config/file_config.dart';
import 'package:crystal/models/editor/config/scroll_config.dart';
import 'package:crystal/models/global_hover_state.dart';
import 'package:crystal/services/editor/editor_services.dart';
import 'package:crystal/state/editor/editor_state.dart';

class EditorViewConfig {
  final ScrollConfig scrollConfig;
  final FileConfig fileConfig;
  final SearchConfig searchConfig;
  final CompletionConfig completionConfig;
  final EditorServices services;
  final EditorState state;
  final GlobalHoverState globalHoverState;
  final int row;
  final int col;

  EditorViewConfig({
    required this.scrollConfig,
    required this.fileConfig,
    required this.searchConfig,
    required this.completionConfig,
    required this.services,
    required this.state,
    required this.globalHoverState,
    required this.row,
    required this.col,
  });
}

class ServiceConfig {}
