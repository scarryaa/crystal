import 'dart:io';

import 'package:crystal/models/editor/command_palette_mode.dart';
import 'package:crystal/models/editor/editor_command.dart';
import 'package:crystal/providers/file_explorer_provider.dart';
import 'package:crystal/providers/terminal_provider.dart';
import 'package:crystal/services/editor/editor_config_service.dart';
import 'package:crystal/services/editor/editor_tab_manager.dart';
import 'package:crystal/services/file_service.dart';
import 'package:crystal/widgets/command_palette.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CommandPaletteService {
  static final CommandPaletteService _instance = CommandPaletteService._();
  static CommandPaletteService get instance => _instance;

  CommandPaletteService._();

  List<EditorCommand> _commands = [];
  List<EditorCommand> get commands => _commands;
  List<String> get recentFiles => _recentFiles;

  BuildContext? _context;
  EditorConfigService? _editorConfigService;
  EditorTabManager? _editorTabManager;
  Function(int)? _onEditorClosed;
  FileService? _fileService;
  Function(String)? _openFile;
  Function()? _openNewTab;
  static const String _recentFilesKey = 'recent_files';
  static const int _maxRecentFiles = 50;
  List<String> _recentFiles = [];

  bool get isInitialized =>
      _context != null &&
      _editorConfigService != null &&
      _editorTabManager != null &&
      _onEditorClosed != null &&
      _openFile != null;

  void initialize({
    required BuildContext context,
    required EditorConfigService editorConfigService,
    required EditorTabManager editorTabManager,
    required Function(int) onEditorClosed,
    required Function(String) openFile,
    required FileService fileService,
  }) {
    _context = context;
    _editorConfigService = editorConfigService;
    _editorTabManager = editorTabManager;
    _onEditorClosed = onEditorClosed;
    _openFile = openFile;
    _fileService = fileService;
    _loadRecentFiles();
    _initializeCommands();
  }

  String _getPlatformShortcut(String windowsShortcut) {
    if (Platform.isMacOS) {
      return windowsShortcut
          .replaceAll('Ctrl+', '⌘')
          .replaceAll('Shift+', '⇧')
          .replaceAll('Alt+', '⌥');
    } else if (Platform.isLinux) {
      return windowsShortcut;
    } else {
      return windowsShortcut;
    }
  }

  Future<void> _loadRecentFiles() async {
    final prefs = await SharedPreferences.getInstance();
    final recentFilesJson = prefs.getStringList(_recentFilesKey) ?? [];
    _recentFiles = recentFilesJson;
  }

  Future<void> _saveRecentFiles() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_recentFilesKey, _recentFiles);
  }

  static void addRecentFile(String filePath) {
    instance._recentFiles.remove(filePath); // Remove if exists
    instance._recentFiles.insert(0, filePath); // Add to start
    if (instance._recentFiles.length > _maxRecentFiles) {
      instance._recentFiles = instance._recentFiles.sublist(0, _maxRecentFiles);
    }
    instance._saveRecentFiles();
  }

  Future<void> openFile(String filePath) async {
    try {
      final file = File(filePath);
      final normalizedPath = file.absolute.path;

      if (await file.exists()) {
        if (_editorTabManager?.activeEditor == null) {
          // Create a new editor since there isn't one
          _openFile?.call(normalizedPath);
          _editorTabManager!.closeEditor(0);
        } else {
          // We have an active editor, open new tab
          _editorTabManager!.activeEditor!.tapCallback(normalizedPath);
          addRecentFile(normalizedPath);
        }
      } else {
        throw Exception('File does not exist: $normalizedPath');
      }
    } catch (e) {
      print('Error opening file: $e');
    }
  }

  void _initializeCommands() {
    _commands = [
      EditorCommand(
        id: 'open_file',
        label: 'Open File',
        shortcut: _getPlatformShortcut('Ctrl+O'),
        action: () async {
          FilePickerResult? result = await FilePicker.platform.pickFiles();

          if (result != null && result.files.isNotEmpty) {
            String filePath = result.files.first.path!;
            await openFile(filePath);
          }
        },
      ),
      EditorCommand(
        id: 'new_tab',
        label: 'New Tab',
        shortcut: _getPlatformShortcut('Ctrl+N'),
        action: () => _openNewTab?.call(),
      ),
      EditorCommand(
        id: 'save_file',
        label: 'Save File',
        shortcut: _getPlatformShortcut('Ctrl+S'),
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
        shortcut: _getPlatformShortcut('Ctrl+Shift+S'),
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
        shortcut: _getPlatformShortcut('Ctrl+W'),
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
        shortcut: _getPlatformShortcut('Ctrl+\\'),
        action: () => _editorTabManager?.addVerticalSplit(),
      ),
      EditorCommand(
        id: 'split_horizontal',
        label: 'Split Editor Horizontal',
        shortcut: _getPlatformShortcut('Ctrl+Shift+\\'),
        action: () => _editorTabManager?.addHorizontalSplit(),
      ),
      EditorCommand(
        id: 'toggle_terminal',
        label: 'Toggle Terminal',
        shortcut: _getPlatformShortcut('Ctrl+`'),
        action: () {
          if (_context != null) {
            Provider.of<TerminalProvider>(_context!, listen: false).toggle();
          }
        },
      ),
      EditorCommand(
        id: 'toggle_file_explorer',
        label: 'Toggle File Explorer',
        shortcut: _getPlatformShortcut('Ctrl+B'),
        action: () {
          if (_context != null) {
            Provider.of<FileExplorerProvider>(_context!, listen: false)
                .toggle();
          }
        },
      ),
    ];
  }

  CommandItem _convertToCommandItem(EditorCommand command) {
    IconData icon;
    Color iconColor;

    if (command.id.startsWith('recent_')) {
      icon = Icons.history;
      iconColor = Colors.grey;
    } else {
      icon = Icons.code;
      iconColor = Colors.blue;
    }

    return CommandItem(
      id: command.id,
      label: command.label,
      detail: command.shortcut ?? command.detail ?? '',
      category: command.category ?? 'Editor',
      icon: icon,
      iconColor: iconColor,
    );
  }

  void showCommandPalette(
      [CommandPaletteMode mode = CommandPaletteMode.commands]) {
    if (!isInitialized) {
      throw Exception('CommandPaletteService must be initialized before use');
    }

    _initializeCommands();

    if (mode == CommandPaletteMode.files) {
      _showFilesPalette();
    } else {
      _showCommandsPalette();
    }
  }

  void _showCommandsPalette() {
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

  Future<void> _showFilesPalette() async {
    final Set<String> addedPaths = {};
    final List<CommandItem> fileItems = [];

    // Add recent files first
    for (final filePath in _recentFiles) {
      if (await File(filePath).exists()) {
        fileItems.add(CommandItem(
          id: 'recent_${filePath.hashCode}',
          label: File(filePath).uri.pathSegments.last,
          detail: filePath,
          category: 'Recent Files',
          icon: Icons.history,
          iconColor: Colors.grey,
        ));
        addedPaths.add(filePath);
      }
    }

    // Get current working directory or project root
    final Directory rootDir = Directory(_fileService?.rootDirectory ?? '');

    try {
      // Create a list to store all files
      List<FileSystemEntity> allFiles = [];

      // Recursively get all files from subdirectories
      await for (final entity
          in rootDir.list(recursive: true, followLinks: false)) {
        if (entity is File) {
          allFiles.add(entity);
        }
      }

      // Sort files by path for consistent ordering
      allFiles.sort((a, b) => a.path.compareTo(b.path));

      // Add files that haven't been added as recent files
      for (final entity in allFiles) {
        if (!addedPaths.contains(entity.path)) {
          final name = entity.uri.pathSegments.last;
          // Get relative path from root directory for the detail
          final relativePath = entity.path.substring(rootDir.path.length + 1);

          fileItems.add(CommandItem(
            id: entity.path,
            label: name,
            detail: relativePath,
            category: 'Files',
            icon: Icons.insert_drive_file,
            iconColor: Colors.blue,
          ));
          addedPaths.add(entity.path);
        }
      }
    } catch (e) {
      print('Error listing directory: $e');
    }

    showDialog(
      context: _context!,
      builder: (context) => CommandPalette(
        commands: fileItems,
        onSelect: (item) async {
          if (item.id != 'separator') {
            final filePath = item.id.startsWith('recent_')
                ? item.detail
                : path.join(rootDir.path, item.detail);

            final file = File(filePath);
            if (await file.exists()) {
              await openFile(filePath);
              Navigator.pop(context);
            }
          }
        },
        editorConfigService: _editorConfigService!,
        initialMode: CommandPaletteMode.files,
      ),
    );
  }
}
