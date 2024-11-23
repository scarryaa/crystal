import 'dart:ui';

import 'package:crystal/models/editor/command_palette_mode.dart';
import 'package:crystal/models/editor/commands/editing_commands.dart';
import 'package:crystal/models/editor/commands/file_commands.dart';
import 'package:crystal/models/editor/commands/navigation_commands.dart';
import 'package:crystal/models/editor/config/config_paths.dart';
import 'package:crystal/models/editor/config/editor_view_config.dart';
import 'package:crystal/services/command_palette_service.dart';
import 'package:crystal/services/editor/editor_input_handler.dart';
import 'package:crystal/services/editor/handlers/keyboard/editor_keyboard_handler.dart';
import 'package:crystal/services/editor/handlers/keyboard/file_handler.dart';
import 'package:crystal/services/editor/handlers/keyboard/navigation_handler.dart';
import 'package:crystal/services/editor/handlers/keyboard/text_editing_handler.dart';
import 'package:crystal/services/editor/view/cursor_manager.dart';
import 'package:crystal/services/editor/view/editor_painter_manager.dart';
import 'package:crystal/services/editor/view/focus_manager.dart';
import 'package:crystal/services/editor/view/git_manager.dart';
import 'package:crystal/services/editor/view/hover_manager.dart';
import 'package:crystal/services/editor/view/key_event_manager.dart';

class EditorManagers {
  late final CursorManager cursor;
  final FocusManager focus;
  final HoverManager hover;
  final GitManager git;
  late final KeyEventManager keyEvent;
  final EditorPainterManager painter;
  final EditorInputHandler input;
  late final EditorKeyboardHandler keyboard;
  late final EditorViewConfig config;

  EditorManagers({
    required EditorViewConfig config,
    required VoidCallback resetCaretBlink,
    required VoidCallback requestFocus,
  })  : config = config,
        hover = HoverManager(config: config),
        focus = FocusManager(config: config),
        git = GitManager(config: config),
        painter = EditorPainterManager(config: config),
        input = EditorInputHandler(
          resetCaretBlink: resetCaretBlink,
          requestFocus: requestFocus,
        ) {
    cursor = CursorManager(config, hover);
    keyboard = EditorKeyboardHandler(
        fileHandler: FileHandler(
          getState: () => config.state,
          scrollToCursor: config.scrollConfig.scrollToCursor,
          isDirty: config.fileConfig.isDirty,
          fileCommands: FileCommands(
            saveFile: config.fileConfig.saveFile,
            saveFileAs: config.fileConfig.saveFileAs,
            openConfig: _openConfig,
            openDefaultConfig: _openDefaultConfig,
            openNewTab: config.fileConfig.openNewTab,
          ),
          onEditorClosed: config.fileConfig.onEditorClosed,
          activeEditorIndex: () => config.fileConfig.activeEditorIndex,
        ),
        navigationHandler: NavigationHandler(
          getState: () => config.state,
          scrollToCursor: config.scrollConfig.scrollToCursor,
          navigationCommands: NavigationCommands(
            scrollToCursor: config.scrollConfig.scrollToCursor,
            moveCursorUp: config.state.moveCursorUp,
            moveCursorDown: config.state.moveCursorDown,
            moveCursorLeft: config.state.moveCursorLeft,
            moveCursorRight: config.state.moveCursorRight,
            moveCursorToLineStart: config.state.moveCursorToLineStart,
            moveCursorToLineEnd: config.state.moveCursorToLineEnd,
            moveCursorToDocumentStart: config.state.moveCursorToDocumentStart,
            moveCursorToDocumentEnd: config.state.moveCursorToDocumentEnd,
            moveCursorPageUp: config.state.moveCursorPageUp,
            moveCursorPageDown: config.state.moveCursorPageDown,
          ),
        ),
        textEditingHandler: TextEditingHandler(
          getState: () => config.state,
          scrollToCursor: config.scrollConfig.scrollToCursor,
          editingCommands: EditingCommands(
            copy: config.state.copy,
            cut: config.state.cut,
            paste: config.state.paste,
            selectAll: config.state.selectAll,
            backspace: config.state.backspace,
            delete: config.state.delete,
            insertNewLine: config.state.insertNewLine,
            insertTab: config.state.insertTab,
            backTab: config.state.backTab,
            insertChar: config.state.insertChar,
            getLastPastedLineCount: config.state.getLastPastedLineCount,
            getSelectedLineRange: config.state.getSelectedLineRange,
          ),
          updateSingleLineWidth: painter.updateSingleLineWidth,
          onSearchTermChanged: config.searchConfig.onSearchTermChanged,
          searchTerm: config.searchConfig.searchTerm,
        ),
        getState: () => config.state,
        onSearchTermChanged: config.searchConfig.onSearchTermChanged,
        searchTerm: config.searchConfig.searchTerm,
        showCommandPalette: (
                [CommandPaletteMode mode = CommandPaletteMode.commands]) =>
            CommandPaletteService.instance.showCommandPalette(mode));
    keyEvent = KeyEventManager(keyboard);
  }

  Future<void> _openConfig() async {
    final configPath = await ConfigPaths.getConfigFilePath();
    await config.state.tapCallback(configPath);
  }

  Future<void> _openDefaultConfig() async {
    final defaultConfigPath = await ConfigPaths.getDefaultConfigFilePath();
    await config.state.tapCallback(defaultConfigPath);
  }

  void dispose() {
    focus.dispose();
    cursor.dispose();
    hover.dispose();
    hover.wordHighlightTimer?.cancel();
  }
}
