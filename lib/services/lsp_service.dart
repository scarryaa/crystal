import 'dart:async';
import 'dart:io';

import 'package:crystal/models/editor/events/event_models.dart';
import 'package:crystal/models/editor/lsp_models.dart';
import 'package:crystal/models/server_command.dart';
import 'package:crystal/services/editor/editor_event_bus.dart';
import 'package:crystal/services/lsp/diagnostics_manager.dart';
import 'package:crystal/services/lsp/document_manager.dart';
import 'package:crystal/services/lsp/lsp_connection_manager.dart';
import 'package:crystal/services/lsp/message_processor.dart';
import 'package:crystal/services/lsp/progress_tracker.dart';
import 'package:crystal/services/lsp_config_manager.dart';
import 'package:crystal/state/editor/editor_state.dart';
import 'package:crystal/state/lsp/lsp_state.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;

class LSPService {
  final LSPConnectionManager connection;
  late final DocumentManager documents;
  final DiagnosticsManager diagnostics;
  final ProgressTracker progress;
  final MessageProcessor messageProcessor;
  final LSPState state;
  final EditorState editor;

  final List<Function()> _diagnosticsListeners = [];

  final _logger = Logger('LSPService');

  LSPService(this.editor)
      : connection = LSPConnectionManager(),
        diagnostics = DiagnosticsManager(editor),
        progress = ProgressTracker(),
        messageProcessor = MessageProcessor(),
        state = LSPState() {
    documents = DocumentManager(connection);
  }

  Future<void> initialize() async {
    if (state.isInitializing.value || state.isRunning.value) return;

    state.isInitializing.value = true;
    int retryCount = 0;
    const maxRetries = 3;
    const retryDelay = Duration(seconds: 2);

    while (retryCount < maxRetries) {
      try {
        final serverCommand = await _getServerCommand();
        if (serverCommand == null) {
          _logger.warning('No server command found for this file type');
          return;
        }

        // Start the server process
        await connection.initializeConnection(
          serverCommand.executable,
          serverCommand.args,
        );

        // Initialize the LSP server
        final response = await connection.initialize(
          'file://${p.dirname(p.dirname(editor.path))}',
          _getClientCapabilities(),
        );

        // Wait for initialization to complete
        await connection.waitForInitialization();
        connection.onNotification = _handleServerNotification;
        connection.onConfigurationRequest = _handleConfigurationRequest;

        state.currentServerName = _extractServerInfo(response);
        state.currentServerCommand = serverCommand;
        state.isRunning.value = true;

        await openDocument();
        _logger.info('LSP server successfully initialized');
        break;
      } catch (e, stackTrace) {
        retryCount++;
        _logger.warning(
          'Failed to initialize LSP server (attempt $retryCount of $maxRetries)',
          e,
          stackTrace,
        );

        if (retryCount >= maxRetries) {
          _logger.severe(
              'Failed to initialize LSP server after $maxRetries attempts');
          EditorEventBus.emit(ErrorEvent(
            message: 'LSP Server Error',
            error:
                'Failed to initialize language server after multiple attempts',
          ));
          break;
        }

        await Future.delayed(retryDelay);
      }
    }

    state.isInitializing.value = false;
  }

  Future<void> reconnect() async {
    _logger.info('Attempting to reconnect to LSP server...');

    // Clean up existing connection
    connection.dispose();

    // Reset state
    state.isRunning.value = false;

    // Try to initialize again
    await initialize();
  }

  Future<void> openDocument() async {
    final extension = p.extension(editor.path);
    final languageId =
        await LSPConfigManager.getLanguageForExtension(extension);

    await documents.openDocument(
        'file://${editor.path}', editor.buffer.content, languageId ?? '');
  }

  Future<void> sendDidChangeNotification(String text) async {
    if (!isLanguageServerRunning()) {
      _logger.warning('Cannot send didChange - language server not running');
      return;
    }

    final uri = 'file://${editor.path}';
    try {
      if (!documents.isDocumentOpen(uri)) {
        await sendDidOpenNotification(text);
      }

      await documents.updateDocument(uri, text);
    } catch (e, stackTrace) {
      _logger.severe('Failed to send didChange notification', e, stackTrace);
    }
  }

  Future<void> sendDidOpenNotification(String text) async {
    if (!state.isRunning.value) {
      _logger.info('LSP server not running, attempting to initialize...');
      await initialize();
    }

    if (!state.isRunning.value) {
      _logger.warning('Cannot send didOpen - language server not running');
      return;
    }

    try {
      final uri = 'file://${editor.path}';
      final extension = p.extension(editor.path);
      final languageId =
          await LSPConfigManager.getLanguageForExtension(extension) ??
              'plaintext';

      await documents.openDocument(uri, text, languageId);
    } catch (e, stackTrace) {
      _logger.severe('Failed to send didOpen notification', e, stackTrace);
    }
  }

  Future<Map<String, dynamic>?> getHover(int line, int character) async {
    if (!state.isRunning.value) return null;

    return await connection.sendRequest('textDocument/hover', {
      'textDocument': {'uri': 'file://${editor.path}'},
      'position': {'line': line, 'character': character}
    });
  }

