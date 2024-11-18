import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crystal/models/editor/events/event_models.dart';
import 'package:crystal/models/editor/lsp_models.dart';
import 'package:crystal/services/editor/editor_event_bus.dart';
import 'package:crystal/services/lsp_config_manager.dart';
import 'package:crystal/state/editor/editor_state.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;

class LSPService {
  final EditorState editor;
  Process? languageServer;
  int _messageId = 1;
  final _logger = Logger('LSPService');
  final Map<int, Completer<dynamic>> _pendingRequests = {};
  int _documentVersion = 1;
  final Map<String, int> _openDocuments = {};
  final Map<String, List<Diagnostic>> _fileDiagnostics = {};
  final List<Function()> _diagnosticsListeners = [];
  ServerCommand? _currentServerCommand;

  LSPService(this.editor);

  Future<void> initialize() async {
    await LSPConfigManager.createDefaultConfigs();
    await _initializeLanguageServer();
  }

  Future<void> _initializeLanguageServer() async {
    try {
      await initializeLanguageServer();
      sendDidOpenNotification(editor.buffer.content);
    } catch (e, stackTrace) {
      _logger.severe(
          'Unexpected error initializing language server', e, stackTrace);
    }
  }

  Future<ServerCommand?> getLSPCommandForLanguage(String extension) async {
    final config = await LSPConfigManager.getLanguageConfig(extension);
    if (config == null) {
      _logger
          .warning('No language server configured for extension: $extension');
      return null;
    }

    return ServerCommand(config['executable'] as String,
        List<String>.from(config['args'] as List));
  }

  Future<void> initializeLanguageServer() async {
    int retryCount = 0;
    while (retryCount < 3) {
      try {
        final fileExtension = p.extension(editor.path);
        _currentServerCommand = await getLSPCommandForLanguage(fileExtension);

        if (_currentServerCommand == null) {
          _logger.warning('No language server for $fileExtension');
          return;
        }

        languageServer = await Process.start(
            _currentServerCommand!.executable, _currentServerCommand!.args,
            environment: {
              'PATH': Platform.environment['PATH']!,
              'NODE_PATH': Platform.environment['NODE_PATH'] ?? ''
            });

        _setupMessageHandling();

        // Wait for server startup
        await Future.delayed(const Duration(milliseconds: 500));

        final response = await sendRequest('initialize', {
          'processId': languageServer?.pid,
          'rootUri': 'file://${p.dirname(p.dirname(editor.path))}',
          'capabilities': _getClientCapabilities(),
        });

        if (response['capabilities'] != null) {
          sendNotification('initialized', {});
          return;
        }
      } catch (e, stack) {
        _logger.warning('Initialize attempt $retryCount failed', e, stack);
        retryCount++;
        await Future.delayed(const Duration(seconds: 2));
      }
    }

    throw Exception('Failed to initialize language server after 3 attempts');
  }

  void _handleServerNotification(Map<String, dynamic> notification) {
    final method = notification['method'] as String;
    final params = notification['params'];

    switch (method) {
      case 'textDocument/publishDiagnostics':
        _handleDiagnostics(params);
        break;
      case 'window/logMessage':
        _handleLogMessage(params);
        break;
      case 'window/showMessage':
        _handleShowMessage(params);
        break;
      case 'client/registerCapability':
        _handleRegisterCapability(params);
        break;
      case 'window/workDoneProgress/create':
        _handleWorkDoneProgress(params);
        break;
      default:
        _logger.fine('Unhandled notification: $method');
    }
  }

  void addDiagnosticsListener(Function() listener) {
    _diagnosticsListeners.add(listener);
  }

  void removeDiagnosticsListener(Function() listener) {
    _diagnosticsListeners.remove(listener);
  }

  void notifyDiagnosticsListeners() {
    for (var listener in _diagnosticsListeners) {
      listener();
    }
  }

