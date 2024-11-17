import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crystal/models/editor/events/event_models.dart';
import 'package:crystal/models/editor/lsp_models.dart';
import 'package:crystal/services/editor/editor_event_bus.dart';
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

  LSPService(this.editor) {
    _initializeLanguageServer();
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

  void sendDidChangeNotification(String text) {
    if (!isLanguageServerRunning()) return;

    final uri = 'file://${editor.path}';
    if (!_openDocuments.containsKey(uri)) {
      sendDidOpenNotification(text);
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

  void sendDidOpenNotification(String text) {
    if (!isLanguageServerRunning()) {
      _logger.warning('Cannot send didOpen - language server not running');
      return;
    }

    try {
      final uri = 'file://${editor.path}';
      sendNotification('textDocument/didOpen', {
        'textDocument': {
          'uri': uri,
          'languageId': 'dart',
          'version': _documentVersion++,
          'text': text
        }
      });
      _openDocuments[uri] = _documentVersion;
    } catch (e, stackTrace) {
      _logger.severe('Failed to send didOpen notification', e, stackTrace);
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

  void _handleDiagnostics(Map<String, dynamic> params) {
    final diagnostics = params['diagnostics'] as List;
    EditorEventBus.emit(DiagnosticsEvent(
      uri: params['uri'] as String,
      diagnostics: diagnostics.map((d) => Diagnostic.fromJson(d)).toList(),
    ));
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

  ServerCommand getLSPCommandForLanguage(String extension) {
    switch (extension) {
      case '.dart':
        return const ServerCommand('dart', [
          'language-server',
          '--protocol=lsp',
        ]);
      case '.py':
        return const ServerCommand('pylsp', []);
      case '.js':
      case '.ts':
        return const ServerCommand('typescript-language-server', ['--stdio']);
      default:
        throw Exception('No language server for extension: $extension');
    }
  }

  Future<void> initializeLanguageServer() async {
    final fileExtension = p.extension(editor.path);
    final serverCommand = getLSPCommandForLanguage(fileExtension);

    try {
      languageServer =
          await Process.start(serverCommand.executable, serverCommand.args);

      // Set up message handling before sending initialize request
      _setupMessageHandling();

      // Wait a bit for the server to start
      await Future.delayed(const Duration(milliseconds: 100));

      await sendRequest('initialize', {
        'processId': languageServer?.pid,
        'rootUri': 'file://${p.dirname(p.dirname(editor.path))}',
        'capabilities': _getClientCapabilities(),
      });

      // Wait for server to process initialize response
      await Future.delayed(const Duration(milliseconds: 100));

      // Send initialized notification
      sendNotification('initialized', {});
    } catch (e, stackTrace) {
      _logger.severe('Failed to initialize language server', e, stackTrace);
      rethrow;
    }
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
      // Skip empty messages
      if (message.trim().isEmpty) return;

      String jsonContent;

      // Handle headers if present
      if (message.startsWith('Content-Length: ')) {
        final headerEnd = message.indexOf('\r\n\r\n');
        if (headerEnd == -1) {
          _logger.warning('Invalid message format - missing header end');
          return;
        }

        // Extract content length
        final lengthMatch =
            RegExp(r'Content-Length: (\d+)').firstMatch(message);
        if (lengthMatch == null) {
          _logger.warning('Invalid Content-Length header');
          return;
        }

        final expectedLength = int.parse(lengthMatch.group(1)!);
        jsonContent = message.substring(headerEnd + 4);

        // Verify content length
        if (jsonContent.length != expectedLength) {
          _logger.warning('Content length mismatch');
          return;
        }
      } else if (message.startsWith('{')) {
        jsonContent = message;
      } else {
        _logger.warning('Invalid message format');
        return;
      }

      // Process the JSON content
      final Map<String, dynamic> jsonData = jsonDecode(jsonContent);
      if (jsonData.isEmpty) {
        _logger.warning('Empty JSON content');
        return;
      }

      _processJsonContent(jsonContent);
    } catch (e, stackTrace) {
      _logger.severe('Error handling server message', e, stackTrace);
    }
  }

  void _processJsonContent(String content) {
    final response = jsonDecode(content);

    // Handle workspace/configuration request separately
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
      _logger.warning(
          'Language server is not running. Unable to get hover information.');
      return null;
    }

    try {
      _logger
          .info('Sending hover request for line $line, character $character');
      final response = await sendRequest('textDocument/hover', {
        'textDocument': {'uri': 'file://${editor.path}'},
        'position': {'line': line, 'character': character}
      });
      _logger.info('Received hover response: $response');
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