  Future<Map<String, dynamic>?> getDefinition(int line, int character) async {
    if (!state.isRunning.value) return null;

    return await connection.sendRequest('textDocument/definition', {
      'textDocument': {'uri': 'file://${editor.path}'},
      'position': {'line': line, 'character': character}
    });
  }

  Future<Map<String, dynamic>> getCompletion(int line, int character) async {
    return await connection.sendRequest('textDocument/completion', {
      'textDocument': {'uri': 'file://${editor.path}'},
      'position': {'line': line, 'character': character}
    });
  }

  // Helper methods
  Future<ServerCommand?> _getServerCommand() async {
    final extension = p.extension(editor.path);
    final config = await LSPConfigManager.getLanguageConfig(extension);
    if (config == null) {
      _logger
          .warning('No language server configured for extension: $extension');
      return null;
    }

    return ServerCommand(
      config['executable'] as String,
      List<String>.from(config['args'] as List),
    );
  }

  String? _extractServerInfo(Map<String, dynamic> response) {
    final serverInfo = response['result']?['serverInfo'];
    if (serverInfo != null) {
      final name = serverInfo['name'] as String;
      final version = serverInfo['version'] as String;
      return '$name v$version';
    }
    return null;
  }

  Map<String, dynamic> _getClientCapabilities() {
    return {
      'workspace': {
        'configuration': true,
        'didChangeWatchedFiles': {
          'dynamicRegistration': true,
          'relativePatternSupport': true
        },
        'didChangeConfiguration': {'dynamicRegistration': true},
        'workspaceFolders': true,
        'symbol': {'resolveSupport': null},
        'inlayHint': {'refreshSupport': true},
        'diagnostic': {'refreshSupport': null},
        'workspaceEdit': {
          'resourceOperations': ['create', 'rename', 'delete'],
          'documentChanges': true,
          'failureHandling': 'textOnlyTransactional',
          'normalizesLineEndings': true,
          'changeAnnotationSupport': {'groupsOnLabel': true},
        },
      },
      'textDocument': {
        'synchronization': {
          'didSave': true,
          'willSave': true,
          'willSaveWaitUntil': true,
        },
        'completion': {
          'completionItem': {
            'snippetSupport': true,
            'commitCharactersSupport': true,
            'documentationFormat': ['markdown', 'plaintext'],
            'deprecatedSupport': true,
            'preselectSupport': true,
            'insertReplaceSupport': true,
            'resolveSupport': {
              'properties': ['documentation', 'detail', 'additionalTextEdits']
            },
            'insertTextModeSupport': {
              'valueSet': [1, 2]
            },
          },
          'completionItemKind': {
            'valueSet': [
              1,
              2,
              3,
              4,
              5,
              6,
              7,
              8,
              9,
              10,
              11,
              12,
              13,
              14,
              15,
              16,
              17,
              18,
              19,
              20,
              21,
              22,
              23,
              24,
              25
            ]
          },
          'contextSupport': true,
        },
        'hover': {
          'contentFormat': ['markdown', 'plaintext'],
        },
        'signatureHelp': {
          'signatureInformation': {
            'documentationFormat': ['markdown', 'plaintext'],
            'parameterInformation': {'labelOffsetSupport': true},
            'activeParameterSupport': true,
          },
          'contextSupport': true,
        },
        'declaration': {'linkSupport': true},
        'definition': {'linkSupport': true},
        'typeDefinition': {'linkSupport': true},
        'implementation': {'linkSupport': true},
        'references': {},
        'documentHighlight': {},
        'documentSymbol': {
          'symbolKind': {
            'valueSet': [
              1,
              2,
              3,
              4,
              5,
              6,
              7,
              8,
              9,
              10,
              11,
              12,
              13,
              14,
              15,
              16,
              17,
              18,
              19,
              20,
              21,
              22,
              23,
              24,
              25,
              26
            ]
          },
          'hierarchicalDocumentSymbolSupport': true,
        },
        'codeAction': {
          'codeActionLiteralSupport': {
            'codeActionKind': {
              'valueSet': [
                '',
                'quickfix',
                'refactor',
                'refactor.extract',
                'refactor.inline',
                'refactor.rewrite',
                'source',
                'source.organizeImports',
              ]
            }
          },
          'isPreferredSupport': true,
          'disabledSupport': true,
          'dataSupport': true,
          'resolveSupport': {
            'properties': ['edit']
          },
        },
        'codeLens': {},
        'formatting': {},
        'rangeFormatting': {},
        'onTypeFormatting': {},
        'rename': {'prepareSupport': true},
        'publishDiagnostics': {
          'relatedInformation': true,
          'tagSupport': {
            'valueSet': [1, 2]
          },
          'versionSupport': true,
          'codeDescriptionSupport': true,
          'dataSupport': true,
        },
        'foldingRange': {
          'lineFoldingOnly': true,
        },
        'selectionRange': {},
        'linkedEditingRange': {},
        'callHierarchy': {},
        'semanticTokens': {
          'requests': {
            'range': true,
            'full': {'delta': true}
          },
          'tokenTypes': [
            'namespace',
            'type',
            'class',
            'enum',
            'interface',
            'struct',
            'typeParameter',
            'parameter',
            'variable',
            'property',
            'enumMember',
            'event',
            'function',
            'method',
            'macro',
            'keyword',
            'modifier',
            'comment',
            'string',
            'number',
            'regexp',
            'operator'
          ],
          'tokenModifiers': [
            'declaration',
            'definition',
            'readonly',
            'static',
            'deprecated',
            'abstract',
            'async',
            'modification',
            'documentation',
            'defaultLibrary'
          ],
          'formats': ['relative'],
        },
        'moniker': {},
      },
      'window': {
        'workDoneProgress': true,
        'showMessage': {},
        'showDocument': {'support': true},
      },
      'general': {
        'regularExpressions': {'engine': 'ECMAScript', 'version': 'ES2020'},
        'markdown': {'parser': 'marked', 'version': '1.1.0'},
      },
      'experimental': {
        'serverStatusNotification': true,
        'localDocs': true,
      }
    };
  }