  void _handleShowMessage(Map<String, dynamic> params) {
    final message = params['message'] as String;
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

      default:
        _logger.info(message);
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

  Future<void> sendDidOpenNotification(String text) async {
    if (!isLanguageServerRunning()) {
      _logger.warning('Cannot send didOpen - language server not running');
      return;
    }

    try {
      final uri = 'file://${editor.path}';
      final extension = p.extension(editor.path);
      final languageId =
          await LSPConfigManager.getLanguageForExtension(extension);

      sendNotification('textDocument/didOpen', {
        'textDocument': {
          'uri': uri,
          'languageId': languageId,
          'version': _documentVersion++,
          'text': text
        }
      });
      _openDocuments[uri] = _documentVersion;
    } catch (e, stackTrace) {
      _logger.severe('Failed to send didOpen notification', e, stackTrace);
    }
  }

  Future<void> sendDidChangeNotification(String text) async {
    if (!isLanguageServerRunning()) return;

    final uri = 'file://${editor.path}';
    if (!_openDocuments.containsKey(uri)) {
      await sendDidOpenNotification(text);
      return;
    }

    try {
      sendNotification('textDocument/didChange', {
        'textDocument': {'uri': uri, 'version': _documentVersion++},
        'contentChanges': [
          {'text': text}
        ]
      });
      _openDocuments[uri] = _documentVersion;
    } catch (e) {
      _logger.severe('Failed to send didChange notification', e);
    }
  }

  void _handleRegisterCapability(Map<String, dynamic> params) {
    final registrations = params['registrations'] as List;
    for (final registration in registrations) {
      _logger.info('Registered capability: ${registration['method']}');
    }
  }

  void _handleWorkDoneProgress(Map<String, dynamic> params) {
    final token = params['token'];
    _logger.info('Work done progress created with token: $token');
  }

  Future<Map<String, dynamic>?> getDefinition(int line, int character) async {
    try {
      return await sendRequest('textDocument/definition', {
        'textDocument': {'uri': 'file://${editor.path}'},
        'position': {'line': line, 'character': character}
      });
    } catch (e) {
      _logger.warning('Failed to get definition', e);
      return null;
    }
  }

  void _handleServerResponse(Map<String, dynamic> response) {
    _logger.info('Handling server response: $response');
    final id = response['id'] as int;

    final completer = _pendingRequests.remove(id);
    if (completer == null) {
      _logger.warning('No pending request found for id: $id');
      return;
    }

    if (response.containsKey('error')) {
      completer.completeError(response['error']);
    } else {
      completer.complete(response['result']);
    }
  }

  Future<Map<String, dynamic>> sendRequest(
      String method, Map<String, dynamic> params) async {
    final id = _messageId++;
    final completer = Completer<Map<String, dynamic>>();
    _pendingRequests[id] = completer;

    try {
      final request = {
        'jsonrpc': '2.0',
        'id': id,
        'method': method,
        'params': params
      };

      final requestJson = jsonEncode(request);
      final message = 'Content-Length: ${requestJson.length}\r\n'
          'Content-Type: application/vscode-jsonrpc; charset=utf-8\r\n'
          '\r\n'
          '$requestJson';

      languageServer!.stdin.write(message);
      await languageServer!.stdin.flush();

      return await completer.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          _pendingRequests.remove(id);
          throw TimeoutException('Request timed out: $method');
        },
      );
    } catch (e) {
      _pendingRequests.remove(id);
      throw Exception('Failed to send request: $e');
    }
  }

  bool isLanguageServerRunning() {
    return languageServer != null && languageServer!.pid != 0;
  }

  void _setupMessageHandling() {
    languageServer?.stdout.transform(utf8.decoder).listen((String data) {
      _logger.info('Server stdout: $data');
      if (data.trim().isNotEmpty) {
        _handleServerMessage(data);
      }
    }, onError: (error) {
      _logger.severe('Error from language server', error);
    });
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

  Future<bool> isDartSdkAvailable() async {
    try {
      final result = await Process.run('dart', ['--version']);
      return result.exitCode == 0;
    } catch (e) {
      _logger.severe('Dart SDK not found: $e');
      return false;
    }
  }

  void sendNotification(String method, Map<String, dynamic> params) {
    if (languageServer == null) return;

    try {
      final notification = {
        'jsonrpc': '2.0',
        'method': method,
        'params': params
      };

      final notificationJson = jsonEncode(notification);
      final message = 'Content-Length: ${notificationJson.length}\r\n'
          'Content-Type: application/vscode-jsonrpc; charset=utf-8\r\n'
          '\r\n'
          '$notificationJson';

      languageServer!.stdin.write(message);
    } catch (e, stackTrace) {
      _logger.severe('Failed to send notification: $method', e, stackTrace);
    }
  }

  void _handleServerMessage(String message) {
    try {
      String jsonContent = '';

      if (message.startsWith('Content-Length: ')) {
        final headerEnd = message.indexOf('\r\n\r\n');
        if (headerEnd != -1) {
          final lengthMatch =
              RegExp(r'Content-Length: (\d+)').firstMatch(message);
          if (lengthMatch != null) {
            jsonContent = message.substring(headerEnd + 4);
          }
        }
      }

      if (jsonContent.isEmpty) return;

      _processJsonContent(jsonContent);
    } catch (e, stack) {
      _logger.severe('Error handling server message', e, stack);
    }
  }

  void _processJsonContent(String content) {
    final response = jsonDecode(content);

    if (response['method'] == 'workspace/configuration') {
      _handleConfigurationRequest(response);
      return;
    }

    if (response.containsKey('method')) {
      _handleServerNotification(response);
    } else {
      _handleServerResponse(response);
    }
  }

  void _handleDiagnostics(Map<String, dynamic> params) {
    try {
      final uri = params['uri'] as String?;
      if (uri == null || uri.isEmpty) {
        _logger.warning('Received diagnostics with empty URI');
        return;
      }

      final diagnosticsList = params['diagnostics'] as List?;
      if (diagnosticsList == null) {
        _logger.warning('Received diagnostics without a diagnostics list');
        return;
      }

      final diagnostics = diagnosticsList
          .map((d) => Diagnostic.fromJson(d as Map<String, dynamic>))
          .toList();

      final filePath = Uri.parse(uri).toFilePath();
      updateDiagnostics(filePath, diagnostics);
    } catch (e, stack) {
      _logger.severe('Error handling diagnostics: $e\n$stack');
      _logger.severe('Raw diagnostics data: $params');
    }
  }

  void updateDiagnostics(String filePath, List<Diagnostic> diagnostics) {
    _fileDiagnostics[filePath] = diagnostics;

    // If this is the current file being edited, update the editor state
    if (filePath == editor.path) {
      editor.updateDiagnostics(diagnostics);
    }

    // Notify listeners about the change in diagnostics
    notifyDiagnosticsListeners();
  }

  List<Diagnostic> getDiagnostics(String filePath) {
    return _fileDiagnostics[filePath] ?? [];
  }

  Map<String, List<Diagnostic>> getAllDiagnostics() {
    return Map.from(_fileDiagnostics);
  }

  void _handleConfigurationRequest(Map<String, dynamic> request) {
    // Respond to configuration request
    final response = {
      'jsonrpc': '2.0',
      'id': request['id'],
      'result': [
        {
          'enableSdkFormatter': true,
          'lineLength': 80,
          'completeFunctionCalls': true
        },
        {
          'enableSdkFormatter': true,
          'lineLength': 80,
          'completeFunctionCalls': true
        }
      ]
    };

    final responseJson = jsonEncode(response);
    final message = 'Content-Length: ${responseJson.length}\r\n'
        'Content-Type: application/vscode-jsonrpc; charset=utf-8\r\n'
        '\r\n'
        '$responseJson';

    languageServer?.stdin.write(message);
    languageServer?.stdin.flush();
  }

  Future<Map<String, dynamic>?> getHover(int line, int character) async {
    if (!isLanguageServerRunning()) {
      _logger.warning('Language server not running');
      return null;
    }

    try {
      final response = await sendRequest('textDocument/hover', {
        'textDocument': {'uri': 'file://${editor.path}'},
        'position': {'line': line, 'character': character}
      });

      if (!response.containsKey('contents')) {
        _logger.warning('Invalid hover response structure');
        return null;
      }

      return response;
    } catch (e) {
      _logger.warning('Failed to get hover information', e);
      return null;
    }
  }

  void dispose() {
    languageServer?.kill();
  }

  Future<Map<String, dynamic>> getCompletion(int line, int character) async {
    return sendRequest('textDocument/completion', {
      'textDocument': {'uri': 'file://${editor.path}'},
      'position': {'line': line, 'character': character}
    });
  }
}

class ServerCommand {
  final String executable;
  final List<String> args;

  const ServerCommand(this.executable, this.args);
}
