import 'package:crystal/services/editor/editor_config_service.dart';
import 'package:crystal/services/editor/editor_file_manager.dart';
import 'package:crystal/services/editor/editor_layout_service.dart';
import 'package:crystal/services/editor/editor_tab_manager.dart';
import 'package:crystal/services/file_service.dart';
import 'package:crystal/services/git_service.dart';
import 'package:crystal/services/lsp_service.dart';
import 'package:crystal/state/editor/editor_state.dart';

class ServiceState {
  final EditorLayoutService editorLayoutService;
  final EditorConfigService editorConfigService;
  final FileService fileService;
  final GitService gitService;
  final EditorTabManager editorTabManager;
  late final LSPService lspService;
  late final EditorFileManager fileManager;

  ServiceState({
    required this.editorLayoutService,
    required this.editorConfigService,
    required this.fileService,
    required this.gitService,
    required this.editorTabManager,
  });

  void initializeLSPService(EditorState editorState) {
    lspService = LSPService(editorState);
    lspService.initialize();
  }
}