  void addDiagnosticsListener(Function() listener) {
    diagnostics.addListener(listener);
  }

  void removeDiagnosticsListener(Function() listener) {
    diagnostics.removeListener(listener);
  }

  // Handle server notifications
  void _handleServerNotification(Map<String, dynamic> notification) {
    final method = notification['method'] as String;
    final params = notification['params'];

    switch (method) {
      case 'textDocument/publishDiagnostics':
        diagnostics.handleDiagnostics(params);
        break;
      case 'window/logMessage':
        _handleLogMessage(params);
        break;
      case 'window/showMessage':
        _handleShowMessage(params);
        break;
      case 'window/workDoneProgress/create':
        progress.handleProgress(params);
        break;
      case '/progress':
        progress.handleProgress(params);
        break;
      default:
        _logger.fine('Unhandled notification: $method');
    }
  }

  void _handleShowMessage(Map<String, dynamic> params) {
    final message = params['message'] as String;
    state.statusMessage.value = message;
    final type = params['type'] as int;

    switch (type) {
      case 1: // Error
        _logger.severe(message);
        EditorEventBus.emit(ErrorEvent(
          message: 'LSP Server Error',
          error: message,
        ));
        break;
      case 2: // Warning
        _logger.warning(message);
        EditorEventBus.emit(WarningEvent(
          message: message,
        ));
        break;
      case 3: // Info
        _logger.info(message);
        EditorEventBus.emit(InfoEvent(
          message: message,
        ));
        break;
      case 4: // Log
        _logger.fine(message);
        break;
    }
  }

  void _handleLogMessage(Map<String, dynamic> params) {
    final type = params['type'] as int;
    final message = params['message'] as String;
    switch (type) {
      case 1:
        _logger.severe(message);
        break;
      case 2:
        _logger.warning(message);
        break;
      case 3:
        _logger.info(message);
        break;
      case 4:
        _logger.fine(message);
        break;
    }
  }

  // Configuration handling
  void _handleConfigurationRequest(Map<String, dynamic> request) {
    final response = {
      'jsonrpc': '2.0',
      'id': request['id'],
      'result': [
        {
          'enableSdkFormatter': true,
          'lineLength': 80,
          'completeFunctionCalls': true
        },
      ]
    };

    connection.sendMessage(response);
  }

  // Dart SDK availability check
  Future<bool> isDartSdkAvailable() async {
    try {
      final result = await Process.run('dart', ['--version']);
      return result.exitCode == 0;
    } catch (e) {
      _logger.severe('Dart SDK not found: $e');
      return false;
    }
  }

  // Analysis state management
  bool isAnalysisStuck() {
    return progress.isAnalysisInProgress();
  }

  bool isLanguageServerRunning() {
    return state.isRunning.value;
  }

  // Diagnostics access methods
  List<Diagnostic> getDiagnostics(String filePath) {
    return diagnostics.getDiagnostics(filePath);
  }

  Map<String, List<Diagnostic>> getAllDiagnostics() {
    return diagnostics.getAllDiagnostics();
  }

  // Server status
  String? get serverName => state.currentServerName;

  // ValueNotifier access
  ValueNotifier<bool> get isRunningNotifier => state.isRunning;
  ValueNotifier<bool> get isInitializingNotifier => state.isInitializing;
  ValueNotifier<String> get statusMessageNotifier => state.statusMessage;
  ValueNotifier<bool> get workProgressNotifier => progress.workProgress;
  ValueNotifier<String> get workProgressMessage => progress.workProgressMessage;

  // Getters
  String get currentServerName => state.currentServerName ?? 'Unknown';
  ServerCommand? get currentServerCommand => state.currentServerCommand;

  void dispose() {
    _diagnosticsListeners.clear();
    progress.clearProgress();
    state.dispose();
    connection.dispose();
  }
}
