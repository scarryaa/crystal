import 'package:crystal/models/editor/editor_command.dart';
import 'package:crystal/providers/file_explorer_provider.dart';
import 'package:crystal/providers/terminal_provider.dart';
import 'package:crystal/services/editor/editor_config_service.dart';
import 'package:crystal/services/editor/editor_tab_manager.dart';
import 'package:crystal/widgets/command_palette.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class CommandPaletteService {
  static final CommandPaletteService _instance = CommandPaletteService._();
  static CommandPaletteService get instance => _instance;

  CommandPaletteService._();

  List<EditorCommand> _commands = [];
  List<EditorCommand> get commands => _commands;

  BuildContext? _context;
  EditorConfigService? _editorConfigService;
  EditorTabManager? _editorTabManager;
  Function(int)? _onEditorClosed;
  Function()? _openNewTab;

  bool get isInitialized =>
      _context != null &&
      _editorConfigService != null &&
      _editorTabManager != null &&
      _onEditorClosed != null &&
      _openNewTab != null;

  void initialize({
    required BuildContext context,
    required EditorConfigService editorConfigService,
    required EditorTabManager editorTabManager,
    required Function(int) onEditorClosed,
    required Function() openNewTab,
  }) {
    _context = context;
    _editorConfigService = editorConfigService;
    _editorTabManager = editorTabManager;
    _onEditorClosed = onEditorClosed;
    _openNewTab = openNewTab;
    _initializeCommands();
  }

  void _initializeCommands() {
    _commands = [
      EditorCommand(
        id: 'new_tab',
        label: 'New Tab',
        shortcut: 'Ctrl+N',
        action: () => _openNewTab?.call(),
      ),
      EditorCommand(
        id: 'save_file',
        label: 'Save File',
        shortcut: 'Ctrl+S',
        action: () async {
          if (_editorTabManager?.activeEditor != null) {
            await _editorTabManager!.activeEditor!.saveFile(
              _editorTabManager!.activeEditor!.path,
            );
          }
        },
      ),
      EditorCommand(
        id: 'save_as',
        label: 'Save As...',
        shortcut: 'Ctrl+Shift+S',
        action: () async {
          if (_editorTabManager?.activeEditor != null) {
            await _editorTabManager!.activeEditor!.saveFileAs(
              _editorTabManager!.activeEditor!.path,
            );
          }
        },
      ),
      EditorCommand(
        id: 'close_tab',
        label: 'Close Tab',
        shortcut: 'Ctrl+W',
        action: () {
          if (_editorTabManager!.activeSplitView.activeEditorIndex >= 0) {
            _onEditorClosed?.call(
              _editorTabManager!.activeSplitView.activeEditorIndex,
            );
          }
        },
      ),
      EditorCommand(
        id: 'split_vertical',
        label: 'Split Editor Vertical',
        shortcut: 'Ctrl+\\',
        action: () => _editorTabManager?.addVerticalSplit(),
      ),
      EditorCommand(
        id: 'split_horizontal',
        label: 'Split Editor Horizontal',
        shortcut: 'Ctrl+Shift+\\',
        action: () => _editorTabManager?.addHorizontalSplit(),
      ),
      EditorCommand(
        id: 'toggle_terminal',
        label: 'Toggle Terminal',
        shortcut: 'Ctrl+`',
        action: () {
          if (_context != null) {
            Provider.of<TerminalProvider>(_context!, listen: false).toggle();
          }
        },
      ),
      EditorCommand(
        id: 'toggle_file_explorer',
        label: 'Toggle File Explorer',
        shortcut: 'Ctrl+B',
        action: () {
          if (_context != null) {
            Provider.of<FileExplorerProvider>(_context!, listen: false)
                .toggle();
          }
        },
      ),
    ];
  }

  void showCommandPalette() {
    if (!isInitialized) {
      throw Exception('CommandPaletteService must be initialized before use');
    }

    showDialog(
      context: _context!,
      builder: (context) => CommandPalette(
        commands: _commands.map((cmd) => _convertToCommandItem(cmd)).toList(),
        onSelect: (commandItem) {
          final originalCommand = _commands.firstWhere(
            (cmd) => cmd.id == commandItem.id,
            orElse: () => throw Exception('Command not found'),
          );
          originalCommand.action();
          Navigator.pop(context);
        },
        editorConfigService: _editorConfigService!,
      ),
    );
  }

  CommandItem _convertToCommandItem(EditorCommand command) {
    return CommandItem(
      id: command.id,
      label: command.label,
      detail: command.shortcut ?? '',
      category: 'Editor',
      icon: Icons.code,
      iconColor: Colors.blue,
    );
  }
}
